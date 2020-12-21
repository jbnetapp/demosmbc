#!/bin/bash
#
set -x

VERSION=0.3
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


iscsiadm --mode discovery --op update --type sendtargets --portal $IP_SVM_P2 
iscsiadm --mode discovery --op update --type sendtargets --portal $IP_SVM_S2 

/usr/bin/rescan-scsi-bus.sh
multipath -ll

sanlun lun show -p
