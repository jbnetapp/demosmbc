#!/bin/bash
#
set -x
VERSION=1.0
DIRNAME=`dirname $0`
CONFIG_FILE=${DIRNAME}/Setup.conf
FUNCTIONS_FILE=${DIRNAME}/functions.sh

if [ ! -f $CONFIG_FILE ] ; then
        echo "ERROR: Unable to read $CONFIG_FILE"
        exit 1
fi

. $CONFIG_FILE
. $FUNCTIONS_FILE

check_var
check_linux_bin
check_netapp_linux_bin

echo Create iGroup Linux
INITIATOR_NAME=`cat $LINUX_ISCSI_INITIATOR_FILE | awk -F '=' '{print $2}'`
igroup_init=`sshpass -p $PASSWD ssh -l admin cluster1 igroup show -igroup centos01  -vserver $SVM_NAME_P -fields initiator |grep $SVM_NAME_P | awk '{print $3}' |tr -d '\r'`
[ -z "$igroup_init" ] && sshpass -p $PASSWD ssh -l admin cluster1 igroup create -igroup centos01 -protocol mixed -ostype linux -initiator $INITIATOR_NAME -vserver $SVM_NAME_P

igroup_init=`sshpass -p $PASSWD ssh -l admin cluster2 igroup show -igroup centos01  -vserver $SVM_NAME_S -fields initiator |grep $SVM_NAME_S | awk '{print $3}' |tr -d '\r'`
[ -z "$igroup_init" ] && sshpass -p $PASSWD ssh -l admin cluster2 igroup create -igroup centos01 -protocol mixed -ostype linux -initiator $INITIATOR_NAME -vserver $SVM_NAME_S

sshpass -p $PASSWD ssh -l admin cluster1 lun map -vserver $SVM_NAME_P -path /vol/${VOL_NAME_P}/${LUN_NAME} -igroup centos01
sshpass -p $PASSWD ssh -l admin cluster2 lun map -vserver $SVM_NAME_S -path /vol/${VOL_NAME_S}/${LUN_NAME} -igroup centos01

sessions=`iscsiadm --mode session`
if [ -z "$sessions" ] ; then 
	iscsiadm --mode discovery --op update --type sendtargets --portal $IP_SVM_P2 
	iscsiadm --mode discovery --op update --type sendtargets --portal $IP_SVM_S2 
	iscsiadm --mode node -l all
	iscsiadm --mode session
fi

/usr/bin/rescan-scsi-bus.sh
multipath -ll
sanlun lun show -p

# Init LVM disq
dev_mapper=`sanlun lun show -p $SVM_NAME_P:/vol/${VOL_NAME_P}/${LUN_NAME} |grep Device | awk -F':' '{print $2}' |tr -d ' \r'`
fdisk -l /dev/mapper/${dev_mapper}; [ $? -ne 0 ] && clean_and_exit "Error: /dev/mapper/${dev_mapper} no such devices" 255


pvdisplay /dev/mapper/${dev_mapper} > /dev/null 2>&1
if [ $? -ne 0 ] ; then
	pvcreate /dev/mapper/${dev_mapper}; [ $? -ne 0 ] && clean_and_exit "Error: pvcreate failed on /dev/mapper/${dev_mapper}" 255
	pvdisplay /dev/mapper/${dev_mapper}; [ $? -ne 0 ] && clean_and_exit "Error: pvdisplay failed on /dev/mapper/${dev_mapper}" 255
fi


vgdisplay /dev/vgdata > /dev/null 2>&1
if [ $? -ne 0 ] ; then
	vgcreate /dev/vgdata /dev/mapper/${dev_mapper}; [ $? -ne 0 ] && clean_and_exit "Error: vgcreate  failed on /dev/mapper/${dev_mapper}" 255
	vgdisplay /dev/vgdata ; [ $? -ne 0 ] && clean_and_exit "Error: vgdisplay  failed on /dev/mapper/${dev_mapper}" 255
fi

lvdisplay /dev/vgdata/lv01 > /dev/null 2>&1
if [ $? -ne 0 ] ; then
	vgsizem=`vgdisplay /dev/vgdata --units m |grep "VG Size" |awk '{print $3}'`
	lvcreate --name lv01 --size ${vgsizem}m vgdata ; [ $? -ne 0 ] && clean_and_exit "Error: lvcreate failed" 255
fi

[ -z "$MNT_DATA" ] && clean_and_exit "Internal Error MNT_DATA NULL" 255
if [ ! -d $MNT_DATA/lost+found ] ; then
	mkfs.ext4 /dev/vgdata/lv01 ; [ $? -ne 0 ] && clean_and_exit "Error: mkfs failed on /dev/vgdata/lv01" 255
	[ ! -d "$MNT_DATA" ] && mkdir $MNT_DATA
	mount /dev/vgdata/lv01 $MNT_DATA
fi

clean_and_exit "Terminate" 0
