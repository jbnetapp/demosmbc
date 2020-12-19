#
# Bash Functions
# v01
#
clean_and_exit(){
        echo $1
        exit $2
}

check_ssh_keyhost(){
	cluster_name=$1
	SSH_Name=`cat $HOME/.ssh/known_hosts  | awk -v cluster_name=$cluster_name '{if ( $1 == cluster_name ) print $1}'`
	[ -z $SSH_Name ] &&  ssh-keyscan $cluster_name >> $HOME/.ssh/known_hosts 
}
