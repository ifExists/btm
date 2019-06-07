#!/bin/bash 
# This is responsible for calling the add user groups scripts
# Creating modularization for this project
BASE=$( basename $0  )
SCRIPT="./group_adder_script.sh"
USERS="users.csv"
MASSGROUPS="groups.csv"
LOG=/tmp/${BASE}.log

printf "This script will add multiple groups to multiple users...\n"
printf "Update the \"user.csv\" file in this directory with all of the users that need the groups added\n"
printf "Update the \"groups.csv\" file in this directory will all of the groups to be added to the users\n"
printf "..........................................................\n"
printf "Preparing script\n"
sleep 3

IFS=','
for u in $(cat $USERS); 
do
	for g in $(cat $MASSGROUPS); do
		$SCRIPT $u $g
	done 
done
