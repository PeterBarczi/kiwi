#!/bin/bash
FILE_NAME_AND_PATH=$1

grep -q "cpuHotAddEnabled" ${FILE_NAME_AND_PATH}.ovf; RC=$?
if [[ ${RC} -eq 1 ]]; then
	sed -i '/<\/VirtualHardwareSection>/i \
      <vmw:Config ovf:required="false" vmw:key="cpuHotAddEnabled" vmw:value="true"\/> \
      <vmw:Config ovf:required="false" vmw:key="memoryHotAddEnabled" vmw:value="true"\/>' ${FILE_NAME_AND_PATH}.ovf
fi

grep -qi "sles15" ${FILE_NAME_AND_PATH}.ovf; RC=$?
if [[ ${RC} -eq 0 ]]; then
#if [ ${IMAGE} == "SLES15" ]; then
        echo "Workaround for SLES15 - Tag system as SLES12."
        sed -i ${FILE_NAME_AND_PATH}.ovf -e 's/sles15_64Guest/sles12_64Guest/g'
fi


FILE_NAME=${FILE_NAME_AND_PATH##*/}

echo -e "$(tail -n +2 "${FILE_NAME_AND_PATH}.mf")\nSHA256(${FILE_NAME}.ovf)= $(sha256sum ${FILE_NAME_AND_PATH}.ovf | awk '{print $1}')" > ${FILE_NAME_AND_PATH}.mf

