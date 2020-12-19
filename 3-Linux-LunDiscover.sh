#!/bin/bash
# echo Discover LUN
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

clean_and_exit "Terminate" 255
exit 

/usr/bin/rescan-scsi-bus.sh
multipath -ll
sanlun lun show -p

