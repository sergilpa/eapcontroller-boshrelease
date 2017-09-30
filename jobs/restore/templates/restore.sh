#!/bin/bash

if [ ! -d /root/backup ]
then
  mkdir -p /root/backup
fi

pushd /root/backup

echo "Dump keys"
cat > id_rsa.pem << EOF
<%= link('eap_backup').p('backup_priv') %>
EOF
chmod 600 id_rsa.pem

echo "List then download file"
region=""
<% link('eap_backup').if_p('s3_region') do |region|-%>
region="-<%= region %>"
<% end -%>
bucket=<%= link('eap_backup').p('s3_bucket') %>
resource="/${bucket}/"
contentType="application/x-compressed-tar"
dateValue=`date -R`
stringToSign="GET\n\n${contentType}\n${dateValue}\n${resource}"
s3Key=<%= link('eap_backup').p('s3_access_key') %>
s3Secret=<%= link('eap_backup').p('s3_secret_key') %>
signature=`echo -en ${stringToSign} | openssl sha1 -hmac ${s3Secret} -binary | base64`

# grab the list of keys in the bucket, sort by newest first, select only latest to download
backup_list=$(curl -s -X GET \
  -H "Host: ${bucket}.s3${region}.amazonaws.com" \
  -H "Date: ${dateValue}" \
  -H "Content-Type: ${contentType}" \
  -H "Authorization: AWS ${s3Key}:${signature}" \
http://${bucket}.s3${region}.amazonaws.com/ | grep -o 'eap-[0-9]\{10\}.tar.gz' | sort -n -r | head -n 1)

if [ -z "${backup_list}" ]
then
  echo "no backups found, exit"
  exit 1
fi

resource="/${bucket}/${backup_list}"
dateValue=`date -R`
stringToSign="GET\n\n${contentType}\n${dateValue}\n${resource}"
signature=`echo -en ${stringToSign} | openssl sha1 -hmac ${s3Secret} -binary | base64`

if [ ! -d /var/vcap/store/restore ]
then
  mkdir /var/vcap/store/restore
fi

curl -s -X GET \
  -H "Host: ${bucket}.s3${region}.amazonaws.com" \
  -H "Date: ${dateValue}" \
  -H "Content-Type: ${contentType}" \
  -H "Authorization: AWS ${s3Key}:${signature}" \
  https://${bucket}.s3${region}.amazonaws.com/${backup_list} --output /var/vcap/store/restore/eap.tar.gz
echo "Done"

pushd /var/vcap/store/restore
  tar zxvf eap.tar.gz
popd

rm /var/vcap/store/restore/eap.tar.gz

openssl rsautl -decrypt -inkey id_rsa.pem -in /var/vcap/store/restore/enckey.bin.enc -out enckey.bin
openssl enc -d -aes-256-cbc -in /var/vcap/store/restore/eap.tar.gz.enc -out /var/vcap/store/restore/eap.tar.gz -pass file:./enckey.bin

pushd /var/vcap/store/restore
  if [ -f db/mongod.lock ]
  then
    rm db/mongod.lock
  fi
  tar zxvf eap.tar.gz
popd

echo "Cleanup"
rm enckey.bin
popd

echo "Stop EAP, copy data, restart EAP"
pushd /var/vcap/store/
  /var/vcap/jobs/eapcontroller/bin/ctl stop
  rm -rf eap/data/db
  rm -rf eap/data/map
  mv restore/db eap/data/.
  mv restore/map eap/data/.
  /var/vcap/jobs/eapcontroller/bin/ctl start
popd

echo "Cleanup"
rm -rf /var/vcap/store/restore
