#!/bin/bash
#This is intended to be run on Macs
#when the local password is out of sync with AD password
#This script will force local/AD to sync
#Sean Henry

USER=$(whoami)

USERID=$(sudo fdesetup list | grep $USER)

echo $USERID

