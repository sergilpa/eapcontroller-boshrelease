# EAP Controller BOSH release

This is a BOSH release for TP-Link EAP wireless accesspoint controller software.

It is used to managed wireless access points.

This is a personal BOSH release that I am making publicly available

* [EAP Controller PDF](http://static.tp-link.com/1910012206_EAP%20Controller_V2.4.8_UG.pdf)
* [EAP Controller Linux Download](http://static.tp-link.com/EAP_Controller_v2.4.8_linux_x64.tar.gz)

# Nginx as SSL proxy
Uses my `nginx-boshrelease`

# Usage
* Modify `manifests/example-ops.yml` to suit your configuration and certificates etc..
  * save it as `manifests/private.yml`

# Adding EAP/WAPs to the controller
* Use EAP Discovery locally, and connect the EAP/WAPs manually to the controller using whatever IP address you deployed this release with

# Backup configuration
Run the errand backup to backup the database to an s3 bucket.
You need to define the following
```
variables:
  - name: backup
    type: ssh
instance_groups:
  - name: eap
    jobs:
      - name: backup
        release: eapconroller
        properties:
          s3_bucket: <bucketname>
          s3_region: <region>
          s3_access_key: <access_key>
          s3_secret_key: <secret_key>
          backup_priv: ((backup.private_key))
```
# Deploy
```
bosh deploy manifests/deployment.yml -o manifests/private.yml --vars-store=vars/private.yml
```
This will generate the SSH key for backups automatically, keep it somewhere safe or else you won't be able to recover any backups!

# TODO
* [ ] add errand to
  * [x] create a backup of data directory
  * [ ] restore data directory if relocating
* [x] manifest for incorporating nginx release to do reverse proxy with valid certificate
  * [x] pre-start will extract the certificate from eap controller and store in in /var/vcap/store/eap/eapstore.crt
