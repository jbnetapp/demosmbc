#!/bin/bash
# v01
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


# Unmape Linux Lun Drives
sanlun lun show -p
#echo "1" > /sys/block/sdm/device/delete
systemctl stop multipathd.service
systemctl start multipathd.service
/usr/bin/rescan-scsi-bus.sh
