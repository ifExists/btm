#!/bin/bash

SDPULL=~/servicedesk-admin/scripts/pull_user_info/sdpull.sh
CCUSER=~/servicedesk-admin/scripts/casemgm_auto_create/massAddLDAPtool.sh
LGADD=~/servicedesk-admin/scripts/add_single_group/addSingleGroup.sh
TCUSERADD=~/servicedesk-admin/scripts/traxis_tc_user_create/massAddLDAPtool.sh
# Bashrc to be updated with new aliases
BRC=~/.bashrc

printf "\nsdpull () {\n $SDPULL \$1 \n}\n" >> $BRC
printf "\nccuser () {\n $CCUSER \n}\n" >> $BRC
printf "\nlgadd () {\n $LGADD \n}\n" >> $BRC
printf "\ntcuseradd () {\n $TCUSERADD \n}\n" >> $BRC

echo "You've unlocked 4 new commands!"

echo "     =="
echo "     ||_________________________"
echo "OOOOO||_________________________>"
echo "     ||"
echo "     =="

echo "........You now have..........."
echo "ccuser"
echo "lgadd"
echo "tcuseradd"
echo "sdpull"
echo "+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-"
echo "View the \"README.md\" file for more information"

. $BRC

exec bash
