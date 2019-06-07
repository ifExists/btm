SECRET="Thisismaster!2"
USERCSV=$1
# CN of group to delete from
g="$2"
ME=$( basename $0 )
LOG=/tmp/${ME}.log

if [ ! -f $USERCSV ]; then
	echo "$USERCSV does not exist, bye bye"
	exit 1
fi

if [ $# -ne 2 ]; then
	echo "Usage: $0 user.CSV \"group-to-remove-from\""
	exit 1
fi

# Figure out who is running this, then use that as the LDAP account that'll remove the users from groups
ADMIN=$( ldapsearch -x -h ldapvip -LLL -s sub -b o=nmdp.org,o=nmdp.org uid=${LOGNAME} dn | awk '$1 ~ /dn:/ { print $2 }' )
# Need the password for $ADMIN
if [[ ! $SECRET ]]; then
	printf "\n${ME}: Enter LDAP password for ${ADMIN}\nThis account will remove the users from group ${g}\n\n"
	echo -n "Enter password: "
	read -s SECRET
	echo ""
fi
# Find the group's DN
GDN=$( ldapsearch -x -h ldapvip -LLL -s sub -b o=nmdp.org,o=nmdp.org cn="${g}" dn | awk '$1 ~ /dn:/ { print $0 }' | sed 's/dn: //' )

if [ ! "$GDN" ]; then
	echo "Group $g not found in App LDAP"
	exit 1
fi

USERS=$( echo $USERCSV )
IFS=','

for u in $(cat $USERS); do
	ldapsearch -x -h ldapvip -LLL -s sub -b o=nmdp.org,o=nmdp.org uid=${u} memberof | grep "$g" &>/dev/null
	if [ $? -eq 0 ]; then
		USERDN=$( ldapsearch -x -h ldapvip -LLL -s sub -b o=nmdp.org,o=nmdp.org uid=${u} dn | awk '$1 ~ /dn:/ { print $0 }' | sed 's/^dn: //' )
		#echo $USERDN

		printf "Attempting to remove $u from $GDN\n\n" | tee -a $LOG
		echo
		echo "version: 1

		dn: ${GDN}
		changetype: modify
		delete: uniqueMember
		uniqueMember: ${USERDN}" | ldapmodify -x -h ldapvip -D "${ADMIN}" -w "${SECRET}"
		echo
		echo "This is the user: ${u}"
		echo "This is the group: ${GDN}"
	else
		printf "User ${u} is not in group ${GDN}\n\n" | tee -a $LOG
	fi

done

printf "\nSee logs in $LOG\n\n"
