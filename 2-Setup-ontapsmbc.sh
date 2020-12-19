#!/bin/bash
#
# v01
#
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

# Main
echo Init SSH session host 
check_ssh_keyhost cluster1
check_ssh_keyhost cluster2

sshpass -p $PASSWD ssh -l admin cluster1 version 
sshpass -p $PASSWD ssh -l admin cluster2 version 


echo Create InteCluser LIF cluster1
sshpass -p $PASSWD ssh -l admin cluster1 network interface create -vserver cluster1 -lif intercluster1 -address 192.168.0.115 -netmask-length 24 -home-node cluster1-01 -service-policy default-intercluster -home-port e0g -status-admin up
sshpass -p $PASSWD ssh -l admin cluster1 network interface create -vserver cluster1 -lif intercluster2 -address 192.168.0.116 -netmask-length 24 -home-node cluster1-02 -service-policy default-intercluster -home-port e0g -status-admin up

echo Create InteCluser LIF cluster2
sshpass -p $PASSWD ssh -l admin cluster2 network interface create -vserver cluster2 -lif intercluster1 -address 192.168.0.117 -netmask-length 24 -home-node cluster2-01 -service-policy default-intercluster -home-port e0g -status-admin up
sshpass -p $PASSWD ssh -l admin cluster2 network interface create -vserver cluster2 -lif intercluster2 -address 192.168.0.118 -netmask-length 24 -home-node cluster2-02 -service-policy default-intercluster -home-port e0g -status-admin up

cps=`sshpass -p $PASSWD ssh -l admin cluster1 cluster peer show |grep cluster2 | awk '{print $4}'|tr -d '\r'`
if [ "$cps" != "ok" ]; then
	(sleep 1; echo $PASSWD ; sleep 2; echo $PASSWD )| sshpass -p $PASSWD ssh -l admin cluster1 cluster peer create -address-family ipv4 -peer-addrs 192.168.0.117
	sleep 10
	cps=`sshpass -p $PASSWD ssh -l admin cluster1 cluster peer show |grep cluster2 | awk '{print $4}'|tr -d '\r'`
	(sleep 1; echo $PASSWD ; sleep 2; echo $PASSWD )| sshpass -p $PASSWD ssh -l admin cluster2 cluster peer create -address-family ipv4 -peer-addrs 192.168.0.115
	sleep 10
	cps=`sshpass -p $PASSWD ssh -l admin cluster1 cluster peer show |grep cluster2 | awk '{print $4}'|tr -d '\r'`
	[ "$cps" != "ok" ] && clean_and_exit "Error Unable to create cluster peer from cluster2" 255
fi
sshpass -p $PASSWD ssh -l admin cluster1 cluster peer show 
sshpass -p $PASSWD ssh -l admin cluster2 cluster peer show 

echo Create $SVM_NAME_P cluster1
sshpass -p $PASSWD ssh -l admin cluster1 vserver create -vserver $SVM_NAME_P -subtype default 
sshpass -p $PASSWD ssh -l admin cluster1 vserver iscsi create -target-alias $SVM_NAME_P -status-admin up
sshpass -p $PASSWD ssh -l admin cluster1 network interface create -vserver $SVM_NAME_P -lif ${SVM_NAME_P}_admin -service-policy default-data-files -address 192.168.0.130 -netmask-length 24 -home-node cluster1-01 -home-port e0g -firewall-policy mgmt
sshpass -p $PASSWD ssh -l admin cluster1 network interface create -vserver $SVM_NAME_P -lif ${SVM_NAME_P}_data1 -service-policy default-data-blocks -address 192.168.0.131 -netmask-length 24 -home-node cluster1-01 -home-port e0g -firewall-policy data
sshpass -p $PASSWD ssh -l admin cluster1 network interface create -vserver $SVM_NAME_P -lif ${SVM_NAME_P}_data2 -service-policy default-data-blocks -address 192.168.0.132 -netmask-length 24 -home-node cluster1-02 -home-port e0g -firewall-policy data
sshpass -p $PASSWD ssh -l admin cluster1 network interface create -vserver $SVM_NAME_P -lif ${SVM_NAME_P}_data3 -service-policy default-data-blocks -address 192.168.0.133 -netmask-length 24 -home-node cluster1-01 -home-port e0g -firewall-policy data
sshpass -p $PASSWD ssh -l admin cluster1 network interface create -vserver $SVM_NAME_P -lif ${SVM_NAME_P}_data4 -service-policy default-data-blocks -address 192.168.0.134 -netmask-length 24 -home-node cluster1-02 -home-port e0g -firewall-policy data

echo Create $SVM_NAME_S cluster2
sshpass -p $PASSWD ssh -l admin cluster2 vserver create -vserver $SVM_NAME_S -subtype default 
sshpass -p $PASSWD ssh -l admin cluster2 vserver iscsi create -target-alias $SVM_NAME_S -status-admin up
sshpass -p $PASSWD ssh -l admin cluster2 network interface create -vserver $SVM_NAME_S -lif ${SVM_NAME_S}_admin -service-policy default-data-files -address 192.168.0.140 -netmask-length 24 -home-node cluster2-01 -home-port e0g -firewall-policy mgmt
sshpass -p $PASSWD ssh -l admin cluster2 network interface create -vserver $SVM_NAME_S -lif ${SVM_NAME_S}_data1 -service-policy default-data-blocks -address 192.168.0.141 -netmask-length 24 -home-node cluster2-01 -home-port e0g -firewall-policy data
sshpass -p $PASSWD ssh -l admin cluster2 network interface create -vserver $SVM_NAME_S -lif ${SVM_NAME_S}_data2 -service-policy default-data-blocks -address 192.168.0.142 -netmask-length 24 -home-node cluster2-02 -home-port e0g -firewall-policy data
sshpass -p $PASSWD ssh -l admin cluster2 network interface create -vserver $SVM_NAME_S -lif ${SVM_NAME_S}_data3 -service-policy default-data-blocks -address 192.168.0.143 -netmask-length 24 -home-node cluster2-01 -home-port e0g -firewall-policy data
sshpass -p $PASSWD ssh -l admin cluster2 network interface create -vserver $SVM_NAME_S -lif ${SVM_NAME_S}_data4 -service-policy default-data-blocks -address 192.168.0.144 -netmask-length 24 -home-node cluster2-02 -home-port e0g -firewall-policy data

echo Create svm relatoin 
sshpass -p $PASSWD ssh -l admin cluster1 vserver peer create -vserver $SVM_NAME_P -peer-vserver $SVM_NAME_S -applications snapmirror -peer-cluster cluster2
while [ -z $STATUS ] ; do 
	sleep 2 
	STATUS=`sshpass -p $PASSWD ssh -l admin cluster2 vserver peer show |grep $SVM_NAME_S |awk '{ print $3}'`
	echo $STATUS
done
sshpass -p $PASSWD ssh -l admin cluster2 vserver peer accept -vserver $SVM_NAME_S -peer-vserver $SVM_NAME_P

# Gets Free Data Aggregate
AGGR_DATA_CL1=`sshpass -p $PASSWD ssh -l admin cluster1 aggr show -root false |grep online |sort -k2 -u | tail -1 |awk '{print $1}'`
AGGR_DATA_CL2=`sshpass -p $PASSWD ssh -l admin cluster2 aggr show -root false |grep online |sort -k2 -u | tail -1 |awk '{print $1}'`
sshpass -p $PASSWD ssh -l admin cluster1 volume create -volume $VOL_NAME_P -vserver $SVM_NAME_P -aggregate $AGGR_DATA_CL1 -size $SIZE -autosize-mode grow -state online
sshpass -p $PASSWD ssh -l admin cluster2 volume create -volume $VOL_NAME_S -vserver $SVM_NAME_S -aggregate $AGGR_DATA_CL2 -size $SIZE -autosize-mode grow -type DP -state online 
U_SIZE=`echo $SIZE|sed -e s/[0-9]//g`
N_SIZE=`echo $SIZE|sed -e s/[a-zA-Z]//g`
LUN_SIZE=$(($N_SIZE - 1))${U_SIZE}

sshpass -p $PASSWD ssh -l admin cluster1 lun create -vserver $SVM_NAME_P -path /vol/${VOL_NAME_P}/${LUN_NAME} -size $LUN_SIZE -ostype Linux -space-reserve disabled

echo Add the Mediator on each cluser
(sleep 1; cat $CRT_FILE; sleep 2; echo "" ) | sshpass -p $PASSWD ssh -l admin cluster1 security certificate install -type server-ca -vserver cluster1 -cert-name ONTAPMediatorCA
(sleep 1; cat $CRT_FILE; sleep 2; echo "" ) | sshpass -p $PASSWD ssh -l admin cluster2 security certificate install -type server-ca -vserver cluster2 -cert-name ONTAPMediatorCA

(sleep 1; echo $PASSWD; sleep 2; echo $PASSWD)| sshpass -p $PASSWD ssh -l admin cluster1 snapmirror mediator add -mediator-address $MEDIATOR_IP -peer-cluster cluster2 -username mediatoradmin -port-number $MEDIATOR_PORT
(sleep 1; echo $PASSWD; sleep 2; echo $PASSWD)| sshpass -p $PASSWD ssh -l admin cluster2 snapmirror mediator add -mediator-address $MEDIATOR_IP -peer-cluster cluster1 -username mediatoradmin -port-number $MEDIATOR_PORT

echo Create Consistency group and consistency relation 

SM_STATE=`sshpass -p $PASSWD ssh -l admin cluster2 snapmirror show -destination-path $SMBC_DST_PATH -field status |grep $SMBC_DST_PATH |awk '{print $3}'| tr -d '\r'`
echo Snapmirror Status is [$SM_STATE]
if [ "$SM_STATE" != "InSync" ]; then 
	sshpass -p $PASSWD ssh -l admin cluster2 snapmirror create -source-path $SMBC_SRC_PATH -destination-path $SMBC_DST_PATH -cg-item-mappings $VOL_NAME_P:@$VOL_NAME_S -policy AutomatedFailOver 
	SM_STATE=`sshpass -p $PASSWD ssh -l admin cluster2 snapmirror show -destination-path $SMBC_DST_PATH -field state |grep $SMBC_DST_PATH |awk '{print $3}'| tr -d '\r'`
	echo Snapmirror State is [$SM_STATE]
	[ "$SM_STATE" != "Uninitialized" ] && clean_and_exit "ERRROR: Unable to create snamirror smbc from clsuter2" 255

	sshpass -p $PASSWD ssh -l admin cluster2 snapmirror initialize -destination-path $SMBC_DST_PATH
	SM_STATE=`sshpass -p $PASSWD ssh -l admin cluster2 snapmirror show -destination-path $SMBC_DST_PATH -field status |grep $SMBC_DST_PATH |awk '{print $3}'| tr -d '\r'`
	while [ "$SM_STATE" != "InSync" ]; do
		SM_STATE=`sshpass -p $PASSWD ssh -l admin cluster2 snapmirror show -destination-path $SMBC_DST_PATH -field status |grep $SMBC_DST_PATH |awk '{print $3}'| tr -d '\r'`
		echo Please waite Snapmirror State is [$SM_STATE] ; date
		sleep 1
	done
fi

echo Create iGroup Linux
INITIATOR_NAME=`cat $LINUX_ISCSI_INITIATOR_FILE | awk -F '=' '{print $2}'`
sshpass -p $PASSWD ssh -l admin cluster1 igroup create -igroup centos01 -protocol mixed -ostype linux -initiator $INITIATOR_NAME -vserver $SVM_NAME_P
sshpass -p $PASSWD ssh -l admin cluster2 igroup create -igroup centos01 -protocol mixed -ostype linux -initiator $INITIATOR_NAME -vserver $SVM_NAME_S

sshpass -p $PASSWD ssh -l admin cluster1 lun map -vserver $SVM_NAME_P -path /vol/${VOL_NAME_P}/${LUN_NAME} -igroup centos01
sshpass -p $PASSWD ssh -l admin cluster2 lun map -vserver $SVM_NAME_S -path /vol/${VOL_NAME_S}/${LUN_NAME} -igroup centos01

clean_and_exit "Terminate" 0
