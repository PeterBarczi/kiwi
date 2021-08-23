#!/bin/bash
#
#Description: Script to configure or un-configure patching service for VMC on AWS from DT

#AUTHOR="TSI VMC DevOps"
#CONTACT="DL-TSI-VMC-DevOps@t-systems.com"
#DATE="20.08.2021"
#VERSION="1_0-1"
#Version history
#1_0-0          TSI VMC DevOps		first version.
#1_0-1		TSI VMC DevOps		some bugfixes


URL="rmt.eu-central-1.vmcdev.t-systems.net"

source /etc/os-release

RELEASE=$(echo $VERSION|awk -F"-" '{print $1}')
SP=$(echo $VERSION|awk -F"-" '{print $2}')

if [ $1 == "start" ]
then
        "">/etc/zypp/repos.d/products
        logger -p INFO -t Patch-service "Going to download scripts for patching."
        wget https://${URL}/repo/client_scripts/SLES-${RELEASE}.sh -O /tmp/SLES-${RELEASE}.sh
        wget https://${URL}/repo/client_scripts/SLES-${RELEASE}${SP}.sh -O /tmp/SLES-${RELEASE}${SP}.sh
        sh  /tmp/SLES-${RELEASE}.sh
        sh /tmp/SLES-${RELEASE}${SP}.sh
        zypper --gpg-auto-import-keys ref
        systemctl disable patch-service
elif [ $1 == "stop" ]
then
        logger -p info -t Patch-service "Removing repositories providing by patching service."
        for i in `cat /etc/zypp/repos.d/products`; do zypper rr $i;done
else
        logger -p error -t Patch-service "Script $0 expect parameter start or stop. systemctl start|stop patch-service \n"
        exit 1
fi
