#!/bin/bash
#Pull the helpful info, all the helpful info
#How to use:
# 1. Run this command: kinit
# 2. Authenticate with your AD password
# 3. Run this tool with the user id as an arg: ./sdpull.sh <userID>
################################################################
ME=$( basename $0 )
LOG=/tmp/${ME}.log

# Validate that there is at least one argument 
if [ $# -ne 1 ]; then
	echo "Usage: ./sdpull.sh <userID>"
	echo "There was no user id passed in"
	exit 1
fi	

# This validates the user even exists
USERDN=$( ldapsearch -x -h ldapvip -LLL -s sub -b o=nmdp.org,o=nmdp.org uid="$1" dn | awk '$1 ~ /dn:/ { print $0 }' | sed 's/^dn: //' )

#This find the OU the user is in
USEROU=$(ldapsearch -x -h ldapvip -LLL -s sub -b o=nmdp.org,o=nmdp.org uid="$1" dn | awk '$1 ~ /dn:/ { print $0 }' | sed 's/^dn: //' | awk -F= '{ print $3 }' | sed 's/,o//g')

# Validate that the user actually exists in LDAP
if [[ ! $USERDN ]]; then
	echo "The user $1 cannot be found in LDAP..."
	exit 1
fi

# This is for future AD|LDAP group display
USERADGROUPS=$(ldapsearch -o ldif-wrap=no -Q -LLL -b "OU=NMDP_Users,DC=NMDP,DC=ORG" "(&(sAMAccountName=shenry2)(objectClass=User))" memberof | awk -F= '{ print $2 }' | sed 's/,OU//g')


####LOCKOUT SECTION##

#ADLOCK=$(ldapsearch -Q -LLL samaccountname="$1" )
ADLOCK=$(ldapsearch -o ldif-wrap=no -Q -LLL -b "OU=NMDP_Users,DC=NMDP,DC=ORG" "(&(sAMAccountName="$1")(objectClass=User))" lockoutTime | awk '$1 ~ /lockoutTime/ { print $2 }')

if [[ $ADLOCK -gt 0 ]]; then
	ADLOCKSTAT=$(echo "Locked")
else
	ADLOCKSTAT=$(echo "Not Locked")
fi

####TIME SECTION#####

# This looks up the password expiration date from AD
xWin=$(ldapsearch -Q -LLL samaccountname="$1" msDS-UserPasswordExpiryTimeComputed | awk '$1 ~ /msDS-UserPasswordExpiryTimeComputed/ { print $2 }')
# Check on expiration date of the AD account
xAccDate=$(ldapsearch -Q -LLL samaccountname="$1" accountExpires | awk '$1 ~ /accountExpires/ { print $2 }')

# Full LDAP string to be manipulated
LDAPFULL=$(ldapsearch -x -b "ou=$USEROU,o=nmdp.org,o=nmdp.org" -H ldap://ldapvip.nmdp.org "uid=$1" passwordExpirationTime  | egrep -v '^#|^ref|^result|search' | sed -e '/^$/d' | tail -1 | awk '$1 ~ /passwordExpirationTime/ { print $2 }')

# This is where we chop up the raw value passed in from the LDAP passwordExpirationTime attribute
LDAPYEAR=$(echo "$LDAPFULL" | cut -c 1-4)
LDAPMONTH=$(echo "$LDAPFULL" | cut -c 5-6)
LDAPDAY=$(echo "$LDAPFULL" | cut -c 7-8)
LDAPHOUR=$(echo "$LDAPFULL" | cut -c 9-10)
LDAPI=$(echo "$LDAPFULL" | cut -c 11-12)
LDAPSEC=$(echo "$LDAPFULL" | cut -c 13-14)

# Account Expiry Converter
# Converts expiry date to unix time
xAccUnix=$(echo "($xAccDate/10000000)-11644495200" | /usr/bin/bc)

# Check if the account is set to really extended end date, pretty much a "never" to me
xADaccNever=$(/bin/date -u -d @$xAccUnix | sed 's/UTC/CST/' | awk '{ print $6 }')

# Test to see if the account expires
if [[ $xAccDate -eq 0 || $xADaccNever -eq 30828 ]]; then
	xAccountDate=$(echo "Never")
else 
	# if the account does expire, format the date
	xAccountDate=$(/bin/date -u -d @$xAccUnix | sed 's/UTC/CST/')
fi

# LDAP Hour Formatted to a 12 hour clock
LDAPHF=$(echo "$LDAPHOUR-5" | /usr/bin/bc)

#Present Date in a reasonable way
DATECONV=$(date --date="$LDAPYEAR-$LDAPMONTH-$LDAPDAY $LDAPHF:$LDAPI:$LDAPSEC")

# This converts the MS date to a Unix date.
xUnix=$(echo "($xWin/10000000)-11644491600" | /usr/bin/bc)
#11644473600 correct

# This converts LDAP date to seconds so we can find the days until expiry 
xLDAP=$(date --date="$DATECONV" +%s)

# This gives us a human-readable expiration date for the AD attribute
xDate=$(/bin/date -u -d @$xUnix)

# This pulls the time from the AD date after it has been converted
adTime=$(date --date="$xDate" +%T)
adHourPlus5=$(echo $adTime | awk -F: '{ print $1 }')
adHourCHPASS=$(echo $adHourPlus5 + 05 | /usr/bin/bc)
adMinCHPASS=$(echo $adTime | awk -F: '{ print $2}')
adSecCHPASS=$(echo $adTime | awk -F: '{ print $3}')

# This gives us a Unix date value for right now.
today=$(/bin/date +%s)

# This uses some simple math to get the number of days between
# today and the date the password expires.
xDays=$(echo "($xUnix - $today)/60/60/24" | /usr/bin/bc)

# LDAP Days until expiry
lDays=$(echo "($xLDAP - $today)/60/60/24" | /usr/bin/bc)

# Day to convert so we can get the correct LDAP expiry day count
lExpiryDay=$(echo "($lDays)" | /usr/bin/bc)

# Math to figure out when the LDAP password was changed
lDayDiff=$(echo "(59 - $lDays)" | /usr/bin/bc)

# Math to figure out what the AD password was changed
adDayDiff=$(echo "(59 - $xDays)" | /usr/bin/bc)

# LDAP Password changed date
LDAPCHPASS=$(echo "$(date --date="$lDayDiff days ago $LDAPHF:$LDAPI:$LDAPSEC")")
# AD Password changed date
ADCHPASS=$(echo "$(TZ=":America/Chicago" date --date="$adDayDiff days ago $adHourCHPASS:$adMinCHPASS:$adSecCHPASS")")

# Show the results
echo "-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-"
echo "Username:                              $1"
echo "AD Expiration date:                    $xDate"
echo "LDAP Expiration date:                  $DATECONV"
echo "Number of days until AD expiry:        $xDays"
echo "Number of days until LDAP expiry:      $lExpiryDay"
echo "AD Password Changed:                   $ADCHPASS"
echo "LDAP Password Changed:                 $LDAPCHPASS"
echo "AD Account lock status:                $ADLOCKSTAT"
echo "AD Account Expiry Date:                $xAccountDate"
echo "-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-"
#Future Info Pull
#echo "-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-"
#echo "-------------------AD Groups---------------------"
#echo "$USERADGROUPS"
