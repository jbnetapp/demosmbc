#!/bin/bash

VERSION=0.2
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

set -x
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
	set +x
	gettext "Run: [grubby --args "rdloaddriver=scsi_dh_alua" --update-kernel $KERNEL_FILE] [y/n]? : "
	read input 
	if [ "$input" == "y" ] ; then
		grubby --args "rdloaddriver=scsi_dh_alua" --update-kernel $KERNEL_FILE
		echo "Please Reboot Linux and run following command after reboot"
		echo "# cat /proc/cmdline "
		echo "And check if you sse the variable rdloaddriver=scsi_dh_alua in the kernel" 
	fi
fi
clean_and_exit "terminate" 0
