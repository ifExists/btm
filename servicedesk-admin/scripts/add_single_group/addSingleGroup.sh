#MYUSER=$1
# CN of group to delete from
#MYGROUP="$2"
ME=$( basename $0 )
LOG=/tmp/${ME}.log


#if [ $# -ne 2 ]; then
#	echo "Usage: $0 user \"group-to-add-to\""
#	exit 1
#fi


printf "What is the user id to add the group to? "
read MYUSER
printf "\nWhat is the group to add to the user? "
read MYGROUP

# Find the group's DN
GDN=$( ldapsearch -x -h ldapvip -LLL -s sub -b o=nmdp.org,o=nmdp.org cn="${MYGROUP}" dn | awk '$1 ~ /dn:/ { print $0 }' | sed 's/dn: //' )

if [[ ! $GDN ]]; then
	echo "Group $MYGROUP not found in App LDAP"
	exit 1
fi

# Validate the user exists
USERDN=$( ldapsearch -x -h ldapvip -LLL -s sub -b o=nmdp.org,o=nmdp.org uid=${MYUSER} dn | awk '$1 ~ /dn:/ { print $0 }' | sed 's/^dn: //' )

if [[ ! $USERDN ]]; then
	echo "User $MYUSER is not found in App LDAP"
	exit 1
fi

# Figure out who is running this, then use that as the LDAP account that'll remove the users from groups
ADMIN=$( ldapsearch -x -h ldapvip -LLL -s sub -b o=nmdp.org,o=nmdp.org uid=${LOGNAME} dn | awk '$1 ~ /dn:/ { print $2 }' )
# Need the password for $ADMIN
if [[ ! $SECRET ]]; then
	printf "\n${ME}: Enter LDAP password for ${ADMIN}\nThis account will add the user ${MYUSER} to the group ${MYGROUP}\n\n"
	echo -n "Enter password: "
	read -s SECRET
	echo ""
fi

printf "Attempting to add $MYUSER to $GDN\n\n" | tee -a $LOG
echo
echo "version: 1

dn: ${GDN}
changetype: modify
add: uniqueMember
uniqueMember: ${USERDN}

uniqueMember: ${USERDN}" | ldapmodify -x -h ldapvip -D "${ADMIN}" -w "${SECRET}"
echo "Adding ${USERDN} to ${GDN}"

printf "\nSee logs in $LOG\n\n"
