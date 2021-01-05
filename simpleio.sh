#!/bin/bash
#
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

[ ! -d ${MNT_DATA}/lost+found ] && clean_and_exit "$MNT_DATA no such file system"

while true; do 
	echo Single Write 
	dd if=/dev/zero of=${MNT_DATA}/io.file iflag=fullblock bs=1024k count=2000; date
	echo Single Read/Write 
	dd if=${MNT_DATA}/io.file of=${MNT_DATA}/io.file2 bs=1024k iflag=fullblock; date; 
	echo Single Read 
	dd if=${MNT_DATA}/io.file of=/dev/null bs=1024k iflag=fullblock; date; 
done
