#!/bin/bash
#
set -x
VERSION=0.4
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

# Unmape Linux Lun Drives
[ -z "$MNT_DATA" ] && clean_and_exit "Internal Error MNT_DATA NULL" 255
if [ -d $MNT_DATA/lost+found ] ; then
	lsof=`lsof $MNT_DATA` ; [ ! -z "$lsof" ] && clean_and_exit "Error: $MNT_DATA busy" 255
	umount $MNT_DATA ; [ ! -z "$lsof" ] && clean_and_exit "Error: umount $MNT_DATA failed" 255
fi

lvdisplay /dev/vgdata/lv01 > /dev/null 2>&1
if [ $? -eq 0 ] ; then
	lvremove /dev/vgdata/lv01 -f ; [ $? -ne 0 ] && clean_and_exit "Error: failed to delete lv /dev/vgdata/lv01" 255
fi

vgdisplay /dev/vgdata > /dev/null 2>&1
if [ $? -eq 0 ] ; then
        vgremove /dev/vgdata -f ; [ $? -ne 0 ] && clean_and_exit "Error: failed to delete vg /dev/vgdata" 255
fi

dev_mapper=`sanlun lun show -p $SVM_NAME_P:/vol/${VOL_NAME_P}/${LUN_NAME} |grep Device | awk -F':' '{print $2}' |tr -d ' \r'`
[ -z "$dev_mapper" ] && clean_and_exit "No Linux device found exit" 1

fdisk -l /dev/mapper/${dev_mapper}; [ $? -ne 0 ] && clean_and_exit "Error: /dev/mapper/${dev_mapper} no such devices" 255

pvdisplay /dev/mapper/${dev_mapper} > /dev/null 2>&1
if [ $? -eq 0 ] ; then
        pvremove /dev/mapper/${dev_mapper} -f ; [ $? -ne 0 ] && clean_and_exit "Error: failed to remove pv /dev/mapper/${dev_mapper}" 255
fi

device_list=`sanlun lun show -p $SVM_NAME_P:/vol/${VOL_NAME_P}/${LUN_NAME} |grep ^up |awk '{print $3}'`
[ -z "$device_list" ] && clean_and_exit "Error: sanlun no device found" 255

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
