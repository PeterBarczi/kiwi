#!/bin/bash
#BUILD_SOURCE=$1
BUILD_DESTINATION="/build/images/$1_$(date +%Y%m%d-%H%M)"
#BUILD_NAME="$2-$(date +%Y%m%d-%H%M)"
BUILD_NAME="$1"
IMAGE=$2


WAIT_COUNT=0
TEMPLATE_PATH="/build/templates"
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
		echo "/usr/bin/kiwi-ng system build --description=${TEMPLATE_PATH}/MCS_TSY_SLES12_VMC --target-dir=${BUILD_DESTINATION}"
		/usr/bin/kiwi-ng system build --description=${TEMPLATE_PATH}/${BUILD_NAME} --target-dir=${BUILD_DESTINATION}; RC=$?
	elif [ ${IMAGE} == "SLES15" ]; then
		echo "/usr/bin/kiwi-ng system build --description=${TEMPLATE_PATH}/MCS_TSY_SLES15_VMC --target-dir=${BUILD_DESTINATION}"
		/usr/bin/kiwi-ng system build --description=${TEMPLATE_PATH}/${BUILD_NAME} --target-dir=${BUILD_DESTINATION}; RC=$?
	elif [ ${IMAGE} == "RHEL7" ]; then
		echo "/usr/bin/kiwi-ng system build --description=${TEMPLATE_PATH}/MCS_TSY_RHEL7_VMC --target-dir=${BUILD_DESTINATION}"
		/usr/bin/kiwi-ng system build --description=${TEMPLATE_PATH}/${BUILD_NAME} --target-dir=${BUILD_DESTINATION}; RC=$?
	elif [ ${IMAGE} == "RHEL8" ]; then
                echo "/usr/bin/kiwi-ng system build --description=${TEMPLATE_PATH}/MCS_TSY_RHEL8_VMC --target-dir=${BUILD_DESTINATION}"
                /usr/bin/kiwi-ng system build --description=${TEMPLATE_PATH}/${BUILD_NAME} --target-dir=${BUILD_DESTINATION}; RC=$?
	else 
		echo "Unknown image type ${IMAGE}"
        	echo "Release lockfile"
        	/usr/bin/rm /tmp/kiwi-build-process.lock
	
	fi
        echo "Release lockfile"
        /usr/bin/rm /tmp/kiwi-build-process.lock

	if [[ ${RC} -ne 0 ]]; then
		echo "Kiwi-Build failed. Exiting mcs-vmc-imagebuild.sh script"
		exit 1
	fi
fi

if [ ! -f ${BUILD_DESTINATION}/*.vmx ]; then
	echo "No vmx file found"
	exit 1
fi
FILENAME=$(ls ${BUILD_DESTINATION}/*.vmx | sed 's/.vmx//')

if [ ! -f ${FILENAME}.ovf ]; then
	echo "/usr/bin/ovftool ${FILENAME}.vmx ${FILENAME}.ovf"
	/usr/bin/ovftool ${FILENAME}.vmx ${FILENAME}.ovf
fi

/build/templates/customize_ovf.sh ${FILENAME}
/usr/bin/ovftool ${FILENAME}.ovf ${FILENAME}.ova

if [[ ${RC} -ne 0 ]]; then
	echo "Deployment via /usr/bin/ovftool failed!"
	exit 1
fi

#UPLOAD TO S3 BUCKET 

#aws s3 cp ${FILENAME}.ova s3://kukybucket2021/ --acl public-read
#aws s3 cp ${FILENAME}.ova s3://tsy-vmc-dev-s3-euc1-images
#OVAFILENAME=$(find ${FILENAME}.ova -printf "%f\n")
#echo "ova File of image available on https://kukybucket2021.s3.eu-central-1.amazonaws.com/${OVAFILENAME}"
echo "ova File of image uploaded into s3://tsy-vmc-dev-s3-euc1-images.s3.eu-central-1.amazonaws.com/${OVAFILENAME}"

#INDEX THE S3 BUCKET
#python /build/templates/make-vcsp-2018.py -n foo-remote -t s3 -p tsy-vmc-dev-s3-euc1-images
#echo "Indexing S3 Bucket for Content Library done"
#if [ ${IMAGE} == "SLES12" ];
#then
#	echo "/usr/bin/python /build/templates/api.py -t 'TSY_SLES12_MANAGED' -o 'sles/12_64' ${BUILD_NAME}"
#	/usr/bin/python /build/templates/mcs_sdursch/mcs_api.py -t 'TSY_SLES12_MANAGED' -o 'sles/12_64' ${BUILD_NAME}
#elif [ ${IMAGE} == "SLES15" ]; then
#	echo "/usr/bin/python /build/templates/mcs_sdursch/mcs_api.py -t 'TSY_SLES15_MANAGED' -o 'sles/12_64' ${BUILD_NAME}"
#	/usr/bin/python /build/templates/mcs_sdursch/mcs_api.py -t 'TSY_SLES15_MANAGED' -o 'sles/12_64' ${BUILD_NAME}
#elif [ ${IMAGE} == "RHEL7" ]; then
#	echo "/usr/bin/python /build/templates/mcs_sdursch/mcs_api.py -t 'TSY_RHEL7_MANAGED' -o 'rhel/7_64'${BUILD_NAME}"
#	/usr/bin/python /build/templates/mcs_sdursch/mcs_api.py -t 'TSY_RHEL7_MANAGED' -o 'rhel/7_64' ${BUILD_NAME}
#fi
