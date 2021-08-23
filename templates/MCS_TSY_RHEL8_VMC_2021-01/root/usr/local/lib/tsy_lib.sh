#!/bin/bash
##################################################################
# TSY standard functions library
#
# This functions should be used to reach a constant quality level
# of internal tools and scripts.
#
TSY_LIB_AUTHOR="Philipp Graf"
TSY_LIB_CONTACT="philipp.graf@t-systems.com"
TSY_LIB_DATE="10.01.2018"
TSY_LIB_VERSION="2_6.0"
TSY_LIB_FUNCTION="T-Systems tool library."
#
#
# History:
#1_0.0		09.05.2012	aeisenre	Initial version
#1_0.1		26.06.2013	phigraf		Added func_getdistro.
#1_0.2		23.09.2014	phigraf		Added additional functions 
#						func_check_rc, func_backup_file, func_delete_file, func_delete_dir_recursively, 
#						func_touch_file, func_run_command, func_ensure_link, func_ensure_line_in_file, 
#						func_remove_line_in_file, func_diff_files, func_get_file_from_server
#1_0.3		05.12.2014	phigraf		Bugfix for \t in func_ensure_line_in_file
#1_0.4		10.03.2015	phigraf		Added additional functions 
#						func_install_rpm_version_or_higher, func_install_rpm, func_erase_rpm,
#						func_wait_for_port_on_ip func_manage_service func_get_file_from_server
#1_0.5		17.03.2015	phigraf		Bugfix for func_checklog, removed func_cleanup and func_TSY_LIB_check_var
#1_1.0		05.08.2015	phigraf		Added umask.sh
#2.3.0		06.08.2015	phigraf		Added rpms to erase gstreamer gstreamer-plugins-base qt-x11 phonon-backend-gstreamer 
#						redhat-lsb-graphics python-iwlib wireless-tools
#2_3.1		01.10.2015	phigraf		Bugfix
#2_3.2		08.01.2016	phigraf		Added tsy-mcos-release
#2_3.3		11.04.2016	phigraf		Added @ service handling to func_manage_service
#2_3.4		13.04.2016	phigraf		bug fixing
#2_5.0		08.09.2016	phigraf		added -n (NO_BACKUP) for func_ensure_line_in_file and func_remove_line_in_file
#2_6.0		10.01.2018	phigraf		fix for not worikg -f in rhel chkconfig and missing CHANGED flag in func_diff_files
#2_7.0		29.04.2019	mwiedere	added support for SLES15 and new tsy-dsirelease format


##################################################################

##################################################################
# USAGE
#
# Please source this library at the beginning of a script before
# define any variable!
###########################
# EXAMPLE USAGE:
###########################
# TSY_LIB="/usr/local/lib/tsy_lib.sh"
# if [ -f ${TSY_LIB} ];then
# 	. ${TSY_LIB}
# else
# 	echo "ERROR: Not able to use the standard TSY libary [${TSY_LIB}]!"
#	exit 1
# fi
###########################
# The following Configuration has to be done in each script that
# Source the TSY library set:
# SCRIPT="${0}"
# SCRIPT_NAME="$(basename "${SCRIPT}")"
# SCRIPT_SHORTNAME="${SCRIPT_NAME%.sh}"
# LOG_DIR="<insert_log_dir>" #Example directory: /var/log
# LOG_FILE="${LOG_DIR}/${SCRIPT_SHORTNAME}.log"
# LOCK_FILE="<insert_lockfile>" #Example: /var/run/${SCRIPT_SHORTNAME}
# LOGFILES_AGE_DAYS=14 #Keep the logs 14 days
# PRINTHELP_OPTIONS="f		force"
##################################################################

##################################################################
# CONFIGURATION
if [ -z "${DEBUG}" ]; then
DEBUG="0"
fi
if [ -z "${TIVOLI}" ]; then
TIVOLI="0"
fi
if [ -z "${FORCE}" ]; then
FORCE="0"
fi
if [ -z "${DRYRUN}" ]; then
DRYRUN="0"
fi
if [ -z "${SAVE_EXT}" ] ; then
SAVE_EXT="$(date '+%Y-%m-%d')_$$"
fi
if [ -z "${READ}" ] ; then
READ="0"
fi

if [ -f /etc/profile.d/umask.sh ];then
	. /etc/profile.d/umask.sh
else
	umask 027
fi

##################################################################
func_checklog ()
{
if [ ! -d "${LOG_DIR}" ]; then
        echo "INFO    - Log directory ${LOG_DIR} not found."
        echo "INFO    - try to create logdir."
        mkdir -p ${LOG_DIR} 2>/dev/null; RC=$?
        if [[ "${RC}" != "0" ]];then
                echo "WARNING - Log directory creation failed. Set LOG_FILE to [/dev/null]."
                LOG_FILE=/dev/null
                return
        fi
else
        touch ${LOG_FILE} 2>/dev/null; RC=$?
        if [[ "${RC}" != "0" ]];then
                echo "WARNING - Can\`t write on LOG_FILE [${LOG_FILE}]. Set LOG_FILE to [/dev/null]."
                LOG_FILE=/dev/null
        elif [[ "${LOGFILES_AGE_DAYS}" != "" ]]; then
                LOGFILES_AGE_DATE=$(date --date="${LOGFILES_AGE_DAYS} days ago" +%Y%m%d%H%M.%S)
                LOGFILES_AGE_TMP_FILE="/tmp/find_flag_$$"
                touch -amt ${LOGFILES_AGE_DATE} ${LOGFILES_AGE_TMP_FILE}; RC=$?
                if [[ "${RC}" != "0" ]]; then
                        echo "ERROR: Can\`t write ${LOGFILES_AGE_TMP_FILE}"
                        RC=1; exit
                fi
                LOGFILES_TO_DELETE=$(find ${LOG_DIR} -type f ! -newer ${LOGFILES_AGE_TMP_FILE} -name "*.log")
                rm -f ${LOGFILES_AGE_TMP_FILE} ${LOGFILES_TO_DELETE} >/dev/null; RC=$?
                if [[ "${RC}" != "0" ]];then
                        echo "WARNING - Can\`t delete all the old Logfiles"
                fi
        fi
fi
}

func_msg()
{
        # Available msg types:
        # $1                                                            $2
        # LIST                                                          OK,ERROR,FAILED,WARING,MSG_RESULT*,<MESSAGE>
        # INFO,VINFO,ERROR,FAILED,WARING        <MESSAGE>
        # LOG                                                           <MESSAGE>

        MSG_TYPE="$1"
        MSG="$2"
        MSG_CHAR="."
        MSG_FILLUP=" "
        MSG_LISTWITH_MAX="200"
        MSG_DEL="\b\b\b\b\b\b\b\b\b\b\b"
        MSG_DATE=$(date '+%b %d %Y %H:%M:%S')

		if [[ ! -z "$PS1" ]]; then
			MSG_TERMWITH=$(tput cols); RC=$?
			if [[ "${RC}" != "0" ]]
			then
					MSG_TERMWITH="80"
			fi
		else
			MSG_TERMWITH="80"
		fi
        MSG_LISTWITH=$(( ${MSG_TERMWITH} - 12 )) #12 == [   OK   ]
        if (( ${MSG_LISTWITH} < 0 )) || (( ${MSG_LISTWITH} > ${MSG_LISTWITH_MAX} ));then
                MSG_LISTWITH=${MSG_LISTWITH_MAX}
        fi

        if [[ ${LOG_FILE} != "" ]]; then
                if [[ "${MSG_TYPE}" = "LOG" ]]; then
                        echo -e "${MSG}" |sed -e "s/^/${MSG_DATE} ${USER} ${HOSTNAME} [$$] : /g" >> ${LOG_FILE}
                        return
                else
                        echo -e "${MSG_DATE} ${USER} ${HOSTNAME} [$$] : ${MSG_TYPE} : ${MSG}" >> ${LOG_FILE}
                fi
        fi

        if [ "${DEBUG}" -eq "0" ] && [ "${TIVOLI}" -eq "0" ];then
                case ${MSG_TYPE} in
                        INFO)           if [[ "${LISTMODE}" = "open" ]]; then
                                                                echo -e "${MSG_DEL}[   \033[1;32mOK\033[0m    ]"
                                                                LISTMODE="closed"
                                                        fi
                                                        echo -e "${MSG_TYPE}    - ${MSG}"
                                                        ;;
                        VINFO)          if [[ "${VERBOSE}" = "1" ]]; then
                                                                if [[ "${LISTMODE}" = "open" ]]; then
                                                                        echo -e "${MSG_DEL}[   \033[1;32mOK\033[0m    ]"
                                                                        LISTMODE="closed"
                                                                fi
                                                                echo -e "INFO    - ${MSG}"
                                                        fi
                                                        ;;
                        ERROR)          if [[ "${LISTMODE}" = "open" ]]; then
                                                                echo -e "${MSG_DEL}[  \033[1;31mERROR\033[0m  ]"
                                                                LISTMODE="closed"
                                                                CHAPTER_FAILED="FAILED"
                                                        fi
                                                        echo -e "${MSG_TYPE}   - ${MSG}"
                                                        ;;
                        FAILED)                 if [[ "${LISTMODE}" = "open" ]]; then
                                                                echo -e "${MSG_DEL}[ \033[1;31mFAILED\033[0m  ]"
                                                                LISTMODE="closed"
                                                                CHAPTER_FAILED="FAILED"
                                                        fi
                                                        echo -e "${MSG_TYPE}   - ${MSG}"
                                                        ;;
                        WARNING)        if [[ "${LISTMODE}" = "open" ]]; then
                                                                echo -e "${MSG_DEL}[ \033[1;33mWARNING\033[0m ]"
                                                                LISTMODE="closed"
                                                        fi
                                                        echo -e "${MSG_TYPE} - ${MSG}"
                                                        ;;
                esac

                if [[ "${MSG_TYPE}" = "LINE" ]]; then
                        if [[ ${MSG} != "" ]]; then
                                MSG_FILLUP=""
                                MSG_BCOUNT=$(( ${MSG_TERMWITH} - 1 ))
                                MSG_i=0
                                while (( ${MSG_i} < ${MSG_BCOUNT} )); do
                                        MSG_FILLUP="${MSG_FILLUP}${MSG}"
                                        MSG_i=$(( ${MSG_i} + 1))
                                done
                                echo ${MSG_FILLUP}
                        else
                                echo
                        fi
                fi

                if [[ "${MSG_TYPE}" = "CHAPTER" ]]; then
                        if [[ "${CHAPTER_INFOS}" = "" ]]; then
                                CHAPTER_INFOS="func_msg LIST \"${MSG}\""
                        else
                                echo
                                CHAPTER_INFOS="${CHAPTER_INFOS}\nfunc_msg LIST ${CHAPTER_FAILED}"
                                CHAPTER_INFOS="${CHAPTER_INFOS}\nfunc_msg LIST \"${MSG}\""
                        fi
                        CHAPTER_FAILED="PASSED"
                        echo -e "\033[1;34m${MSG}:\033[0m"
                fi

                if [[ "${MSG_TYPE}" = "SUMMARY" ]]; then
                        echo -e "\n\033[1;35m${MSG}:\033[0m"
                        CHAPTER_INFOS="${CHAPTER_INFOS}\nfunc_msg LIST ${CHAPTER_FAILED}"
                        eval "$(echo -e "${CHAPTER_INFOS}")"
                        return
                fi

                if [[ "${MSG_TYPE}" = "LIST" ]] || [[ "${MSG_TYPE}" = "VLIST" && "${VERBOSE}" = "1" ]];then
                        if [[ "${LISTMODE}" = "open" ]]; then
                                case $MSG in
                                        OK)             echo -e "${MSG_DEL}[   \033[1;32mOK\033[0m    ]"
                                                                        LISTMODE="closed"
                                                                        ;;
                                        PASSED)                 echo -e "${MSG_DEL}[ \033[1;32mPASSED\033[0m  ]"
                                                                        LISTMODE="closed"
                                                                        ;;
                                        ERROR)          echo -e "${MSG_DEL}[  \033[1;31mERROR\033[0m  ]"
                                                                        LISTMODE="closed"

                                                                        ;;
                                        FAILED)          echo -e "${MSG_DEL}[ \033[1;31mFAILED\033[0m  ]"
                                                                        LISTMODE="closed"
                                                                        ;;
                                        WARNING)        echo -e "${MSG_DEL}[ \033[1;33mWARNING\033[0m ]"
                                                                        LISTMODE="closed"
                                                                        ;;
                                        NA)                     echo -e "${MSG_DEL}[   N/A   ]"
                                                                        LISTMODE="closed"
                                                                        ;;
                                        MSG_RESULT*)    NEW_MSG=$(echo ${MSG} |sed -e 's/MSG_RESULT //')
                                                                        MSG_SPACE=$(( 10 - $(echo ${NEW_MSG} |wc -c)))
                                                                        if (( "${MSG_SPACE}" < "0" ))
                                                                        then
                                                                                func_msg LIST OK
                                                                                func_msg INFO "Result: ${NEW_MSG}"
                                                                        fi
                                                                        echo -en "${MSG_DEL}["
                                                                        case $MSG_SPACE in
                                                                                0) echo -e "${NEW_MSG}]";;
                                                                                1) echo -e " ${NEW_MSG}]";;
                                                                                2) echo -e " ${NEW_MSG} ]";;
                                                                                3) echo -e "  ${NEW_MSG} ] ";;
                                                                                4) echo -e "  ${NEW_MSG}  ] ";;
                                                                                5) echo -e "   ${NEW_MSG}  ] ";;
                                                                                6) echo -e "   ${NEW_MSG}   ] ";;
                                                                                7) echo -e "    ${NEW_MSG}   ] ";;
                                                                                8) echo -e "    ${NEW_MSG}    ] ";;
                                                                        esac
                                                                        LISTMODE="closed"
                                                                        ;;
                                esac
                        elif [[ "${MSG}" != "OK" ]] && [[ "${MSG}" != "ERROR" ]] && [[ "${MSG}" != "FAILED" ]] && [[ "${MSG}" != "WARNING" ]]; then
                                MSG_COUNT=`echo ${MSG} | wc -c`
                                MSG_BCOUNT=$(( ${MSG_LISTWITH} - ${MSG_COUNT} - 1 ))
                                while (( ${MSG_BCOUNT} < "1" ));do
                                        MSG_BCOUNT=$((${MSG_BCOUNT} + ${MSG_TERMWITH}))
                                done
                                MSG_i=0
                                while (( ${MSG_i} < ${MSG_BCOUNT} )); do
                                        MSG_FILLUP="${MSG_FILLUP}${MSG_CHAR}"
                                        MSG_i=$(( ${MSG_i} + 1))
                                done
                                echo -en "${MSG}${MSG_FILLUP} [ working ]"
                                LISTMODE="open"
                        fi
                fi
        elif [[ ${DEBUG} = "1" ]]; then
                echo  "${MSG_TYPE}: ${MSG}" 1>&2
#       elif [[ ${TIVOLI} = "1" ]] && [[ "${MSG_TYPE}" = "INFO" || "${MSG_TYPE}" = "WARNING" || "${MSG_TYPE}" = "ERROR" ]]; then
        elif [[ ${TIVOLI} = "1" ]] && [[ "${MSG_TYPE}" = "WARNING" || "${MSG_TYPE}" = "FAILED" || "${MSG_TYPE}" = "ERROR" ]]; then
                echo  "${MSG_TYPE};${MSG}"; TIVOLI_ERROR="1"
        fi
}

func_lock()
{
		MODE=$1
		EXITCODE=$2
		if [[ -z "${EXITCODE}" ]];
		then
			EXITCODE="0"
		fi		
		
		func_msg DEBUG "Start function func_lock in mode [${MODE}] exitcode [${EXITCODE}]"
		
		if [ ${MODE} == "on" ];then
			if [ -f ${LOCK_FILE} ];then
				func_msg INFO "Another ${SCRIPT_SHORTNAME} is currently running"
				func_msg INFO "Lock file: [${LOCK_FILE}]"
				
				if [ ${FORCE} -eq "1" ];then
					func_msg INFO "${SCRIPT_SHORTNAME} started in force mode! proceed..."
				else
					exit "${EXITCODE}"
				fi
			else
				func_msg DEBUG "Create lock file [${LOCK_FILE}]"
				touch ${LOCK_FILE} 2>/dev/null
				RC=$?
				if [ ${RC} -ne "0" ];then
					func_msg ERROR "Not able to create lock file [${LOCK_FILE}]"
					exit 1
				fi
			fi
		fi
		
		if [ ${MODE} == "off" ];then
			func_msg DEBUG "Remove lock file [${LOCK_FILE}]"
			rm ${LOCK_FILE} 2>/dev/null
			RC=$?
			if [ ${RC} -ne "0" ];then
				func_msg ERROR "Not able to remove lock file [${LOCK_FILE}]"
				exit 1
			fi
		fi
}

func_printhelp()
{
cat <<EO_HELP
${SCRIPT_SHORTNAME} version ${VERSION} date ${DATE}
Copyright (C) $(date +"%Y") by T-Systems Internation GmbH
Author: ${AUTHOR} <${CONTACT}>

${SCRIPT_SHORTNAME} ${FUNCTION}

Usage: ${SCRIPT_NAME} [OPTIONS]

Options:
	-h		Print this [h]elp message.
	-d		[D]ebug mode on.
	-n		Enable Dryru[n] mode.
	-f		[F]orce mode on.
	-v		Print script [v]ersion.
${PRINTHELP_OPTIONS}
EO_HELP

}

func_read()
{
if [[ "${READ}" = "1" ]]; then
	echo -n "Press enter to continue."; read
fi
}

func_getdistro()
{
if [[ -r /etc/oracle-release ]]; then
	grep -q 'Oracle Linux Server' /etc/oracle-release && DIST="ol"
	grep -qi 'release[      ][      ]*6' /etc/redhat-release && RELEASE="6"
    grep -qi 'release[      ][      ]*7' /etc/redhat-release && RELEASE="7"
	INSTALL_CMD="yum install -yq"
	UPDATE_CMD="yum update -yq"
	SERVICEPACK=$(cat /etc/oracle-release |grep -o "[0-9]*\.[0-9]*" |awk -F\. '{print $2}')
elif [[ -r /etc/redhat-release ]]; then
	grep -q 'CentOS' /etc/redhat-release && DIST="centos"
	grep -q 'Red Hat Enterprise Linux' /etc/redhat-release && DIST="rhel"
	grep -qi 'release[      ][      ]*5' /etc/redhat-release && RELEASE="5"
	grep -qi 'release[      ][      ]*6' /etc/redhat-release && RELEASE="6"
    grep -qi 'release[      ][      ]*7' /etc/redhat-release && RELEASE="7"
	INSTALL_CMD="yum install -yq"
	UPDATE_CMD="yum update -yq"
	SERVICEPACK=$(cat /etc/redhat-release |grep -o "[0-9]*\.[0-9]*" |awk -F\. '{print $2}')
elif [[ -r /etc/SuSE-release ]]; then
	grep -q 'openSUSE' /etc/SuSE-release && DIST="opensuse"
	grep -q 'SUSE Linux Enterprise Server' /etc/SuSE-release && DIST="sles"
	grep -qi 'version[      ]*=[    ]*10' /etc/SuSE-release && RELEASE="10"
	grep -qi 'version[      ]*=[    ]*11' /etc/SuSE-release && RELEASE="11"
	grep -qi 'version[      ]*=[    ]*12' /etc/SuSE-release && RELEASE="12"
	SERVICEPACK=$(cat /etc/SuSE-release |grep '^PATCHLEVEL' |awk -F= '{print $2}' |tr -d '[:blank:]')
	INSTALL_CMD="zypper in -y"
	UPDATE_CMD="zypper up -y"
# sles-release for SLES15 does not contain /etc/SuSE-release anymore
# as it is deprecated and might be deleted in future servicepacks - support for SLES12 reading from /etc/os-release is added 
elif [[ $(rpm -q sles-release) != "package sles-release is not installed" ]]; then 
	grep -q 'NAME="SLES"' /etc/os-release && DIST="sles"
	grep -q 'VERSION="12' /etc/os-release && RELEASE="12"
	grep -q 'VERSION="15' /etc/os-release && RELEASE="15"
	# pattern if SP is installed after RELEASE there is a period, followed by the number of the SP
	# otherwise there is no period
	if [[ $(grep '^VERSION_ID="..\.."' /etc/os-release) != "" ]]; then
		SERVICEPACK=$(cat /etc/os-release | grep "^VERSION_ID" | cut -c 16)
	else
		SERVICEPACK=0
	fi
fi

func_msg DEBUG "DIST=[${DIST}]"
func_msg DEBUG "RELEASE=[${RELEASE}]"
func_msg DEBUG "INSTALL_CMD=[${INSTALL_CMD}]"
func_msg DEBUG "UPDATE_CMD=[${UPDATE_CMD}]"
	
OS="${DIST}${RELEASE}"
func_msg DEBUG "OS=[${OS}]"

if [[ -z "${RELEASE}" ]]; then
	func_msg ERROR "Your OS / OS Release is not supported."; func_printhelp
	exit 3
fi

DSI="0"
if [[ -f /etc/tsy-dsirelease ]]; then
	DSI="1"
	DSI_PRODUCT=$(cat /etc/tsy-dsirelease 2>/dev/null |head -1 |awk -F_ '{print $3}')
	if [[ ${DSI_PRODUCT} = "" ]]; then
		DSI_PRODUCT="central"
	fi
	func_msg DEBUG "DSI_PRODUCT=[${DSI_PRODUCT}]"

	IMAGE=$(cat /etc/tsy-dsirelease 2>/dev/null |head -1 |awk -F_ '{print $2}')
	if [[ ${IMAGE} = "" ]]; then
		# test new release format
		IMAGE=$(grep "Image-Version:" /etc/tsy-dsirelease | awk '{print $4}' | tr "[:upper:]" "[:lower:]")
		if [[ ${IMAGE} = "" ]]; then
			func_msg ERROR "Not able to get your image type from /etc/tsy-dsirelease. IMAGE=[${IMAGE}]"
			exit 3
		fi
	fi
fi

DCS="0"
if [[ -f /etc/imageversion ]]; then
	mount -t nfs |grep -qw "/cAppCom"; RC=$?
	if [[ "${RC}" = "0" ]]; then
		DCS="1"
		AUTO_ADMIN=${AUTO_ADMIN_DCS}
		if [[ ${DIST} = "sles" ]]; then
			CERT_DIR=${CERT_DIR_DSC_SLES}
		fi
	fi
fi

CLASSIC="0"
if [[ -f /etc/cobblerrelease ]]; then
	CLASSIC="1"
	IMAGE=$(cat /etc/cobblerrelease 2>/dev/null |tail -1)
	if [[ ${IMAGE} = "" ]]; then
		func_msg ERROR "Not able to get your image version from /etc/cobblerrelease. IMAGE=[${IMAGE}]"
		exit 3
	else
		func_msg DEBUG "IMAGE=[${IMAGE}]"
		IMAGE_YEAR=$(echo "${IMAGE}" |awk -F'-' '{print $1}')
	fi

fi

MCOS="0"
if [[ -r /etc/tsy-mcos-release ]]; then
	. /etc/tsy-mcos-release
fi

func_msg DEBUG "CLASSIC=[${CLASSIC}]"
func_msg DEBUG "DCS=[${DCS}]"
func_msg DEBUG "DSI=[${DSI}]"
func_msg DEBUG "MCOS=[${MCOS}]"
func_msg DEBUG "IMAGE=[${IMAGE}]"

return 0
}

func_check_rc() # $1 RC (n for no exit); $2 MSG_TYPE; $2 MSG
{
CHECK_RC_RC=$?
CHECK_RC_EXIT_CODE=$1
CHECK_RC_MSG_TYPE=$2
CHECK_RC_MSG=$3

if [[ "${CHECK_RC_RC}" != "0" ]]; then
	func_msg DEBUG "CHECK_RC_RC=[${CHECK_RC_RC}]"
	func_msg ${CHECK_RC_MSG_TYPE} "${CHECK_RC_MSG}"
	if [[ "${CHECK_RC_EXIT_CODE}" != "n" && "${CHECK_RC_EXIT_CODE}" != "N" ]]; then
		exit "${CHECK_RC_EXIT_CODE}"
		if [[ ${CHECK_RC_MSG_TYPE} = "ERROR" ]]; then
			ERROR_IN_FUNC="1"
		fi
	fi
fi
}

func_backup_file() # $* file1 file2 file3 ...
{
BACKUP_FILES=$*
for BACKUP_FILE in ${BACKUP_FILES}; do
	if [[ -f ${BACKUP_FILE} ]] && [ -s ${BACKUP_FILE} ]; then
		if [[ "${DRYRUN}" != "1" ]]; then
			if [[ ! -f "${BACKUP_FILE}_${SAVE_EXT}" ]]; then
				func_msg DEBUG "cp -p ${BACKUP_FILE} ${BACKUP_FILE}_${SAVE_EXT}"
				OUTPUT=$(cp -p ${BACKUP_FILE} "${BACKUP_FILE}_${SAVE_EXT}" 2>&1); CP_RC=$?
				if [[ ${CP_RC} != "0" ]]; then
					func_msg DEBUG "${OUTPUT}"
					func_msg ERROR "Cannot backup [${BACKUP_FILE}]."
					ERROR_IN_FUNC="1"
				fi
			else
				func_msg DEBUG "Backup [${BACKUP_FILE}_${SAVE_EXT}] already existent."
			fi
		else
			func_msg INFO "Dryrun: File [${BACKUP_FILE}] would be backuped."
		fi
	else
		func_msg DEBUG "File [${BACKUP_FILE}] not existent or has size zero. No backup needed."
	fi
done
}

func_delete_file() # $* file1 file2 file3 ...
{
DELETE_FILES=$*
for DELETE_FILE in ${DELETE_FILES}; do
	if ls "${DELETE_FILE}" &>/dev/null; then
		if [[ "${DRYRUN}" != "1" ]]; then
			func_msg DEBUG "rm -f ${DELETE_FILE}"
			OUTPUT=$(rm -f ${DELETE_FILE} 2>&1); RM_RC=$?
			if [[ ${RM_RC} != "0" ]]; then
				func_msg DEBUG "${OUTPUT}"
				func_msg ERROR "Cannot delete file [${DELETE_FILE}]."
				ERROR_IN_FUNC="1"
			fi
		else
			func_msg INFO "Dryrun: File [${DELETE_FILE}] would be deleted."
		fi
	else
		func_msg DEBUG "File [${DELETE_FILE}] not existent. No delete needed."
	fi
done
}

func_delete_dir_recursively() # $* dir dir2 dir3 ...
{
DELETE_DIRS=$*
for DELETE_DIR in ${DELETE_DIRS}; do
	if [[ -d ${DELETE_DIR} ]]; then
		if [[ "${DRYRUN}" != "1" ]]; then
			func_msg DEBUG "rm -rf ${DELETE_DIR}"
			OUTPUT=$(rm -rf ${DELETE_DIR} 2>&1); RM_RC=$?
			if [[ ${RM_RC} != "0" ]]; then
				func_msg DEBUG "${OUTPUT}"
				func_msg ERROR "Cannot delete dir [${DELETE_DIR}] recursively."
				ERROR_IN_FUNC="1"
			fi
		else
			func_msg INFO "Dryrun: Dir [${DELETE_DIR}] would be deleted recursively."
		fi
	else
		func_msg DEBUG "Dir [${DELETE_DIR}] not existent or not a directory. No delete needed."
	fi
done
}

func_touch_file() # $1 file
{
TOUCH_FILE=${1}

if [[ "${DRYRUN}" != "1" ]]; then
	func_msg DEBUG "touch ${TOUCH_FILE}"
	OUTPUT=$(touch ${TOUCH_FILE} 2>&1); TOUCH_RC=$?
	if [[ ${TOUCH_RC} != "0" ]]; then
		func_msg DEBUG "${OUTPUT}"
		func_msg ERROR "Cannot touch file [${TOUCH_FILE}]."
		ERROR_IN_FUNC="1"
	fi
else
	func_msg INFO "Dryrun: File [${TOUCH_FILE}] would be touched."
fi
}

func_run_command() # $1 RUN_COMMAND $2 RUN_COMMAND_COUNT $3 RUN_COMMAND_SLEEP $4 RUN_COMMAND_SLEEP_MULTIPLIER
{
RUN_COMMAND=${1}
RUN_COMMAND_COUNT=${2}
RUN_COMMAND_SLEEP=${3}
RUN_COMMAND_SLEEP_MULTIPLIER=${4}
RUN_COMMAND_RC="1"

if [[ "${RUN_COMMAND_COUNT}" = "" ]]; then
	RUN_COMMAND_COUNT="1"
fi

if [[ "${DRYRUN}" != "1" ]]; then
	while (( "${RUN_COMMAND_COUNT}" >= "1" )) && [[ "${RUN_COMMAND_RC}" != "0" ]];do
		func_msg DEBUG "Run [${RUN_COMMAND}]"
		OUTPUT=$(eval ${RUN_COMMAND} 2>&1); RUN_COMMAND_RC=$?
		if [[ ${RUN_COMMAND_RC} != "0" ]]; then
			func_msg LOG "${OUTPUT}"
			if (( "${RUN_COMMAND_COUNT}" > "1" )); then
				RUN_COMMAND_COUNT=$(( ${RUN_COMMAND_COUNT} - 1 ))
				func_msg WARNING "Command [${RUN_COMMAND}] exited not with 0. RC=[${RUN_COMMAND_RC}]. [${RUN_COMMAND_COUNT}] tries left."
				if [[ ${RUN_COMMAND_SLEEP} != "" ]];then
					func_msg DEBUG "Sleep for ${RUN_COMMAND_SLEEP} seconds."
					sleep ${RUN_COMMAND_SLEEP}
					if [[ ${RUN_COMMAND_SLEEP_MULTIPLIER} != "" ]];then
						RUN_COMMAND_SLEEP=$(( ${RUN_COMMAND_SLEEP} * ${RUN_COMMAND_SLEEP_MULTIPLIER} ))
					fi
				fi
			else
				func_msg ERROR "Command [${RUN_COMMAND}] exited not with 0. RC=[${RUN_COMMAND_RC}]"
				ERROR_IN_FUNC="1"
				return 1
			fi
		fi
	done
else
	func_msg INFO "Dryrun: Command [${RUN_COMMAND}] would be executed."
fi
}

func_ensure_link() # $1 file $2 link
{
LINK_FILE=$1
LINK_TO=$2

LINK_TO_ACT=$(readlink ${LINK_TO} 2>/dev/null)
if [[ "${LINK_TO_ACT}" = "${LINK_FILE}" ]]; then
	func_msg DEBUG "File [${LINK_FILE}] links to link [${LINK_TO}]."
else
	func_msg DEBUG "File [${LINK_FILE}] is not linked to link [${LINK_TO}]."
	if [[ ${DRYRUN} != "1" ]]; then
		func_backup_file ${LINK_TO}
		func_delete_file ${LINK_TO}
		OUTPUT=$(ln -s ${LINK_FILE} ${LINK_TO} 2>&1); LINK_RC=$?
		if [[ ${LINK_RC} != "0" ]]; then
			func_msg DEBUG "${OUTPUT}"
			func_msg ERROR "Cannot link ${LINK_FILE} to ${LINK_TO}."
			ERROR_IN_FUNC="1"
		else
			func_msg DEBUG "Created link from ${LINK_FILE} to ${LINK_TO}."
		fi
	else
		func_msg INFO "Dryrun: File [${LINK_FILE}] would be liked to link [${LINK_TO}]."
	fi
fi
}

func_ensure_line_in_file() # $1 lile $2 line
{

NO_BACKUP="0"
if [[ $1 = "-n" ]]; then
	NO_BACKUP="1"
	FILE="$2"
	LINE="$3"
else
	FILE="$1"
	LINE="$2"
fi

if [[ -r ${FILE} ]]; then
	grep -q "$(echo -e "${LINE}")" ${FILE}; GREP_RC=$?
	if [[ ${GREP_RC} != "0" ]]; then
		if [[ ${DRYRUN} != "1" ]]; then
			if [[ ${NO_BACKUP} != "1" ]]; then
				func_backup_file ${FILE}
			fi
			func_msg DEBUG "add LINE [${LINE}] to ${FILE}"
			echo -e "${LINE}" >>${FILE} 2>/dev/null; ECHO_RC=$?
			if [[ ${ECHO_RC} != "0" ]]; then
				func_msg ERROR "Cannot write to [${FILE}]."
				ERROR_IN_FUNC="1"
			fi
		else
			func_msg INFO "Dryrun: Line [${LINE}] would be added to file [${FILE}]."
		fi
	else
		func_msg DEBUG "Ok line [${LINE}] is in File [${FILE}]."
	fi
else
	func_msg ERROR "Cannot read file [${FILE}]."
	ERROR_IN_FUNC="1"
fi
}

func_remove_line_in_file() # $1 file $2 line
{
NO_BACKUP="0"
if [[ $1 = "-n" ]]; then
	NO_BACKUP="1"
	FILE="$2"
	LINE="$3"
else
	FILE="$1"
	LINE="$2"
fi

if [[ -r ${FILE} ]]; then
	grep -q "${LINE}" ${FILE}; GREP_RC=$?
	if [[ ${GREP_RC} = "0" ]]; then
		if [[ ${DRYRUN} != "1" ]]; then
			if [[ ${NO_BACKUP} != "1" ]]; then
				func_backup_file ${FILE}
			fi
			func_msg DEBUG "remove LINE [${LINE}] in ${FILE}"
			OUTPUT=$(sed -i "/${LINE}/d" ${FILE} 2>&1); SED_RC=$?
			if [[ ${SED_RC} != "0" ]]; then
				func_msg DEBUG "${OUTPUT}"
				func_msg ERROR "Cannot romove line [${LINE}] from file [${FILE}]."
				ERROR_IN_FUNC="1"
			fi
		else
			func_msg INFO "Dryrun: Line [${LINE}] would be removed from file [${FILE}]."
		fi
	else
		func_msg DEBUG "Ok line [${LINE}] not in file [${FILE}]."
	fi
else
	func_msg ERROR "Cannot read file [${FILE}]."
	ERROR_IN_FUNC="1"
fi
}

func_diff_files() # [-s] $1 ACTFILE $2 NEWFILE $3 NEW_MODE $4 NEW_USER $5 PRE_CHANGE_COMMAND $6 AFTER_CHANGE_COMMAND
{
SORT="0"
NO_BACKUP="0"

if [[ "$1" = "-s" ]];then
	ACTFILE=$2
	NEWFILE=$3
	NEW_MODE=$4
	NEW_USER=$5
	PRE_CHANGE_COMMAND="$6"
	AFTER_CHANGE_COMMAND="$7"
	SORT="1"
elif [[ "$1" = "-n" ]];then
	ACTFILE=$2
	NEWFILE=$3
	NEW_MODE=$4
	NEW_USER=$5
	PRE_CHANGE_COMMAND="$6"
	AFTER_CHANGE_COMMAND="$7"
	NO_BACKUP="1"
elif [[ "$1" = "-f" ]];then
	ACTFILE=$2
	NEWFILE=$3
	NEW_MODE=$4
	NEW_USER=$5
	PRE_CHANGE_COMMAND="$6"
	AFTER_CHANGE_COMMAND="$7"
	FULL_COMPARE="1"
else
	ACTFILE=$1
	NEWFILE=$2
	NEW_MODE=$3
	NEW_USER=$4
	PRE_CHANGE_COMMAND="$5"
	AFTER_CHANGE_COMMAND="$6"
fi

CHANGED="0"
PROCESS_FILE="0"
DIFF_OUTPUT=""

OUTPUT=$(chmod "${NEW_MODE}" "${NEWFILE}" 2>&1); RC=$?
if [[ ${RC} != "0" ]]; then
	func_msg DEBUG "${OUTPUT}"
	func_msg ERROR "Can not change permission of ${NEWFILE}"
	ERROR_IN_FUNC="1"
	return 1
fi

if [[ ${DRYRUN} != "1" ]]; then
	OUTPUT=$(chown "${NEW_USER}" "${NEWFILE}" 2>&1); RC=$?
	if [[ ${RC} != "0" ]]; then
		func_msg DEBUG "${OUTPUT}"
		func_msg ERROR "Can not change ownership of ${NEWFILE}"
		ERROR_IN_FUNC="1"
		return 1
	fi
fi

if [[ -L "${ACTFILE}" ]]; then
	PROCESS_FILE="1"
fi

if [[ -r "${ACTFILE}" ]]; then

	ACT_USER=$(ls -l ${ACTFILE} |awk '{print $3":"$4}')
	func_msg DEBUG "ACT_USER=[${ACT_USER}]"
	func_msg DEBUG "NEW_USER=[${NEW_USER}]"
	ACT_MODE_RAW=$(ls -l ${ACTFILE} |awk '{print $1}' |sed -e 's/\.//g')
	func_msg DEBUG "ACT_MODE_RAW=[${ACT_MODE_RAW}]"
	NEW_MODE_RAW=$(ls -l ${NEWFILE} |awk '{print $1}' |sed -e 's/\.//g')
	func_msg DEBUG "NEW_MODE_RAW=[${NEW_MODE_RAW}]"
	
	if [[ "${FULL_COMPARE}" = "1" ]]; then
		DIFF_OUTPUT=$(diff -w --suppress-common-lines ${NEWFILE} ${ACTFILE} 2>&1); DIFF_RC=$?
	else
		if [[ "${SORT}" = "1" ]]; then
			func_msg DEBUG "Write ${ACTFILE} to /tmp/tmp_act_$$ without comments and empty lines and sorted."
			cat ${ACTFILE} |grep -v -e "^#" -e "^$" |sort > /tmp/tmp_act_$$
			func_msg DEBUG "Write ${NEWFILE} to /tmp/tmp_new_$$ without comments and empty lines and sorted."
			cat ${NEWFILE} |grep -v -e "^#" -e "^$" |sort > /tmp/tmp_new_$$
		else
			func_msg DEBUG "Write ${ACTFILE} to /tmp/tmp_act_$$ without comments and empty lines."
			cat ${ACTFILE} |grep -v -e "^#" -e "^$" > /tmp/tmp_act_$$
			func_msg DEBUG "Write ${NEWFILE} to /tmp/tmp_new_$$ without comments and empty lines."
			cat ${NEWFILE} |grep -v -e "^#" -e "^$" > /tmp/tmp_new_$$
		fi

		DIFF_OUTPUT=$(diff -w --suppress-common-lines /tmp/tmp_new_$$ /tmp/tmp_act_$$ 2>&1); DIFF_RC=$?
		rm /tmp/tmp_act_$$ /tmp/tmp_new_$$
	fi
	if [[ "${DIFF_RC}" != "0" ]]; then
		PROCESS_FILE="1"
	else
		func_msg DEBUG "no diffs for ${ACTFILE}."
		if [[ ${PROCESS_FILE} != "1" ]]; then
			rm ${NEWFILE}
		fi
	fi
else
	if [[ -f "${ACTFILE}" ]]; then
		func_msg ERROR "Can not open ${ACTFILE} for reading."
		ERROR_IN_FUNC="1"
		return 1
	else
		PROCESS_FILE="1"
	fi
fi

if [[ ${PROCESS_FILE} = "1" ]]; then
	if [[ ${DRYRUN} != "1" ]]; then
		if [[ ${DIFF_OUTPUT} = "" ]] ; then
			if [[ -L "${ACTFILE}" ]]; then
				func_msg INFO "${ACTFILE} is a link. Replacing it."
			else
				func_msg INFO "${ACTFILE} does not exist and will be created."
			fi
		else
			func_msg INFO "${ACTFILE} differs and will be overwritten."
			if [[ ${VERBOSE} = "1" ]] || [[ ${DEBUG} = "1" ]]; then
				func_msg INFO "difference is (left side is new, right side is existing file):"
				func_msg LINE '-'
				echo "${DIFF_OUTPUT}"
				func_msg LINE '-'
			fi
		fi	
		
		if [[ "${NO_BACKUP}" != "1" ]]; then
			func_backup_file ${ACTFILE}
		fi
		
		if [[ "${PRE_CHANGE_COMMAND}" != "" ]];then
			func_run_command "${PRE_CHANGE_COMMAND}"
		fi
		
		func_run_command "mv ${NEWFILE} ${ACTFILE}"
		which restorecon &>/dev/null && func_run_command "restorecon ${ACTFILE}"
		CHANGED="1"
		
		if [[ "${AFTER_CHANGE_COMMAND}" != "" ]];then
			func_run_command "${AFTER_CHANGE_COMMAND}"
		fi
	else
		if [[ ${DIFF_OUTPUT} = "" ]]; then
			if [[ -L "${ACTFILE}" ]]; then
				func_msg INFO "${ACTFILE} is a link and would be replaced. But content is the same!"			
			else
				func_msg INFO "${ACTFILE} does not exist and would be created."
			fi
		else
			func_msg INFO "${ACTFILE} differs and would be overwritten."
			if [[ ${VERBOSE} = "1" ]] || [[ ${DEBUG} = "1" ]]; then
				func_msg INFO "Difference is (left side is new, right side is existing file):"
				func_msg LINE '-'
				echo "${DIFF_OUTPUT}"
				func_msg LINE '-'
			fi
		fi
	fi
else
	if [[ "${ACT_MODE_RAW}" != "${NEW_MODE_RAW}" ]]; then
			if [[ ${DRYRUN} = "1" ]]; then
				func_msg INFO "Mode of ${ACTFILE} would be changed to ${NEW_MODE}."
			else
				func_msg DEBUG "Setting mode of ${ACTFILE} to ${NEW_MODE}."
				func_msg DEBUG "chmod ${NEW_MODE} ${ACTFILE}"
				chmod ${NEW_MODE} ${ACTFILE}
				CHANGED="1"
			fi
	else
		func_msg DEBUG "Mode ok."
	fi
	
	if [[ "${ACT_USER}" != "${NEW_USER}" ]]; then
			if [[ ${DRYRUN} = "1" ]]; then
				func_msg INFO "Ownership of ${ACTFILE} would be cahnged to ${NEW_USER}."
			else
				func_msg DEBUG "Setting owner of ${ACTFILE} to ${NEW_USER}."
				func_msg DEBUG "chown ${NEW_USER} ${ACTFILE}"
				chown ${NEW_USER} ${ACTFILE}
				CHANGED="1"
			fi
	else
		func_msg DEBUG "Owner ok."
	fi
	
	if [[ "${AFTER_CHANGE_COMMAND}" != "" ]] && [[ "${CHANGED}" = "1" ]] ;then
		func_run_command "${AFTER_CHANGE_COMMAND}"
	fi
fi
}

func_erase_rpm() # $* rpms
{
RPMS=$*
RPMS_TO_ERASE=""

for RPM in ${RPMS}; do
	func_msg DEBUG "Check for ${RPM}"
	OUTPUT=$(rpm -q ${RPM}); RPM_RC=$?
	if [[ ${RPM_RC} != "0" ]]; then
		func_msg DEBUG "${OUTPUT}"
		func_msg DEBUG "${RPM} not installed."
	else
		func_msg DEBUG "${RPM} installed."
		RPMS_TO_ERASE="${RPMS_TO_ERASE} ${RPM}"
		func_msg DEBUG "RPMS_TO_ERASE=[${RPMS_TO_ERASE}]"
	fi
done

if [[ ${RPMS_TO_ERASE} != "" ]]; then
	func_run_command "rpm -e ${RPMS_TO_ERASE}"
fi
}

func_get_file_from_server_request()
{
	for DOWNLOAD_SERVER in ${DOWNLOAD_SERVERS}; do
		func_msg DEBUG "DOWNLOAD_SERVER=[${DOWNLOAD_SERVER}]"
		func_msg DEBUG "wget ${HTTP_OPTIONS} -v -O /tmp/${DOWNLOAD_FILE} -T 5 -t 2 ${DOWNLOAD_PROTOCOL}://${DOWNLOAD_SERVER}/${DOWNLOAD_PATH}/${DOWNLOAD_FILE}"
		WGET_OUTPUT=$(wget ${HTTP_OPTIONS} -v -O /tmp/${DOWNLOAD_FILE} -T 5 -t 2 ${DOWNLOAD_PROTOCOL}://${DOWNLOAD_SERVER}/${DOWNLOAD_PATH}/${DOWNLOAD_FILE} 2>&1); WGET_RC=$?
		func_msg DEBUG "WGET_RC=[${WGET_RC}]"
		if [[ "${WGET_RC}" != "0" ]]; then
			func_msg WARNING "Cannot download ${DOWNLOAD_FILE} from DOWNLOAD_SERVER=[${DOWNLOAD_SERVER}]."
			func_msg DEBUG "${WGET_OUTPUT}"
		else
			func_msg DEBUG "Download successful."
			return
		fi
	done
	if [[ "${SLEEP_TIMER}" != "" ]]; then
		func_msg DEBUG "download not ok. Sleep for ${SLEEP_TIMER} seconds [${SLEEP_TIMER_REPEAT}/${SLEEP_TIMER_REPEAT_MAX}]."
		sleep ${SLEEP_TIMER}
	fi
}

func_get_file_from_server() #DOWNLOAD_PROTOCOL #DOWNLOAD_SERVER_RAW #DOWNLOAD_PATH #DOWNLOAD_FILE #SLEEP_TIMER #SLEEP_TIMER_REPEAT_MAX
{
DOWNLOAD_PROTOCOL=$1 	#http
DOWNLOAD_SERVER_RAW=$2 	#httpserver
DOWNLOAD_PATH=$3 	#dsi/data
DOWNLOAD_FILE=$4 	#bootstrap-client-tsy-dsi-prod-${SM_SERVER}.sh
SLEEP_TIMER=$5
SLEEP_TIMER_REPEAT=0
SLEEP_TIMER_REPEAT_MAX=$6
WGET_RC=1

func_msg DEBUG "DOWNLOAD_PROTOCOL=[${DOWNLOAD_PROTOCOL}]"
func_msg DEBUG "DOWNLOAD_SERVER_RAW=[${DOWNLOAD_SERVER_RAW}]"
func_msg DEBUG "DOWNLOAD_PATH=[${DOWNLOAD_PATH}]"
func_msg DEBUG "DOWNLOAD_FILE=[${DOWNLOAD_FILE}]"
func_msg DEBUG "SLEEP_TIMER=[${SLEEP_TIMER}]"
func_msg DEBUG "SLEEP_TIMER_REPEAT_MAX=[${SLEEP_TIMER_REPEAT_MAX}]"

if cat /etc/hosts |grep -v "^#" | grep -qw "${DOWNLOAD_SERVER_RAW}6"; then
	DOWNLOAD_SERVER_RAW="${DOWNLOAD_SERVER_RAW}6"
	HTTP_OPTIONS="-6"
else
	DOWNLOAD_SERVER_RAW="${DOWNLOAD_SERVER_RAW}"
	HTTP_OPTIONS="-4"
fi

DOWNLOAD_SERVERS=$(cat /etc/hosts |grep -v ^# |grep ${DOWNLOAD_SERVER_RAW} |awk '{print $2}')
func_msg DEBUG "DOWNLOAD_SERVERS=[${DOWNLOAD_SERVERS}]"

if [[ ${DOWNLOAD_PROTOCOL} = "https" ]]; then
	HTTP_OPTIONS="${HTTP_OPTIONS} --no-check-certificate --secure-protocol=SSLv3"
fi

if [[ ${SLEEP_TIMER} = "" ]] || [[ ${SLEEP_TIMER} = "-" ]]; then
	func_msg DEBUG "No SLEEP_TIMER set."
	func_get_file_from_server_request
else
	func_msg DEBUG "SLEEP_TIMER set."
	if [[ ${SLEEP_TIMER_REPEAT_MAX} = "" ]] || [[ ${SLEEP_TIMER_REPEAT_MAX} = "-" ]]; then
		func_msg DEBUG "No SLEEP_TIMER_REPEAT_MAX set."
		while [[ ${WGET_RC} != "0" ]]; do
			func_get_file_from_server_request
		done
	else
		func_msg DEBUG "SLEEP_TIMER_REPEAT_MAX set."
		while [[ ${WGET_RC} != "0" ]] && (( ${SLEEP_TIMER_REPEAT} < ${SLEEP_TIMER_REPEAT_MAX} )); do
			SLEEP_TIMER_REPEAT=$((${SLEEP_TIMER_REPEAT} + 1))
			func_get_file_from_server_request
		done
	fi
fi

if [[ ! -s /tmp/${DOWNLOAD_FILE} ]];then
	func_msg ERROR "Cannot download ${DOWNLOAD_FILE}. No ${DOWNLOAD_SERVER_RAW} Servers left."
	ERROR_IN_FUNC="1"
	rm -f /tmp/${DOWNLOAD_FILE} &>/dev/null
	return 1
fi

if [[ "${DOWNLOAD_FILE}" = "md5.txt" ]]; then
	func_msg DEBUG "skip md5 check for file DOWNLOAD_FILE=[${DOWNLOAD_FILE}]."
	return
fi

if [[ ! -r /tmp/md5.txt ]];then
	func_msg WARNING "Cannot read /tmp/md5.txt."
	return
elif ! grep -wq ${DOWNLOAD_FILE} /tmp/md5.txt; then
	func_msg WARNING "Cannot find ${DOWNLOAD_FILE} in /tmp/md5.txt."
	return
else
	SHOULD_MD5="$(grep -w ${DOWNLOAD_FILE} /tmp/md5.txt |awk '{print $1}')"
	func_msg DEBUG "SHOULD_MD5=[${SHOULD_MD5}]"
	IS_MD5=$(md5sum /tmp/${DOWNLOAD_FILE} |awk '{print $1}')
	func_msg DEBUG "IS_MD5=[${IS_MD5}]"
	if [[ ${SHOULD_MD5} != ${IS_MD5} ]]; then
		func_msg ERROR "The md5sum of ${DOWNLOAD_FILE} differs SHOULD_MD5=[${SHOULD_MD5}] IS_MD5=[${IS_MD5}]."
	fi
fi

}

func_manage_service() # $1 SYSCTL_MODE(disable/enable/start/stop/restart) $2 SERVICES
{
SYSCTL_MODE=${1}
func_msg DEBUG "SYSCTL_MODE=[${SYSCTL_MODE}]"
SERVICES=${2}
func_msg DEBUG "SERVICES=[${SERVICES}]"

MODE_SCRIPT="chkconfig"
	
if [[ ${SYSCTL_MODE} = "enable" ]]; then
	SYSV_MODE="on"
elif [[ ${SYSCTL_MODE} = "disable" ]]; then
	if [[ ${DIST} = "sles" ]];then
		SYSV_MODE="-f off"
	else
		SYSV_MODE="off"
	fi
else
	SYSV_MODE="${SYSCTL_MODE}"
	MODE_SCRIPT="service"
fi
func_msg DEBUG "SYSCTL_MODE=[${SYSCTL_MODE}]"

for SERVICE in ${SERVICES}; do
	if which chkconfig &>/dev/null; then
		if [[ -f /etc/init.d/${SERVICE} ]]; then
			func_run_command "${MODE_SCRIPT} ${SERVICE} ${SYSV_MODE}"
		else
			func_msg DEBUG "File /etc/init.d/${SERVICE} does not exist. Do not ${SYSCTL_MODE} it."
		fi
	fi

	if which systemctl &>/dev/null; then
		SERVICE_SHORT="${SERVICE}"
		echo "${SERVICE}" |grep -q "@" && SERVICE_SHORT=$(echo "${SERVICE}" |awk -F'@' '{print $1"@"}')
		func_msg DEBUG "SERVICE=[${SERVICE}]"
		
		if [[ -f /usr/lib/systemd/system/${SERVICE_SHORT}.service ]] || [[ -f /etc/systemd/system/${SERVICE_SHORT}.service ]] ; then
			func_run_command "systemctl ${SYSCTL_MODE} ${SERVICE}"
		else
			func_msg DEBUG "File ${SERVICE}.service does not exist in /usr/lib/systemd/system/ and /etc/systemd/system/ . Do not ${SYSCTL_MODE} it."
		fi
	fi
done
}

func_wait_for_port_on_ip() # $1 PORT $2 HOST $3 SLEEP_TIMER $4 SLEEP_TIMER_REPEAT_MAX
{
#func_wait_for_port_on_ip 443 ${DSI_CONFIG_PATCHSERVER_RHEL} 30 120
PORT=$1
HOST=$2
SLEEP_TIMER=$3
SLEEP_TIMER_REPEAT_MAX=$4
SLEEP_TIMER_REPEAT=0
NMAP_RC="1"
IPV6_OPTS=""

func_msg DEBUG "PORT=[${PORT}]"
func_msg DEBUG "HOST=[${HOST}]"
func_msg DEBUG "SLEEP_TIMER=[${SLEEP_TIMER}]"
func_msg DEBUG "SLEEP_TIMER_REPEAT_MAX=[${SLEEP_TIMER_REPEAT_MAX}]"

if ! which nmap &>/dev/null; then
	func_msg WARNING "No nmap found, skip test of ${PORT} on ${HOST}."
	return
fi

if echo "${HOST}" |grep -q ":"; then
	IPV6_OPTS="-6 "
	func_msg DEBUG "IPV6_OPTS=[${IPV6_OPTS}]"
fi

if cat /etc/hosts |grep -v "^#" | grep -w "${HOST}" |grep -q ":"; then
	IPV6_OPTS="-6 "
	func_msg DEBUG "IPV6_OPTS=[${IPV6_OPTS}]"
fi

if [[ ${SLEEP_TIMER_REPEAT_MAX} = "" ]] || [[ ${SLEEP_TIMER_REPEAT_MAX} = "-" ]]; then
	while [[ ${NMAP_RC} != "0" ]]; do
		func_msg DEBUG "nmap ${IPV6_OPTS}-PN -p${PORT} ${HOST}"
		nmap ${IPV6_OPTS} -PN -p${PORT} ${HOST} 2>&1 |grep -q "${PORT}/tcp open" ; NMAP_RC=$?
		if [[ ${NMAP_RC} != "0" ]]; then
			func_msg DEBUG "nmap to port ${PORT} on host ${HOST} not ok. Sleep for ${SLEEP_TIMER} seconds."
			sleep ${SLEEP_TIMER}
		fi
	done
else
	while [[ ${NMAP_RC} != "0" ]] && (( ${SLEEP_TIMER_REPEAT} < ${SLEEP_TIMER_REPEAT_MAX} )); do
		SLEEP_TIMER_REPEAT=$((${SLEEP_TIMER_REPEAT} + 1))
		func_msg DEBUG "nmap ${IPV6_OPTS}-PN -p${PORT} ${HOST} [${SLEEP_TIMER_REPEAT}/${SLEEP_TIMER_REPEAT_MAX}]"
		nmap ${IPV6_OPTS} -PN -p${PORT} ${HOST} 2>&1 |grep -q "${PORT}/tcp open" ; NMAP_RC=$?
		if [[ ${NMAP_RC} != "0" ]] && (( ${SLEEP_TIMER_REPEAT} < ${SLEEP_TIMER_REPEAT_MAX} )); then
			func_msg DEBUG "nmap to port ${PORT} on host ${HOST} not ok. Sleep for ${SLEEP_TIMER} seconds."
			sleep ${SLEEP_TIMER}
		fi
	done
	if [[ ${NMAP_RC} != "0" ]]; then
		return 1
	fi
fi
}

func_exit()
{
if [[ ${FORCE} != "1" ]]; then
	exit $1
else
	func_msg WARNING "Do no exit $1, Force is set."
fi
}

func_install_rpm() # $* rpms
{
func_msg LIST "Check for rpms to install"
RPMS=$*
for RPM in ${RPMS}; do
	func_msg VINFO "Check for ${RPM}"
	func_msg DEBUG "rpm -q ${RPM}"
	OUTPUT=$(rpm -q ${RPM}); RPM_RC=$?
	if [[ ${RPM_RC} = "0" ]]; then
		func_msg DEBUG "${OUTPUT}"
		func_msg DEBUG "${RPM} installed."
	else
		func_msg DEBUG "${RPM} not installed."
		if [[ ${DRYRUN} != "1" ]]; then
			func_msg DEBUG "${INSTALL_CMD} ${RPM}"
			OUTPUT=$(${INSTALL_CMD} ${RPM} 2>&1); INSTALL_RC=$?
			if [[ ${INSTALL_RC} != "0" ]]; then
				func_msg DEBUG "${OUTPUT}"
				func_msg ERROR "Can not install ${RPM}."
				func_exit 1
			fi
		else
			func_msg INFO "${RPM} would be installed. "
		fi
	fi
done
func_msg LIST "OK"
}

func_install_rpm_version_or_higher() # $1 rpm $2 version
{
RPM=$1
VERSION=$2

func_msg LIST "Check for $1 rpm to install"

func_msg VINFO "Check for ${RPM}-${VERSION}"
func_msg DEBUG "rpm -q ${RPM}"
FULL_RPM=$(rpm -q ${RPM}); RPM_RC=$?
if [[ ${RPM_RC} = "0" ]]; then
	func_msg DEBUG "${FULL_RPM}"
	func_msg DEBUG "${RPM} installed."
	if [[ ${FULL_RPM} = "${RPM}-${VERSION}" ]]; then
		func_msg DEBUG "Ok. ${RPM} is version ${VERSION}."
	else
		func_msg DEBUG "${RPM} is not the same version."
		func_msg DEBUG "check if ${FULL_RPM} is higher than ${RPM}-${VERSION}."
		OLDER_RPM=$(echo -e "${FULL_RPM}\n${RPM}-${VERSION}" |sort -V |head -1)
		if [[ "${OLDER_RPM}" = "${RPM}-${VERSION}" ]]; then
			func_msg DEBUG "Ok. ${RPM} is newer."
		else
			if [[ ${DRYRUN} != "1" ]]; then
				func_msg DEBUG "${UPDATE_CMD} ${RPM}-${VERSION}"
				OUTPUT=$(${UPDATE_CMD} ${RPM}-${VERSION} 2>&1); UPDATE_RC=$?
				if [[ ${UPDATE_RC} != "0" ]]; then
					func_msg DEBUG "${OUTPUT}"
					func_msg ERROR "Can not update ${RPM} to version ${VERSION}, pleas do by hand."
					if [[ ${RPM} = "sudo" ]]; then
						func_msg INFO "TSI sudo packages can be downloaded from http://auditserver.telekom.de"
					fi
					func_exit 1
				fi
			else
				func_msg INFO "${RPM} would be updated to ${VERSION}."
			fi
		fi
	fi
else
	func_msg DEBUG "${RPM} not installed."
	if [[ ${DRYRUN} != "1" ]]; then
		func_msg DEBUG "${INSTALL_CMD} ${RPM}"
		OUTPUT=$(${INSTALL_CMD} ${RPM} 2>&1); INSTALL_RC=$?
		if [[ ${INSTALL_RC} != "0" ]]; then
			func_msg DEBUG "${OUTPUT}"
			func_msg ERROR "Can not install ${RPM}."
			func_exit 1
		fi
	else
		func_msg INFO "${RPM} would be installed. "
	fi
fi

func_msg LIST "OK"
}
