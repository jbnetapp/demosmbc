#!/bin/bash
set -x
TMPFILE=/tmp/file.$$
PWD='Netapp1!'

echo Init SSH session host 
SSH_Name=`cat $HOME/.ssh/known_hosts  | awk -F',' -v cluster_name=cluster1 '{if ( $1 == cluster_name ) print $1}'`
[ -z $SSH_Name ] &&  ssh -l admin cluster1 exit

SSH_Name=`cat $HOME/.ssh/known_hosts  | awk -F',' -v cluster_name=cluster1 '{if ( $1 == cluster_name ) print $1}'`
[ -z $SSH_Name ] &&  ssh -l admin cluster2 exit
echo Delete Vserver relation 
sshpass -p $PWD ssh -l admin cluster1 vserver peer delete -vserver SVM_SAN_P -peer-vserver SVM_SAN_S
sleep 5

echo Delete Vserver SVM_SAN_S
sshpass -p $PWD ssh -l admin cluster2 network interface modify -vserver SVM_SAN_S -lif SVM_SAN_S_* -status-admin down
sshpass -p $PWD ssh -l admin cluster2 network interface delete -vserver SVM_SAN_S -lif SVM_SAN_S_* 
sshpass -p $PWD ssh -l admin cluster2 vserver delete -vserver SVM_SAN_S

echo Delete Vserver SVM_SAN_P
sshpass -p $PWD ssh -l admin cluster1 network interface modify -vserver SVM_SAN_P -lif SVM_SAN_P_* -status-admin down
sshpass -p $PWD ssh -l admin cluster1 network interface delete -vserver SVM_SAN_P -lif SVM_SAN_P_* 
sshpass -p $PWD ssh -l admin cluster1 vserver delete -vserver SVM_SAN_P

echo Delete Peer Cluser
sshpass -p $PWD ssh -l admin cluster1 cluster peer delete -cluster cluster2 
sshpass -p $PWD ssh -l admin cluster2 cluster peer delete -cluster cluster1
sleep 5

echo Create InteCluser LIF cluster1
sshpass -p $PWD ssh -l admin cluster1 version 
sshpass -p $PWD ssh -l admin cluster1 network interface modify -vserver cluster1 -lif intercluster1 -status-admin down
sshpass -p $PWD ssh -l admin cluster1 network interface modify -vserver cluster1 -lif intercluster2 -status-admin down 
sshpass -p $PWD ssh -l admin cluster1 network interface delete -vserver cluster1 -lif intercluster1
sshpass -p $PWD ssh -l admin cluster1 network interface delete -vserver cluster1 -lif intercluster2
sshpass -p $PWD ssh -l admin cluster1 cluster peer policy modify -is-unauthenticated-access-permitted false 
sshpass -p $PWD ssh -l admin cluster1 cluster peer policy modify -is-unencrypted-access-permitted false 

echo Create InteCluser LIF cluster2
sshpass -p $PWD ssh -l admin cluster2 version
sshpass -p $PWD ssh -l admin cluster2 network interface modify -vserver cluster2 -lif intercluster1 -status-admin down 
sshpass -p $PWD ssh -l admin cluster2 network interface modify -vserver cluster2 -lif intercluster2 -status-admin down 
sshpass -p $PWD ssh -l admin cluster2 network interface delete -vserver cluster2 -lif intercluster1
sshpass -p $PWD ssh -l admin cluster2 network interface delete -vserver cluster2 -lif intercluster2
sshpass -p $PWD ssh -l admin cluster2 cluster peer policy modify -is-unauthenticated-access-permitted false 
sshpass -p $PWD ssh -l admin cluster2 cluster peer policy modify -is-unencrypted-access-permitted false



[ -f $TMPFILE ] && rm $TMPFILE
