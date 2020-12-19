#!/bin/bash
set -x

DIRNAME=`dirname $0`
CONFIG_FILE=${DIRNAME}/Setup.conf
FUNCTIONS_FILE=${DIRNAME}/functions.sh

if [ ! -f $CONFIG_FILE ] ; then
        echo "ERROR: Unable to read $CONFIG_FILE"
        exit 1
fi

. $CONFIG_FILE
. $FUNCTIONS_FILE

set -x

DIRNAME=`dirname $0`
CONFIG_FILE=${DIRNAME}/Setup.conf

if [ ! -f $CONFIG_FILE ] ; then
        echo "ERROR: Unable to read $CONFIG_FILE"
        exit 1
fi

. $CONFIG_FILE

yum update -y
yum install tuned -y
yum install grubby -y
yum install device-mapper -y
yum install device-mapper-multipath -y


tuned-adm profile virtual-guest

cat /etc/iscsi/iscsid.conf |sed s/'node.session.timeo.replacement_timeout = 20'/'node.session.timeo.replacement_timeout = 5'/ > $TMPFILE
diff /etc/iscsi/iscsid.conf $TMPFILE
echo > /etc/multipath.conf << EOF
blacklist {
        devnode    "^(ram|raw|loop|fd|md|dm-|sr|scd|st)[0-9]*"
        devnode    "^hd[a-z]"
        devnode     "^cciss.*"
}
EOF

systemctl start iscsid
systemctl start multipathd.service 
multipath -t

ISCSI_INAME=`cat /etc/iscsi/initiatorname.iscsi | awk -F'=' '{print $2}'`
echo "ISCSI_INAME $ISCSI_INAME"


echo "Uptate kernel grub"
KERNEL=`uname -r`
KERNEL_FILE=`echo /boot/vmlinuz-${KERNEL}` 
if [ -f $KERNEL_FILE ] ; then
	echo "grubby --args "rdloaddriver=scsi_dh_alua" --update-kernel $KERNEL_FILE"
	grubby --args "rdloaddriver=scsi_dh_alua" --update-kernel $KERNEL_FILE
fi

clean_and_exit "terminate" 0
