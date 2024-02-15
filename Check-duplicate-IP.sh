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

for i in `grep IP_I $CONFIG_FILE | awk -F'=' '{print $2}'`; do 
	echo Check Duplicate IP: $i 
	ping -q -c 4 $i
	[ $? -eq 0 ] && clean_and_exit "Error $i duplicated IP address" 1
done


for i in `grep IP_SVM $CONFIG_FILE  | awk -F'=' '{print $2}'`; do 
	echo Check Duplicate IP: $i 
	ping -q -c 4 $i
	[ $? -eq 0 ] && clean_and_exit "Error $i duplicated IP address" 1
done

clean_and_exit "terminate" 0
