#!/bin/bash

if [ ! -d /root/backup ]
then
  mkdir -p /root/backup
fi

backup_timestamp=$(date +%s)
backup_filename=eap-${backup_timestamp}.tar.gz
backup_file=/root/backup/${backup_filename}
filename=eap.tar.gz
file=/root/backup/${filename}

pushd /var/vcap/store/eap/data
  tar zcvf ${file} db map
popd

pushd /root/backup

echo "Dump keys"
cat > id_rsa.pem << EOF
<%= p('backup_priv') %>
EOF
chmod 600 id_rsa.pem

echo "Generate encoded files"
openssl rand -base64 32 > enckey.bin
openssl rsa -in id_rsa.pem -pubout -outform pem > id_rsa.pub.pem
openssl rsautl -encrypt -inkey id_rsa.pub.pem -pubin -in enckey.bin -out enckey.bin.enc
openssl enc -aes-256-cbc -salt -in ${file} -out ${filename}.enc -pass file:./enckey.bin

echo "Generate tar of encoded files"
tar zcvf ${backup_filename} enckey.bin.enc ${filename}.enc

echo "Upload file"
region=""
<% if_p('s3_region') do |region|-%>
region="-<%= region %>"
<% end -%>
bucket=<%= p('s3_bucket') %>
resource="/${bucket}/${backup_filename}"
contentType="application/x-compressed-tar"
dateValue=`date -R`
stringToSign="PUT\n\n${contentType}\n${dateValue}\n${resource}"
s3Key=<%= p('s3_access_key') %>
s3Secret=<%= p('s3_secret_key') %>
signature=`echo -en ${stringToSign} | openssl sha1 -hmac ${s3Secret} -binary | base64`
curl -X PUT -T "${backup_file}" \
  -H "Host: ${bucket}.s3${region}.amazonaws.com" \
  -H "Date: ${dateValue}" \
  -H "Content-Type: ${contentType}" \
  -H "Authorization: AWS ${s3Key}:${signature}" \
  https://${bucket}.s3${region}.amazonaws.com/${backup_filename}
echo "Done"

echo "Cleanup"
rm enckey.bin.enc
rm enckey.bin
rm ${file}
rm ${filename}.enc
rm ${backup_filename}

popd


## RESTORE
#openssl rsautl -decrypt -inkey id_rsa-test.pem -in key.bin.enc -out key.bin
#openssl enc -d -aes-256-cbc -in ${file}.enc -out ${file}2 -pass file:./key.bin

