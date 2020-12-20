#!/bin/bash
#
set -x

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

# Unmape Linux Lun Drives
sanlun lun show -p
#echo "1" > /sys/block/sdm/device/delete
systemctl stop multipathd.service
systemctl start multipathd.service
/usr/bin/rescan-scsi-bus.sh
