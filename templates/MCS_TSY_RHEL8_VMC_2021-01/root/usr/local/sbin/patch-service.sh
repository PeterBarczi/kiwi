#!/bin/bash
#
#Description: Script to configure or un-configure patching service for RHEL - VMC on AWS from DT
#Author: Jan Kukurugya
#Version: 1.0
#Date: 15.3.2021

source /etc/os-release
RELEASE=$(echo $VERSION|awk -F"." '{print $1}')

if [ $1 == "start" ]
then

        logger -p INFO -t Patch-service "Going to install rpm for patching."
        wget --no-check-certificate https://redhat.tsivmcservices.com/pulp/repos/unprotected/Patchmanagement-rhel/Packages/r/rhel${RELEASE}-lb-2.0-1.noarch.rpm -O /tmp/rhel${RELEASE}-lb-2.0-1.noarch.rpm
        rpm -ivh /tmp/rhel${RELEASE}-lb-2.0-1.noarch.rpm
        rm -rf /tmp/rhel${RELEASE}-lb-2.0-1.noarch.rpm
	systemctl disable patch-service
elif [ $1 == "stop" ]
then
        logger -p info -t Patch-service "Removing repositories providing by patching service."
        rpm -e rhel${RELEASE}-lb-2.0-1.noarch
else
        logger -p error -t Patch-service "Script $0 expect parameter start or stop. systemctl start|stop patch-service \n"
        exit 1
fi
