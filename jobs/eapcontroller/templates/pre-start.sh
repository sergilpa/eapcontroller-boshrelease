#!/bin/bash

#sudo /var/vcap/packages/eapcontroller/bin/control.sh start

package_location=/var/vcap/packages/eapcontroller

sudo_reload=$(cat /etc/sudoers | grep "vcap ALL=(ALL) NOPASSWD: ALL")
if [ -z "$sudo_reload" ]
then
  echo "allow vcap to reload nginx"
  cp /etc/sudoers /etc/sudoers.tmp
  echo "vcap ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.tmp
  mv /etc/sudoers.tmp /etc/sudoers
  chmod 440 /etc/sudoers
else
  echo "vcap already has permission to reload nginx"
fi

if [ ! -d /var/vcap/store/eap/data ]
then
  mkdir -p /var/vcap/store/eap/data/db
  mkdir -p /var/vcap/store/eap/data/map
  mkdir -p /var/vcap/store/eap/data/portal
  mkdir -p /var/vcap/store/eap/data/region
  cp -r $package_location/data/db /var/vcap/store/eap/data/
  cp -r $package_location/data/map /var/vcap/store/eap/data/
  cp -r $package_location/data/portal /var/vcap/store/eap/data/
  cp -r $package_location/data/region /var/vcap/store/eap/data/
fi

rm -rf $package_location/data

if [ ! -L $package_location/data ]
then
  ln -s /var/vcap/store/eap/data $package_location
fi

echo "tplink" | $package_location/jre/bin/keytool -export -alias eap -file /var/vcap/store/eap/eapstore.crt -keystore $package_location/keystore/eap.keystore
openssl x509 -inform der -in /var/vcap/store/eap/eapstore.crt -out /var/vcap/store/eap/eapstore.pem
rm /var/vcap/store/eap/eapstore.crt
