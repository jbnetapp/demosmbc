#!/bin/bash
#
# Install Mediator and Host utilities kit
#
set -x
VERSION=0.4
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

# Package File
NETAPP_LINUX_HUK_71_PKG=${DIRNAME}/pkg/netapp_linux_unified_host_utilities-7-1.x86_64.rpm
NETAPP_MEDIATOR_21_PK=${DIRNAME}/pkg/ONTAP-MEDIATOR-1.2BAD


[ ! -f $NETAPP_LINUX_HUK_71_PKG ] && clean_and_exit "Error $NETAPP_LINUX_HUK_71_PKG no such file" 255
rpm -i $NETAPP_LINUX_HUK_71_PKG

check_netapp_linux_bin

[ ! -f $NETAPP_MEDIATOR_21_PK ] && clean_and_exit "Error $NETAPP_MEDIATOR_21_PKG no such file" 255


clean_and_exit "Terminate" 0
