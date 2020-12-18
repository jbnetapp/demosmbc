#!/bin/bash
set -x
#TMPFILE=/tmp/file.$$
#PASSWD='Netapp1!'

DIRNAME=`dirname $0`
CONFIG_FILE=${DIRNAME}/Setup.conf

if [ ! -f $CONFIG_FILE ] ; then
        echo "ERROR: Unable to read $CONFIG_FILE"
        exit 1
fi

clean_and_exit(){
	echo $0
	exit  
}

. $CONFIG_FILE

echo Init SSH session host 
SSH_Name=`cat $HOME/.ssh/known_hosts  | awk -F',' -v cluster_name=cluster1 '{if ( $1 == cluster_name ) print $1}'`
[ -z $SSH_Name ] &&  ssh -l admin cluster1 exit

SSH_Name=`cat $HOME/.ssh/known_hosts  | awk -F',' -v cluster_name=cluster1 '{if ( $1 == cluster_name ) print $1}'`
[ -z $SSH_Name ] &&  ssh -l admin cluster2 exit

echo Unmap LUN
sshpass -p $PASSWD ssh -l admin cluster1 lun unmap -vserver $SVM_P -path /vol/${VOL_NAME_P}/${LUN_NAME} -igroup centos01
sshpass -p $PASSWD ssh -l admin cluster2 lun unmap -vserver $SVM_S -path /vol/${VOL_NAME_S}/${LUN_NAME} -igroup centos02

echo Delete iGroup
sshpass -p $PASSWD ssh -l admin cluster1 igroup delete -igroup centos01 -vserver $SVM_P
igroup=`sshpass -p $PASSWD ssh -l admin cluster1 igroup show -igroup centos01 -vserver $SVM_P |grep centos01`
[ ! -z "$igroup" ] && clean_and_exit "Error Unable to delete igroup centos01 exit " 

sshpass -p $PASSWD ssh -l admin cluster2 igroup delete -igroup centos01 -vserver $SVM_S
igroup=`sshpass -p $PASSWD ssh -l admin cluster2 igroup show -igroup centos01 -vserver $SVM_S |grep centos01`
[ ! -z "$igroup" ] && clean_and_exit "Error Unable to delete igroup centos01 exit " 

echo Delete SnapMirror SMBC
sshpass -p $PASSWD ssh -l admin cluster2 snapmirror delete -destination-path $SMBC_DST_PATH -source-path $SMBC_SRC_PATH
smr=`sshpass -p $PASSWD ssh -l admin cluster2 snapmirror show -destination-path $SMBC_DST_PATH -source-path $SMBC_SRC_PATH -fields status,state | grep $SMBC_DST_PATH`
[ ! -z "$smr" ] && clean_and_exit "Error Unable to delete snapmirror relation destination-path $SMBC_DST_PATH"

sshpass -p $PASSWD ssh -l admin cluster1 snapmirror release -destination-path $SMBC_DST_PATH -source-path $SMBC_SRC_PATH
smr=`sshpass -p $PASSWD ssh -l admin cluster1 snapmirror list-destinations -destination-path $SMBC_DST_PATH -source-path $SMBC_SRC_PATH -fields status | grep $SMBC_DST_PATH`
[ ! -z "$smr" ] && clean_and_exit "Error Unable to delete snapmirror relation destination-path $SMBC_DST_PATH"


echo Delete Mediator
sshpass -p $PASSWD ssh -l admin cluster1 snapmirror mediator remove -mediator-address $MEDIATOR_IP -peer-cluster cluster2
med=`sshpass -p $PASSWD ssh -l admin cluster1 snapmirror mediator remove -mediator-address $MEDIATOR_IP -peer-cluster cluster2`
[ ! -z "$med" ] && clean_and_exit "Error Unable to delete mediator"

sshpass -p $PASSWD ssh -l admin cluster2 snapmirror mediator remove -mediator-address $MEDIATOR_IP -peer-cluster cluster1


CERT=`sshpass -p $PASSWD ssh -l admin cluster1 security certificate show  -cert-name ONTAPMediatorCA -field serial,ca,type | grep ONTAPMediatorCA`
CERT_VSERVER=`echo $CERT |awk '{print $1}'`
CERT_SERIAL=`echo $CERT |awk '{print $3}'`
CERT_TYPE=`echo $CERT |awk -F'"' '{print $3}'| awk '{print $1}'`
[ ! -z "$CERT_SERIAL" ] && sshpass -p $PASSWD ssh -l admin cluster1 "security certificate delete -common-name ONTAPMediatorCA -serial ${CERT_SERIAL} -type ${CERT_TYPE} -ca *"

CERT=`sshpass -p $PASSWD ssh -l admin cluster2 security certificate show  -cert-name ONTAPMediatorCA -field serial,ca,type | grep ONTAPMediatorCA`
CERT_VSERVER=`echo $CERT |awk '{print $1}'`
CERT_SERIAL=`echo $CERT |awk '{print $3}'`
CERT_TYPE=`echo $CERT |awk -F'"' '{print $3}'| awk '{print $1}'`
[ ! -z "$CERT_SERIAL" ] && sshpass -p $PASSWD ssh -l admin cluster2 "security certificate delete -common-name ONTAPMediatorCA -serial ${CERT_SERIAL} -type ${CERT_TYPE} -ca *"

echo Delete LUN 
sshpass -p $PASSWD ssh -l admin cluster1 lun offline -path /vol/$VOL_NAME_P/$LUN_NAME -vserver $SVM_P
sshpass -p $PASSWD ssh -l admin cluster1 lun delete -path /vol/$VOL_NAME_P/$LUN_NAME -vserver $SVM_P

sshpass -p $PASSWD ssh -l admin cluster1 volume offline -volume $VOL_NAME_P
sshpass -p $PASSWD ssh -l admin cluster1 volume delete -volume $VOL_NAME_P

sshpass -p $PASSWD ssh -l admin cluster2 volume offline -volume $VOL_NAME_S
sshpass -p $PASSWD ssh -l admin cluster2 volume delete -volume $VOL_NAME_S

echo Delete Vserver peer 
sshpass -p $PASSWD ssh -l admin cluster1 vserver peer delete -vserver $SVM_P -peer-vserver $SVM_S
sleep 5

echo Delete Vserver $SVM_S
sshpass -p $PASSWD ssh -l admin cluster2 network interface modify -vserver $SVM_S -lif ${SVM_S}_* -status-admin down
sshpass -p $PASSWD ssh -l admin cluster2 network interface delete -vserver $SVM_S -lif ${SVM_S}_* 
sshpass -p $PASSWD ssh -l admin cluster2 vserver delete -vserver $SVM_S

echo Delete Vserver $SVM_P
sshpass -p $PASSWD ssh -l admin cluster1 network interface modify -vserver $SVM_P -lif ${SVM_P}_* -status-admin down
sshpass -p $PASSWD ssh -l admin cluster1 network interface delete -vserver $SVM_P -lif ${SVM_P}_* 
sshpass -p $PASSWD ssh -l admin cluster1 vserver delete -vserver $SVM_P

echo Delete Peer Cluser
sshpass -p $PASSWD ssh -l admin cluster1 cluster peer delete -cluster cluster2 
sshpass -p $PASSWD ssh -l admin cluster2 cluster peer delete -cluster cluster1
sleep 5

echo Delete InteCluser LIF cluster1
sshpass -p $PASSWD ssh -l admin cluster1 version 
sshpass -p $PASSWD ssh -l admin cluster1 network interface modify -vserver cluster1 -lif intercluster1 -status-admin down
sshpass -p $PASSWD ssh -l admin cluster1 network interface modify -vserver cluster1 -lif intercluster2 -status-admin down 
sshpass -p $PASSWD ssh -l admin cluster1 network interface delete -vserver cluster1 -lif intercluster1
sshpass -p $PASSWD ssh -l admin cluster1 network interface delete -vserver cluster1 -lif intercluster2
sshpass -p $PASSWD ssh -l admin cluster1 cluster peer policy modify -is-unauthenticated-access-permitted false 
sshpass -p $PASSWD ssh -l admin cluster1 cluster peer policy modify -is-unencrypted-access-permitted false 

echo Delete InteCluser LIF cluster2
sshpass -p $PASSWD ssh -l admin cluster2 version
sshpass -p $PASSWD ssh -l admin cluster2 network interface modify -vserver cluster2 -lif intercluster1 -status-admin down 
sshpass -p $PASSWD ssh -l admin cluster2 network interface modify -vserver cluster2 -lif intercluster2 -status-admin down 
sshpass -p $PASSWD ssh -l admin cluster2 network interface delete -vserver cluster2 -lif intercluster1
sshpass -p $PASSWD ssh -l admin cluster2 network interface delete -vserver cluster2 -lif intercluster2
sshpass -p $PASSWD ssh -l admin cluster2 cluster peer policy modify -is-unauthenticated-access-permitted false 
sshpass -p $PASSWD ssh -l admin cluster2 cluster peer policy modify -is-unencrypted-access-permitted false

[ -f $TMPFILE ] && rm $TMPFILE
