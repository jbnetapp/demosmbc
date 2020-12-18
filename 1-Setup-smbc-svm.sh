#!/bin/bash
set -x

DIRNAME=`dirname $0`
CONFIG_FILE=${DIRNAME}/Setup.conf

if [ ! -f $CONFIG_FILE ] ; then
	echo "ERROR: Unable to read $CONFIG_FILE"
	exit 1
fi

. $CONFIG_FILE

clean_and_exit(){
        echo $0
        exit
}


# Main
echo Init SSH session host 
SSH_Name=`cat $HOME/.ssh/known_hosts  | awk -F',' -v cluster_name=cluster1 '{if ( $1 == cluster_name ) print $1}'`
[ -z $SSH_Name ] &&  ssh -l admin cluster1 exit

SSH_Name=`cat $HOME/.ssh/known_hosts  | awk -F',' -v cluster_name=cluster1 '{if ( $1 == cluster_name ) print $1}'`
[ -z $SSH_Name ] &&  ssh -l admin cluster2 exit

echo Create InteCluser LIF cluster1
sshpass -p $PASSWD ssh -l admin cluster1 version 
sshpass -p $PASSWD ssh -l admin cluster1 network interface create -vserver cluster1 -lif intercluster1 -address 192.168.0.115 -netmask-length 24 -home-node cluster1-01 -service-policy default-intercluster -home-port e0g -status-admin up
sshpass -p $PASSWD ssh -l admin cluster1 network interface create -vserver cluster1 -lif intercluster2 -address 192.168.0.116 -netmask-length 24 -home-node cluster1-02 -service-policy default-intercluster -home-port e0g -status-admin up

echo Create InteCluser LIF cluster2
sshpass -p $PASSWD ssh -l admin cluster2 version
sshpass -p $PASSWD ssh -l admin cluster2 network interface create -vserver cluster2 -lif intercluster1 -address 192.168.0.117 -netmask-length 24 -home-node cluster2-01 -service-policy default-intercluster -home-port e0g -status-admin up
sshpass -p $PASSWD ssh -l admin cluster2 network interface create -vserver cluster2 -lif intercluster2 -address 192.168.0.118 -netmask-length 24 -home-node cluster2-02 -service-policy default-intercluster -home-port e0g -status-admin up


(sleep 1; echo $PASSWD ; sleep 5; echo $PASSWD )| sshpass -p $PASSWD ssh -l admin cluster1 cluster peer create -address-family ipv4 -peer-addrs 192.168.0.117
(sleep 1; echo $PASSWD ; sleep 5; echo $PASSWD )| sshpass -p $PASSWD ssh -l admin cluster2 cluster peer create -address-family ipv4 -peer-addrs 192.168.0.115
cpr=`sshpass -p $PASSWD ssh -l admin cluster2 cluster peer show -fields Availability | grep cluster1`
[ -z "$cpr" ] && clean_and_exit "Error Unable to create cluster peer from cluster2"
sshpass -p $PASSWD ssh -l admin cluster1 cluster peer show 
sshpass -p $PASSWD ssh -l admin cluster2 cluster peer show 

echo Create $SVM_P cluster1
sshpass -p $PASSWD ssh -l admin cluster1 vserver create -vserver $SVM_P -subtype default 
sshpass -p $PASSWD ssh -l admin cluster1 vserver iscsi create -target-alias $SVM_P -status-admin up
sshpass -p $PASSWD ssh -l admin cluster1 network interface create -vserver $SVM_P -lif ${SVM_P}_admin -service-policy default-data-files -address 192.168.0.130 -netmask-length 24 -home-node cluster1-01 -home-port e0g -firewall-policy mgmt
sshpass -p $PASSWD ssh -l admin cluster1 network interface create -vserver $SVM_P -lif ${SVM_P}_data1 -service-policy default-data-blocks -address 192.168.0.131 -netmask-length 24 -home-node cluster1-01 -home-port e0g -firewall-policy data
sshpass -p $PASSWD ssh -l admin cluster1 network interface create -vserver $SVM_P -lif ${SVM_P}_data2 -service-policy default-data-blocks -address 192.168.0.132 -netmask-length 24 -home-node cluster1-02 -home-port e0g -firewall-policy data
sshpass -p $PASSWD ssh -l admin cluster1 network interface create -vserver $SVM_P -lif ${SVM_P}_data3 -service-policy default-data-blocks -address 192.168.0.133 -netmask-length 24 -home-node cluster1-01 -home-port e0g -firewall-policy data
sshpass -p $PASSWD ssh -l admin cluster1 network interface create -vserver $SVM_P -lif ${SVM_P}_data4 -service-policy default-data-blocks -address 192.168.0.134 -netmask-length 24 -home-node cluster1-02 -home-port e0g -firewall-policy data

echo Create $SVM_S cluster2
sshpass -p $PASSWD ssh -l admin cluster2 vserver create -vserver $SVM_S -subtype default 
sshpass -p $PASSWD ssh -l admin cluster2 vserver iscsi create -target-alias $SVM_S -status-admin up
sshpass -p $PASSWD ssh -l admin cluster2 network interface create -vserver $SVM_S -lif ${SVM_S}_admin -service-policy default-data-files -address 192.168.0.140 -netmask-length 24 -home-node cluster2-01 -home-port e0g -firewall-policy mgmt
sshpass -p $PASSWD ssh -l admin cluster2 network interface create -vserver $SVM_S -lif ${SVM_S}_data1 -service-policy default-data-blocks -address 192.168.0.141 -netmask-length 24 -home-node cluster2-01 -home-port e0g -firewall-policy data
sshpass -p $PASSWD ssh -l admin cluster2 network interface create -vserver $SVM_S -lif ${SVM_S}_data2 -service-policy default-data-blocks -address 192.168.0.142 -netmask-length 24 -home-node cluster2-02 -home-port e0g -firewall-policy data
sshpass -p $PASSWD ssh -l admin cluster2 network interface create -vserver $SVM_S -lif ${SVM_S}_data3 -service-policy default-data-blocks -address 192.168.0.143 -netmask-length 24 -home-node cluster2-01 -home-port e0g -firewall-policy data
sshpass -p $PASSWD ssh -l admin cluster2 network interface create -vserver $SVM_S -lif ${SVM_S}_data4 -service-policy default-data-blocks -address 192.168.0.144 -netmask-length 24 -home-node cluster2-02 -home-port e0g -firewall-policy data

echo Create svm relatoin 
sshpass -p $PASSWD ssh -l admin cluster1 vserver peer create -vserver $SVM_P -peer-vserver $SVM_S -applications snapmirror -peer-cluster cluster2
while [ -z $STATUS ] ; do 
	sleep 5 
	STATUS=`sshpass -p $PASSWD ssh -l admin cluster2 vserver peer show |grep $SVM_S |awk '{ print $3}'`
	echo $STATUS
done
sshpass -p $PASSWD ssh -l admin cluster2 vserver peer accept -vserver $SVM_S -peer-vserver $SVM_P

# Gets Free Data Aggregate
AGGR_DATA_CL1=`sshpass -p 'Netapp1!' ssh -l admin cluster1 aggr show -root false |grep online |sort -k2 -u | tail -1 |awk '{print $1}'`
AGGR_DATA_CL2=`sshpass -p 'Netapp1!' ssh -l admin cluster2 aggr show -root false |grep online |sort -k2 -u | tail -1 |awk '{print $1}'`
sshpass -p $PASSWD ssh -l admin cluster1 volume create -volume $VOL_NAME_P -vserver $SVM_P -aggregate $AGGR_DATA_CL1 -size $SIZE -autosize-mode grow -state online
sshpass -p $PASSWD ssh -l admin cluster2 volume create -volume $VOL_NAME_S -vserver $SVM_S -aggregate $AGGR_DATA_CL2 -size $SIZE -autosize-mode grow -type DP -state online 
U_SIZE=`echo $SIZE|sed -e s/[0-9]//g`
N_SIZE=`echo $SIZE|sed -e s/[a-zA-Z]//g`
LUN_SIZE=$(($N_SIZE - 1))${U_SIZE}

sshpass -p $PASSWD ssh -l admin cluster1 lun create -vserver $SVM_P -path /vol/${VOL_NAME_P}/${LUN_NAME} -size $LUN_SIZE -ostype Linux -space-reserve disabled

echo Add the Mediator on each cluser
(sleep 1; cat $CRT_FILE; sleep 5; echo "" ) | sshpass -p $PASSWD ssh -l admin cluster1 security certificate install -type server-ca -vserver cluster1 -cert-name ONTAPMediatorCA
(sleep 1; cat $CRT_FILE; sleep 5; echo "" ) | sshpass -p $PASSWD ssh -l admin cluster2 security certificate install -type server-ca -vserver cluster2 -cert-name ONTAPMediatorCA

(sleep 1; echo $PASSWD; sleep 5; echo $PASSWD)| sshpass -p $PASSWD ssh -l admin cluster1 snapmirror mediator add -mediator-address $MEDIATOR_IP -peer-cluster cluster2 -username mediatoradmin -port-number $MEDIATOR_PORT
(sleep 1; echo $PASSWD; sleep 5; echo $PASSWD)| sshpass -p $PASSWD ssh -l admin cluster2 snapmirror mediator add -mediator-address $MEDIATOR_IP -peer-cluster cluster1 -username mediatoradmin -port-number $MEDIATOR_PORT

echo Create Consistency group and consistency relation 
sshpass -p $PASSWD ssh -l admin cluster2 snapmirror create -source-path $SMBC_SRC_PATH -destination-path $SMBC_DST_PATH -cg-item-mappings $VOL_NAME_P:@$VOL_NAME_S -policy AutomatedFailOver 
SM_STATE=`sshpass -p $PASSWD ssh -l admin cluster2 snapmirror show -destination-path $SMBC_DST_PATH -field state |grep $SMBC_DST_PATH |awk '{print $3}'`
while [ "$SM_STATE" != "Uninitialized" ];  do
	SM_STATE=`sshpass -p $PASSWD ssh -l admin cluster2 snapmirror show -destination-path $SMBC_DST_PATH -field state |grep $SVM_S:/cg/cg_s |awk '{print $3}'`
	echo Please waite Snapmirror State is [$SM_STATE] ; date
	sleep 2
done

sshpass -p $PASSWD ssh -l admin cluster2 snapmirror initialize -destination-path $SMBC_DST_PATH
while [ "$SM_STATE" != "InSync" ];  do
	SM_STATE=`sshpass -p $PASSWD ssh -l admin cluster2 snapmirror show -destination-path $SMBC_DST_PATH -field status |grep $SVM_S:/cg/cg_s |awk '{print $3}'`
	echo Please waite Snapmirror State is [$SM_STATE] ; date
	sleep 2
done

[ -f $TMPFILE ] && rm $TMPFILE

echo Create iGroup Linux
INITIATOR_NAME=`cat $LINUX_ISCSI_INITIATOR_FILE | awk -F '=' '{print $2}'`
sshpass -p $PASSWD ssh -l admin cluster1 igroup create -igroup centos01 -protocol mixed -ostype linux -initiator $INITIATOR_NAME -vserver $SVM_P
sshpass -p $PASSWD ssh -l admin cluster2 igroup create -igroup centos01 -protocol mixed -ostype linux -initiator $INITIATOR_NAME -vserver $SVM_S

sshpass -p $PASSWD ssh -l admin cluster1 lun map -vserver $SVM_P -path /vol/${VOL_NAME_P}/${LUN_NAME} -igroup centos01
sshpass -p $PASSWD ssh -l admin cluster2 lun map -vserver $SVM_S -path /vol/${VOL_NAME_S}/${LUN_NAME} -igroup centos01
