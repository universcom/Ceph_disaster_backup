#!/bin/bash

######
# We assume, there are 2 pool, which one for Volumes with Bussines type class and other
# for Economy type class
# get project list form site
# combain project lists and get uniq project list
# get volume list per project
# get backup in newer directory
# check in back up in pervios backup if exsit and qemu-command compeleted successfuly  was remove
# remove backup for 10 days ago
######

#necessery DIR and parameters
BackupDir=/mnt/nfs/var/CephDisasterBackup #Directory that all RAW file save in it
BaseScriptDir=/opt/scripts/CephDisasterBackup #Directory of script location
AgeDate=2 #data age

#copy project list to appoprate files
cp /tmp/economy_project_list_afra.txt $BaseScriptDir/economy.txt #economy project list
cp /tmp/business_project_list_afra.txt $BaseScriptDir/business.txt #business project list


# #Create and Delete requierd DIR
time=`date '+%Y-%m-%d'` #get time for create appropriate directory in NFS
mkdir -p $BackupDir/$time/economy #create appropriate directory in NFS based on time for economy users
mkdir -p $BackupDir/$time/business #create appropriate directory in NFS based on time for business users
expairedBackupDirName=`date --iso-8601 -d "$AgeDate day ago"` #get last day of backup age time
 rm -rf $BackupDir/$expairedBackupDirName #delete Backup directory that deleted in rotation

#openstack auth
export OS_NO_CACHE=True
export COMPUTE_API_VERSION=1.1
export OS_USERNAME=admin
export OS_REGION_NAME=$4
export OS_USER_DOMAIN_NAME=Default
export OS_VOLUME_API_VERSION=3
export OS_AUTH_URL=$3
export NOVA_VERSION=1.1
export OS_IMAGE_API_VERSION=2
export OS_PASSWORD=$2
export OS_PROJECT_DOMAIN_NAME=Default
export OS_IDENTITY_API_VERSION=3
export OS_PROJECT_NAME=$1
export OS_AUTH_TYPE=password

#business
for business_porject_id in $(cat $BaseScriptDir/business.txt)
do
  cinder list --tenant $business_porject_id | cut -d "|" -f 2 | sed '$d' | sed '1,3d' | sed 's/ //g' > $BaseScriptDir/business_volumes_id
  if (-nz `cat $BaseScriptDir/business_volumes_id`)
  do
    for volume_id in $(cat $BaseScriptDir/business_volumes_id)
    do
      if (-nz `rbd -p business-cinder-volume ls | grep -i $volume_id`)
      do
        qemu-img convert -f raw -O qcow2 rbd:business-cinder-volumes/volume-$volume_id $BackupDir/$time/business/$volume_id -p
      elif (-nz `rbd -p cinder-volume ls | grep -i $volume_id`)
      do
        qemu-img convert -f raw -O qcow2 rbd:cinder-volumes/volume-$volume_id $BackupDir/$time/business/$volume_id -p
        echo "volume $volume_id in incorrect pool economy->business" > $BaseScriptDir/backup.log
      done
    done
  done
done


#ec
for economy_porject_id in $(cat $BaseScriptDir/economy.txt)
do
  cinder list --tenant $economy_porject_id | cut -d "|" -f 2 | sed '$d' | sed '1,3d' | sed 's/ //g' > $BaseScriptDir/economy_volumes_id
  if (-nz `cat $BaseScriptDir/economy_volumes_id`)
  do
    for volume_id in $(cat $BaseScriptDir/economy_volumes_id)
    do
      if (-nz `rbd -p cinder-volume ls | grep -i $volume_id`)
      do
        qemu-img convert -f raw -O qcow2 rbd:cinder-volumes/volume-$volume_id $BackupDir/$time/economy/$volume_id -p
      elif (-nz `rbd -p business-cinder-volume ls | grep -i $volume_id`)
      do
        qemu-img convert -f raw -O qcow2 rbd:business-cinder-volumes/volume-$volume_id $BackupDir/$time/economy/$volume_id -p
        echo "volume $volume_id in incorrect pool business->economy" > $BaseScriptDir/backup.log
      done
    done
  done
done  
