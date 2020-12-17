#!/bin/bash
set -x
TMPFILE='/tmp/File.$$'
yum install tuned -y
yum install grubby -y
yum install device-mapper -y
yum install device-mapper-multipath -y
tuned-adm profile virtual-guest
ISCSI_INAME=`cat /etc/iscsi/initiatorname.iscsi | awk -F'=' '{print $2}'`
echo "ISCSI_INAME $ISCSI_INAME"
cat /etc/iscsi/iscsid.conf |sed s/'node.session.timeo.replacement_timeout = 20'/'node.session.timeo.replacement_timeout = 5'/ > $TMPFILE
diff /etc/iscsi/iscsid.conf $TMPFILE
echo > /etc/multipath.conf << EOF
blacklist {
        wwid       3600508e000000000753250f933cc4606
        devnode    "^(ram|raw|loop|fd|md|dm-|sr|scd|st)[0-9]*"
        devnode    "^hd[a-z]"
        devnode     "^cciss.*"
}
EOF

KERNEL=`uname -r`
KERNEL_FILE=`echo /boot/vmlinuz-${KERNEL}` 
if [ -f $KERNEL_FILE ] ; then
	echo "grubby --args "rdloaddriver=scsi_dh_alua" --update-kernel $KERNEL_FILE"
fi
