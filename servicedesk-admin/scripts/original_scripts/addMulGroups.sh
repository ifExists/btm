#!/bin/bash
# You may be asking yourself, what does this thing do?
# This script will add multiple groups to a user - well, 
# it will actually be adding a user to multiple groups
# The format of this command will look like what is shown below:

# ./addMulGroups.sh groups.csv <userName>

# Meaning, it accepts two arguments and the groups are the list of groups that will be added to the single user

# CSV file containing groups to add to a user
GROUPCSV=$1
# User to add the groups to
user="$2"
# Randers stuff because he hates typing
ME=$( basename $0 )
LOG=/tmp/${ME}.log

if [ ! -f $GROUPCSV ]; then
  echo "$GROUPCSV does not exist, bye bye"
  exit 1
fi

if [ $# -ne 2 ]; then
  echo "Usage: $0 group.CSV \"groups-to-add-to\""
  exit 1
fi

# Find the group's DN
# Figure out who is running this, then use that as the LDAP account that'll remove the users from groups
ADMIN=$( ldapsearch -x -h ldapvip -LLL -s sub -b o=nmdp.org,o=nmdp.org uid=${LOGNAME} dn | awk '$1 ~ /dn:/ { print $2 }' )
# Need the password for $ADMIN
printf "\n${ME}: Enter LDAP password for ${ADMIN}\nThis account will add the users to the groups from the groups.csv file\n\n"
echo -n "Enter password: "
read -s SECRET
echo ""


USERDN=$( ldapsearch -x -h ldapvip -LLL -s sub -b o=nmdp.org,o=nmdp.org uid=${user} dn | awk '$1 ~ /dn:/ { print $0 }' | sed 's/^dn: //' )

if [ ! "$USERDN" ]; then
  echo "User: $user not found in App LDAP"
  exit 1
fi


#GROUPS=$(cat $GROUPCSV)
IFS=','
for grp in $(cat $GROUPCSV); do

  ldapsearch -x -h ldapvip -LLL -s sub -b o=nmdp.org,o=nmdp.org cn=${grp} uniqueMember | grep "${user}" &>/dev/null
  if [ $? -eq 1 ]; then

  # GDN=$( ldapsearch -x -h ldapvip -LLL -s sub -b o=nmdp.org,o=nmdp.org cn="${grp}" dn | awk '$1 ~ /dn:/ { print $0 }' | sed 's/dn: //' )
   
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
   # echo "Would have added ${USERDN} to ${GDN}"
	echo "Added ${USERDN} to ${GDN}"
  else
    printf "Group: ${grp} is already assigned to ${user}\n\n" | tee -a $LOG
  fi

done

