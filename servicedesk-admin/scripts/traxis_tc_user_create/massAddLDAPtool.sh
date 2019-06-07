#!/bin/bash
# You may be asking yourself, what does this thing do?
# This script will add multiple groups to a user - well, 
# it will actually be adding a user to multiple groups
# The format of this command will look like what is shown below:

# ./addMulGroups.sh groups.csv 

# CSV file containing groups to add to a user
GROUPCSV=~/servicedesk-admin/scripts/traxis_tc_user_create/tcUserGroups.csv

# Randers stuff because he hates typing
ME=$( basename $0 )
LOG=/tmp/${ME}.log

if [ ! -f $GROUPCSV ]; then
	echo "$GROUPCSV does not exist, bye bye"
	exit 1
fi

# Find the group's DN
# Figure out who is running this, then use that as the LDAP account that'll add the groups to the user
ADMIN=$( ldapsearch -x -h ldapvip -LLL -s sub -b o=nmdp.org,o=nmdp.org uid=${LOGNAME} dn | awk '$1 ~ /dn:/ { print $2 }' )
# Need the password for $ADMIN
printf "\n${ME}: Enter LDAP password for ${ADMIN}\nThis account will add the users to the groups from the groups.csv file\n\n"
echo -n "Enter password: "
read -s SECRET
echo ""


printf "What is the user that you'd like to add all of these groups to? "
read user;

USERDN=$( ldapsearch -x -h ldapvip -LLL -s sub -b o=nmdp.org,o=nmdp.org uid=${user} dn | awk '$1 ~ /dn:/ { print $0 }' | sed 's/^dn: //' )

if [ ! "$USERDN" ]; then
	echo "User: $user not found in App LDAP"
	exit 1
fi


IFS=','
for grp in $(cat $GROUPCSV); do

	ldapsearch -x -h ldapvip -LLL -s sub -b o=nmdp.org,o=nmdp.org cn=${grp} uniqueMember | grep "${user}" &>/dev/null
	if [ $? -eq 1 ]; then


		GDN=$( ldapsearch -x -h ldapvip -LLL -s sub -b o=nmdp.org,o=nmdp.org cn="${grp}" dn | awk '$1 ~ /dn:/ { print $0 }' | sed 's/dn: //' )


		echo ${USERDN}
		echo ${GDN}

		printf "Attempting to add $user to $GDN\n\n" | tee -a $LOG
		echo
		echo "version: 1

		dn: ${GDN}
		changetype: modify
		add: uniqueMember
		uniqueMember: ${USERDN}" | ldapmodify -x -h ldapvip -D "${ADMIN}" -w "${SECRET}"
		#echo "Would have added ${USERDN} to ${GDN}"
		echo "Added ${USERDN} to ${GDN}"
	else
		printf "Group: ${grp} is already assigned to ${user}\n\n" | tee -a $LOG
	fi

done

