#!/bin/bash
#BUILD_SOURCE=$1
BUILD_DESTINATION="/build/images/$1_$(date +%Y%m%d-%H%M)"
#BUILD_NAME="$2-$(date +%Y%m%d-%H%M)"
BUILD_NAME="$1"
IMAGE=$2

#if [[ $(/usr/bin/ps auwx | /usr/bin/grep kiwi | /usr/bin/wc -l) -gt "1" ]]; then
#	echo "Kiwi is already running"
#	exit 1
#fi

WAIT_COUNT=0
TEMPLATE_PATH="/build/mcs_sdursch"
while [[ -f /tmp/kiwi-build-process.lock ]] || [[ $(/usr/bin/ps auwx | /usr/bin/grep " kiwi" | /usr/bin/wc -l) -gt "1" ]]; do
    echo "Kiwi build already in process, waiting [$WAIT_COUNT]"
    let "WAIT_COUNT=WAIT_COUNT+1"
    sleep 10
done
/usr/bin/touch /tmp/kiwi-build-process.lock
echo "Acquire lockfile"




vgs 2>&1 | /usr/bin/grep -q vg00; RC=$?
if [[ ${RC} -eq 0 ]]; then
	systemctl restart lvm2-lvmetad.service
fi

if [ ! -d ${BUILD_DESTINATION} ]; then
	if [ ${IMAGE} == "SLES12" ];
	then
		echo "/usr/bin/kiwi-ng system build --description=${TEMPLATE_PATH}/mcs-vcloud-SLES12 --target-dir=${BUILD_DESTINATION}"
		/usr/bin/kiwi-ng system build --description=${TEMPLATE_PATH}/${BUILD_NAME} --target-dir=${BUILD_DESTINATION}; RC=$?
	elif [ ${IMAGE} == "SLES15" ]; then
		echo "/usr/bin/kiwi-ng system build --description=${TEMPLATE_PATH}/mcs-vcloud-SLES15 --target-dir=${BUILD_DESTINATION}"
		/usr/bin/kiwi-ng system build --description=${TEMPLATE_PATH}/${BUILD_NAME} --target-dir=${BUILD_DESTINATION}; RC=$?
	elif [ ${IMAGE} == "RHEL7" ]; then
		echo "/usr/bin/kiwi-ng system build --description=${TEMPLATE_PATH}/mcs-vcloud-RHEL7 --target-dir=${BUILD_DESTINATION}"
		/usr/bin/kiwi-ng system build --description=${TEMPLATE_PATH}/${BUILD_NAME} --target-dir=${BUILD_DESTINATION}; RC=$?
	else 
		echo "Unknown image type ${IMAGE}"
        	echo "Release lockfile"
        	/usr/bin/rm /tmp/kiwi-build-process.lock
	
	fi
        echo "Release lockfile"
        /usr/bin/rm /tmp/kiwi-build-process.lock

	if [[ ${RC} -ne 0 ]]; then
		echo "Kiwi-Build failed. Exiting vcloud-imagebuild.sh script"
		exit 1
	fi
fi

if [ ! -f ${BUILD_DESTINATION}/*.vmx ]; then
	echo "No vmx file found"
	exit 1
fi
FILENAME=$(ls ${BUILD_DESTINATION}/*.vmx | sed 's/.vmx//')

## Workaround:
#/usr/bin/grep -q "ethernet1.present" ${FILENAME}.vmx; RC=$? 
#if [[ ${RC} -eq 1 ]]; then
#	sed -i 's/usb.present = "true"/usb.present = "false"/g' ${FILENAME}.vmx
#	cat >>${FILENAME}.vmx <<EOT
#ethernet1.present = "true"
#ethernet1.allow64bitVmxnet = "true"
#ethernet1.addressType = "generated"
#ethernet1.virtualDev = "vmxnet3"
#ethernet1.connectionType = "none"
#EOT
#fi
if [ ! -f ${FILENAME}.ovf ]; then
	echo "/usr/bin/ovftool ${FILENAME}.vmx ${FILENAME}.ovf"
	/usr/bin/ovftool ${FILENAME}.vmx ${FILENAME}.ovf
fi

/build/templates/mcs_sdursch/customize_ovf.sh ${FILENAME}

echo "/usr/bin/ovftool --X:skipContentLength ${FILENAME}.ovf \"vcloud://kiwi:start123%21@vcloudtest-muc.t-systems.de:443?org=mcs_mcsdev01&vapp=${BUILD_NAME}&vdc=com-a-mcs_mcsdev01-01\""
/usr/bin/ovftool --X:skipContentLength ${FILENAME}.ovf "vcloud://kiwi:start123%21@vcloudtest-muc.t-systems.de:443?org=mcs_mcsdev01&vapp=${BUILD_NAME}&vdc=com-a-mcs_mcsdev01-01"; RC=$?

if [[ ${RC} -ne 0 ]]; then
	echo "Deployment via /usr/bin/ovftool failed!"
	exit 1
fi



#/usr/bin/ovftool ${FILENAME}.ovf "vcloud://kiwi:start123%21@vcloudtest-muc.t-systems.de:443?org=testdev02&vappTemplate=${BUILD_NAME}&catalog=imagefactory"

if [ ${IMAGE} == "SLES12" ];
then
	echo "/usr/bin/python /build/api.py -t 'TSY_SLES12_MANAGED' -o 'sles/12_64' ${BUILD_NAME}"
	/usr/bin/python /build/mcs_sdursch/mcs_api.py -t 'TSY_SLES12_MANAGED' -o 'sles/12_64' ${BUILD_NAME}
elif [ ${IMAGE} == "SLES15" ]; then
	echo "/usr/bin/python /build/mcs_sdursch/mcs_api.py -t 'TSY_SLES15_MANAGED' -o 'sles/12_64' ${BUILD_NAME}"
	/usr/bin/python /build/mcs_sdursch/mcs_api.py -t 'TSY_SLES15_MANAGED' -o 'sles/12_64' ${BUILD_NAME}
elif [ ${IMAGE} == "RHEL7" ]; then
	echo "/usr/bin/python /build/mcs_sdursch/mcs_api.py -t 'TSY_RHEL7_MANAGED' -o 'rhel/7_64'${BUILD_NAME}"
	/usr/bin/python /build/mcs_sdursch/mcs_api.py -t 'TSY_RHEL7_MANAGED' -o 'rhel/7_64' ${BUILD_NAME}
fi
