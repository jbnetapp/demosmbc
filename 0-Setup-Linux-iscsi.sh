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

set -x
yum update -y
yum install tuned -y
yum install grubby -y
yum install sshpass -y
yum install device-mapper -y
yum install device-mapper-multipath -y

# package require for Mediator
yum install openssl -y
yum install openssl-devel -y 
yum install gcc -y 
yum install make -y 
yum install redhat-lsb-core -y 
yum install patch -y 
yum install bzip2 -y 
yum install python36 -y 
yum install python36-devel -y 
yum install python36-pip -y
yum install libselinux-utils -y 
yum inqtall perl-Data-Dumper -y 
yum install perl-ExtUtils-MakeMaker -y 
yum install policycoreutils-python -y


tuned-adm profile virtual-guest

cat /etc/iscsi/iscsid.conf |sed s/'node.session.timeo.replacement_timeout = 20'/'node.session.timeo.replacement_timeout = 5'/ > $TMPFILE
diff=`diff /etc/iscsi/iscsid.conf $TMPFILE`
if [ -z "$diff" ]; then
	cp -p /etc/iscsi/iscsid.conf /etc/iscsi/iscsid.conf_bck.$$
	cat $TMPFILE > /etc/iscsi/iscsid.conf
fi

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

gettext "Reboot Linux now [y/n]? : "
read input 
if [ "$input" == "y" ] ; then
	reboot
fi
clean_and_exit "terminate" 0
