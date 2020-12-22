#!/bin/bash
#
# Install NetApp Mediator and NetApp Host Utilities
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
NETAPP_MEDIATOR_21_PKG=${DIRNAME}/pkg/ONTAP-MEDIATOR-1.2


[ ! -f $NETAPP_LINUX_HUK_71_PKG ] && clean_and_exit "Error $NETAPP_LINUX_HUK_71_PKG no such file" 255
rpm -i $NETAPP_LINUX_HUK_71_PKG

mediator_port=`lsof -n |grep uwsgi |grep TCP |grep $MEDIATOR_PORT | awk '{ print $9}' | uniq`
if [ -z "$mediator_port" ] ; then
	[ ! -f $NETAPP_MEDIATOR_21_PKG ] && clean_and_exit "Error $NETAPP_MEDIATOR_21_PKG no such file" 255
	( echo $MEDIATOR_PASSWD ; sleep 5 ; echo $MEDIATOR_PASSWD ) | $NETAPP_MEDIATOR_21_PKG -y
fi

check_netapp_linux_bin
check_mediator
clean_and_exit "Terminate" 0
