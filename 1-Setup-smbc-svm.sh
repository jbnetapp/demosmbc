#!/bin/bash
set -x
TMPFILE=/tmp/file.$$
PWD='Netapp1!'

echo Init SSH session host 
SSH_Name=`cat $HOME/.ssh/known_hosts  | awk -F',' -v cluster_name=cluster1 '{if ( $1 == cluster_name ) print $1}'`
[ -z $SSH_Name ] &&  ssh -l admin cluster1 exit

SSH_Name=`cat $HOME/.ssh/known_hosts  | awk -F',' -v cluster_name=cluster1 '{if ( $1 == cluster_name ) print $1}'`
[ -z $SSH_Name ] &&  ssh -l admin cluster2 exit

echo Create InteCluser LIF cluster1
sshpass -p $PWD ssh -l admin cluster1 version 
sshpass -p $PWD ssh -l admin cluster1 network interface create -vserver cluster1 -lif intercluster1 -address 192.168.0.115 -netmask-length 24 -home-node cluster1-01 -service-policy default-intercluster -home-port e0g -status-admin up
sshpass -p $PWD ssh -l admin cluster1 network interface create -vserver cluster1 -lif intercluster2 -address 192.168.0.116 -netmask-length 24 -home-node cluster1-02 -service-policy default-intercluster -home-port e0g -status-admin up
sshpass -p $PWD ssh -l admin cluster1 cluster peer policy modify -is-unauthenticated-access-permitted true
sshpass -p $PWD ssh -l admin cluster1 cluster peer policy modify -is-unencrypted-access-permitted true

echo Create InteCluser LIF cluster2
sshpass -p $PWD ssh -l admin cluster2 version
sshpass -p $PWD ssh -l admin cluster2 network interface create -vserver cluster2 -lif intercluster1 -address 192.168.0.117 -netmask-length 24 -home-node cluster2-01 -service-policy default-intercluster -home-port e0g -status-admin up
sshpass -p $PWD ssh -l admin cluster2 network interface create -vserver cluster2 -lif intercluster2 -address 192.168.0.118 -netmask-length 24 -home-node cluster2-02 -service-policy default-intercluster -home-port e0g -status-admin up
sshpass -p $PWD ssh -l admin cluster2 cluster peer policy modify -is-unauthenticated-access-permitted true
sshpass -p $PWD ssh -l admin cluster2 cluster peer policy modify -is-unencrypted-access-permitted true

sshpass -p $PWD ssh -l admin cluster1 cluster peer create -address-family ipv4 -peer-addrs 192.168.0.117 -no-authentication
sshpass -p $PWD ssh -l admin cluster2 cluster peer create -address-family ipv4 -peer-addrs 192.168.0.115 -no-authentication

sshpass -p $PWD ssh -l admin cluster1 cluster peer show 
sshpass -p $PWD ssh -l admin cluster2 cluster peer show 

echo Create SVM_SAN_P cluster1
sshpass -p $PWD ssh -l admin cluster1 vserver create -vserver SVM_SAN_P -subtype default 
sshpass -p $PWD ssh -l admin cluster1 vserver iscsi create -target-alias SVM_SAN_P -status-admin up
sshpass -p $PWD ssh -l admin cluster1 network interface create -vserver SVM_SAN_P -lif SVM_SAN_P_admin -service-policy default-data-files -address 192.168.0.130 -netmask-length 24 -home-node cluster1-01 -home-port e0g -firewall-policy mgmt
sshpass -p $PWD ssh -l admin cluster1 network interface create -vserver SVM_SAN_P -lif SVM_SAN_P_data1 -service-policy default-data-blocks -address 192.168.0.131 -netmask-length 24 -home-node cluster1-01 -home-port e0g -firewall-policy data
sshpass -p $PWD ssh -l admin cluster1 network interface create -vserver SVM_SAN_P -lif SVM_SAN_P_data2 -service-policy default-data-blocks -address 192.168.0.132 -netmask-length 24 -home-node cluster1-02 -home-port e0g -firewall-policy data
sshpass -p $PWD ssh -l admin cluster1 network interface create -vserver SVM_SAN_P -lif SVM_SAN_P_data3 -service-policy default-data-blocks -address 192.168.0.133 -netmask-length 24 -home-node cluster1-01 -home-port e0g -firewall-policy data
sshpass -p $PWD ssh -l admin cluster1 network interface create -vserver SVM_SAN_P -lif SVM_SAN_P_data4 -service-policy default-data-blocks -address 192.168.0.134 -netmask-length 24 -home-node cluster1-02 -home-port e0g -firewall-policy data

echo Create SVM_SAN_S cluster2
sshpass -p $PWD ssh -l admin cluster2 vserver create -vserver SVM_SAN_S -subtype default 
sshpass -p $PWD ssh -l admin cluster2 vserver iscsi create -target-alias SVM_SAN_S -status-admin up
sshpass -p $PWD ssh -l admin cluster2 network interface create -vserver SVM_SAN_S -lif SVM_SAN_S_admin -service-policy default-data-files -address 192.168.0.140 -netmask-length 24 -home-node cluster2-01 -home-port e0g -firewall-policy mgmt
sshpass -p $PWD ssh -l admin cluster2 network interface create -vserver SVM_SAN_S -lif SVM_SAN_S_data1 -service-policy default-data-blocks -address 192.168.0.141 -netmask-length 24 -home-node cluster2-01 -home-port e0g -firewall-policy data
sshpass -p $PWD ssh -l admin cluster2 network interface create -vserver SVM_SAN_S -lif SVM_SAN_S_data2 -service-policy default-data-blocks -address 192.168.0.142 -netmask-length 24 -home-node cluster2-02 -home-port e0g -firewall-policy data
sshpass -p $PWD ssh -l admin cluster2 network interface create -vserver SVM_SAN_S -lif SVM_SAN_S_data3 -service-policy default-data-blocks -address 192.168.0.143 -netmask-length 24 -home-node cluster2-01 -home-port e0g -firewall-policy data
sshpass -p $PWD ssh -l admin cluster2 network interface create -vserver SVM_SAN_S -lif SVM_SAN_S_data4 -service-policy default-data-blocks -address 192.168.0.144 -netmask-length 24 -home-node cluster2-02 -home-port e0g -firewall-policy data

echo Create svm relatoin 
sshpass -p $PWD ssh -l admin cluster1 vserver peer create -vserver SVM_SAN_P -peer-vserver SVM_SAN_S -applications snapmirror -peer-cluster cluster2
while [ -z $STATUS ] ; do 
	sleep 5 
	STATUS=`sshpass -p $PWD ssh -l admin cluster2 vserver peer show |grep SVM_SAN_S |awk '{ print $3}'`
	echo $STATUS
done
sshpass -p $PWD ssh -l admin cluster2 vserver peer accept -vserver SVM_SAN_S -peer-vserver SVM_SAN_P

[ -f $TMPFILE ] && rm $TMPFILE
