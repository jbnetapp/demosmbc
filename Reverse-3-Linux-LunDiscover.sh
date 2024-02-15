#!/bin/bash
#
set -x
VERSION=1.0
DIRNAME=`dirname $0`
CONFIG_FILE=${DIRNAME}/Setup.conf
FUNCTIONS_FILE=${DIRNAME}/functions.sh
OPT=$1

if [ ! -f $CONFIG_FILE ] ; then
        echo "ERROR: Unable to read $CONFIG_FILE"
        exit 1
fi

. $CONFIG_FILE
. $FUNCTIONS_FILE

check_var

# Check LUN
device_list=`sanlun lun show -p $SVM_NAME_P:/vol/${VOL_NAME_P}/${LUN_NAME} |grep ^up |awk '{print $3}'`
if [ -z "$device_list" ] ; then 
	device_list=`sanlun lun show -p $SVM_NAME_S:/vol/${VOL_NAME_S}/${LUN_NAME} |grep ^up |awk '{print $3}'`
	[ -z "$device_list" ] && clean_and_exit "Error: sanlun no device found" 255
fi

echo Unmap LUN
sshpass -p $PASSWD ssh -l admin cluster1 lun unmap -vserver $SVM_NAME_P -path /vol/${VOL_NAME_P}/${LUN_NAME} -igroup centos01
sshpass -p $PASSWD ssh -l admin cluster2 lun unmap -vserver $SVM_NAME_S -path /vol/${VOL_NAME_S}/${LUN_NAME} -igroup centos01

for dev in $device_list; do
	echo /sys/block/${dev}/device/delete
	echo "1" > /sys/block/${dev}/device/delete
done

sessions=`iscsiadm --mode session`
if [ ! -z "$sessions" ] ; then
	iscsiadm --mode session > $TMPFILE 
	iscsiadm --mode session -u
	cat $TMPFILE | awk '{print $3" "$4}' | while read line ; do
		ip=`echo $line | awk -F ':' '{print $1}'`
		iqn=`echo $line | awk '{print $2}'`
		echo "iscsiadm --mode node --targetname $iqn --portal $ip -o delete"
		iscsiadm --mode node --targetname $iqn --portal $ip -o delete
	done
fi

systemctl restart multipathd.service

clean_and_exit "Terminate" 0 
