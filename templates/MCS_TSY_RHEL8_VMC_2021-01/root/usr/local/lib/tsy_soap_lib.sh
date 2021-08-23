#!/bin/bash
##################################################################
# TSY soap functions library
#
# Author: 	"Marcel Wiederer"
# Mail:		"marcel.wiederer@t-systems.com"
# Date:		"29.05.2017"
# Version:	"1_0.0"
# Description:	"T-Systems library for soap functions."
#
#
# History:
#1_0.0          29.05.2017      mwiedere        Initial version
#1_1.0 		19.01.2018	sdursch		Added dvma_maintainBackend
##################################### SOAP FUNCTIONS ####################################

# general return codes from soap_calls below
#  0     OK
#  1-92  CURL ERROR
#  127   CURL NOT FOUND
#  200   SOAP EXCEPTION
#
#  all codes greater than 0 result in a soap exception

#TSY_LIB="/usr/local/lib/tsy_lib.sh"
#if [ -f ${TSY_LIB} ];then
#	. ${TSY_LIB}
#else
#	echo "ERROR: Not able to use the standard TSY libary [${TSY_LIB}]!"
#	exit 5
#fi



debug_soap_call() {
	func_msg DEBUG ">> RC = '$1'"
	func_msg DEBUG ">> Return = '$2'"
	func_msg DEBUG ">> Exception = '$3'"
}

soap_exception_handler() {
	ret="[SOAP EXCEPTION: rc=\"$2\" faultcode=\"$3\" faultstring=\"$4\"]"
	eval "$1='"${ret//[$'\'']/\'\\\'\'}"'"
}

soap_escape_xmls() {
        local var=$@
        var=${var//[$'&']/&amp;}
        var=${var//[$'\"']/&quot;}
        var=${var//[$'\'']/&apos;}
        var=${var//[$'<']/&lt;}
        var=${var//[$'>']/&gt;}
        var=$(echo $var | awk '{$1= ""; print $0}')
        var=$(echo $var | sed -e 's/^[ \t]*//')
        eval "$1='"${var//[$'\'']/\'\\\'\'}"'"
}

soap_escape_xml() {
	local var=$2
	var=${var//[$'&']/&amp;}
	var=${var//[$'\"']/&quot;}
	var=${var//[$'\'']/&apos;}
	var=${var//[$'<']/&lt;}
	var=${var//[$'>']/&gt;}

	eval "$1='"${var//[$'\'']/\'\\\'\'}"'"
}

soap_parse() {
	var=$2
	tmp=${var##*$3}
	returnvar=${tmp%%$4*}

	#eval "$1='"${returnvar//[$'\'']/\'\\\'\'}"'"
	eval "$1=$'"${returnvar//[$'\'']/\\x27}"'"
}

soap_call() {
	local soap_url=$3
	local soap_fnc=$4
	local soap_xml=$5
	#backtick below cannot be local because of RC $?
	#####soap_out=$(echo $soap_xml | curl -s --insecure --header "Content-Type: text/xml;charset=UTF-8" --header "$soap_fnc" --data @- $soap_url)
	soap_out=$(2>&1 curl --insecure --header "Content-Type: text/xml;charset=UTF-8" --header "$soap_fnc" --data @- $soap_url <<< "$soap_xml")
	local soap_rc=$?

	local soap_faultcode=""
	local soap_faultstring=""
	local soap_exception=""

	if [ $soap_rc -eq 0 ] ; then

		if [[ $soap_out == *"<faultcode>"* ]] || [[ $soap_out == *"<faultstring>"* ]] ; then
			soap_faultcode="errot"
			soap_faultstring="error"
			soap_rc=200

			if [[ $soap_out == *"<faultcode>"* ]] ; then
				soap_parse soap_faultcode "$soap_out" "<faultcode>" "</faultcode>"
				soap_faultcode=${soap_faultcode//[$'\t\r\n']}
			fi

			if [[ $soap_out == *"<faultstring>"* ]] ; then
				soap_parse soap_faultstring "$soap_out" "<faultstring>" "</faultstring>"
				soap_faultstring=${soap_faultstring//[$'\t\r\n']}
			fi
		fi
	else
		soap_faultcode="soap:Curl[$soap_rc]"
		soap_faultstring=$soap_out
		soap_faultstring=${soap_faultstring//[$'\t\r\n']}
		soap_out=""
	fi

	if [ $soap_rc -ne 0 ] ; then
		soap_exception_handler soap_exception "$soap_rc" "$soap_faultcode" "$soap_faultstring"
	fi

	eval "$1='"${soap_out//[$'\'']/\'\\\'\'}"'"
	eval "$2='"${soap_exception//[$'\'']/\'\\\'\'}"'"

	return $soap_rc
}


##################################### DVMA FUNCTIONS ####################################

dvma_version() {

	local var_xmlout=""
	local var_return=""
	local var_exception=""

	read -r -d '' soap_xml_request << EOM
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xs="http://www.w3.org/2001/XMLSchema">
   <soapenv:Header/>
   <soapenv:Body>
	  <xs:version/>
   </soapenv:Body>
</soapenv:Envelope>
EOM

	soap_call var_xmlout var_exception "$3" "version" "$soap_xml_request"
	rc=$?

	if [ $rc -eq 0 ] ; then
		soap_parse var_return "$var_xmlout" "<return>" "</return>"
	fi

	eval "$1='"${var_return//[$'\'']/\'\\\'\'}"'"
	eval "$2='"${var_exception//[$'\'']/\'\\\'\'}"'"

	return $rc
}

dvma_testConnection() {

	local passphrase
	local var_xmlout=""
	local var_return=""
	local var_exception=""

	soap_escape_xml passphrase $4

	read -r -d '' soap_xml_request << EOM
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xs="http://www.w3.org/2001/XMLSchema">
   <soapenv:Header/>
   <soapenv:Body>
      <xs:testConnection>
         <passphrase>$passphrase</passphrase>
      </xs:testConnection>
   </soapenv:Body>
</soapenv:Envelope>
EOM

	soap_call var_xmlout var_exception "$3" "testConnection" "$soap_xml_request"
	rc=$?

	if [ $rc -eq 0 ] ; then
		soap_parse var_return "$var_xmlout" "<return>" "</return>"
	fi

	eval "$1='"${var_return//[$'\'']/\'\\\'\'}"'"
	eval "$2='"${var_exception//[$'\'']/\'\\\'\'}"'"

	return $rc
}

dvma_orderTemporaryAdmin() {

	local apiKey
	local sid
	local osUser
	local comment

	local var_return=""
	local var_xmlout=""
	local var_exception=""

	soap_escape_xml apiKey $4
	soap_escape_xml sid $5
	soap_escape_xml osUser $6
	soap_escape_xml comment $7

	read -r -d '' soap_xml_request << EOM
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xs="http://www.w3.org/2001/XMLSchema">
   <soapenv:Header/>
   <soapenv:Body>
      <xs:orderTemporaryAdmin>
         <apiKey>$apiKey</apiKey>
         <sid>$sid</sid>
         <osUser>$osUser</osUser>
         <comment>$comment</comment>
      </xs:orderTemporaryAdmin>
   </soapenv:Body>
</soapenv:Envelope>
EOM

	soap_call var_xmlout var_exception "$3" "orderTemporaryAdmin" "$soap_xml_request"
	rc=$?

	if [ $rc -eq 0 ] ; then
		soap_parse var_return "$var_xmlout" "<return>" "</return>"
	fi

	eval "$1='"${var_return//[$'\'']/\'\\\'\'}"'"
	eval "$2='"${var_exception//[$'\'']/\'\\\'\'}"'"

	return $rc
}

dvma_orderTemporaryAdminV2() {

	local apiKey
	local sid
	local osUser
	local comment
	local reqUser
	local clientVersion


	local var_return=""
	local var_xmlout=""
	local var_exception=""

	soap_escape_xml apiKey $4
	soap_escape_xml sid $5
	soap_escape_xml osUser $6
	soap_escape_xml comment $7
	soap_escape_xml reqUser $8
	soap_escape_xml clientVersion $9


	read -r -d '' soap_xml_request << EOM
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xs="http://www.w3.org/2001/XMLSchema">
   <soapenv:Header/>
   <soapenv:Body>
      <xs:orderTemporaryAdminV2>
         <apiKey>$apiKey</apiKey>
         <sid>$sid</sid>
         <osUser>$osUser</osUser>
         <comment>$comment</comment>
         <reqUser>$reqUser</reqUser>
         <clientVersion>$clientVersion</clientVersion>
      </xs:orderTemporaryAdminV2>
   </soapenv:Body>
</soapenv:Envelope>
EOM

	soap_call var_xmlout var_exception "$3" "orderTemporaryAdminV2" "$soap_xml_request"
	rc=$?

	if [ $rc -eq 0 ] ; then
		soap_parse var_return "$var_xmlout" "<return>" "</return>"
	fi

	eval "$1='"${var_return//[$'\'']/\'\\\'\'}"'"
	eval "$2='"${var_exception//[$'\'']/\'\\\'\'}"'"

	return $rc
}

dvma_revokeTemporaryAdmin() {

	local apiKey
	local sid
	local osUser
	local comment
	local reqUser
	local clientVersion


	local var_return=""
	local var_xmlout=""
	local var_exception=""

	soap_escape_xml apiKey $4
	soap_escape_xml sid $5
	soap_escape_xml osUser $6
	soap_escape_xml reqUser $7
	soap_escape_xml clientVersion $8


	read -r -d '' soap_xml_request << EOM
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xs="http://www.w3.org/2001/XMLSchema">
   <soapenv:Header/>
   <soapenv:Body>
      <xs:revokeTemporaryAdmin>
         <apiKey>$apiKey</apiKey>
         <sid>$sid</sid>
         <osUser>$osUser</osUser>
         <reqUser>$reqUser</reqUser>
         <clientVersion>$clientVersion</clientVersion>
      </xs:revokeTemporaryAdmin>
   </soapenv:Body>
</soapenv:Envelope>
EOM

	soap_call var_xmlout var_exception "$3" "revokeTemporaryAdmin" "$soap_xml_request"
	rc=$?

	if [ $rc -eq 0 ] ; then
		soap_parse var_return "$var_xmlout" "<return>" "</return>"
	fi

	eval "$1='"${var_return//[$'\'']/\'\\\'\'}"'"
	eval "$2='"${var_exception//[$'\'']/\'\\\'\'}"'"

	return $rc
}


dvma_whoHasTemporaryAdmin() {

	local apiKey
	local sid
	local clientVersion


	local var_return=""
	local var_xmlout=""
	local var_exception=""

	soap_escape_xml apiKey $4
	soap_escape_xml sid $5
	soap_escape_xml clientVersion $6


	read -r -d '' soap_xml_request << EOM
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xs="http://www.w3.org/2001/XMLSchema">
   <soapenv:Header/>
   <soapenv:Body>
      <xs:whoHasTemporaryAdmin>
         <apiKey>$apiKey</apiKey>
         <sid>$sid</sid>
         <clientVersion>$clientVersion</clientVersion>
      </xs:whoHasTemporaryAdmin>
   </soapenv:Body>
</soapenv:Envelope>
EOM

	soap_call var_xmlout var_exception "$3" "whoHasTemporaryAdmin" "$soap_xml_request"
	rc=$?

	if [ $rc -eq 0 ] ; then
		soap_parse var_return "$var_xmlout" "<return>" "</return>"
	fi

	eval "$1='"${var_return//[$'\'']/\'\\\'\'}"'"
	eval "$2='"${var_exception//[$'\'']/\'\\\'\'}"'"

	return $rc
}


dvma_startupInitiated() {

	local apiKey
	local sid


	local var_return=""
	local var_xmlout=""
	local var_exception=""

	soap_escape_xml apiKey $4
	soap_escape_xml sid $5


	read -r -d '' soap_xml_request << EOM
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xs="http://www.w3.org/2001/XMLSchema">
   <soapenv:Header/>
   <soapenv:Body>
      <xs:startupInitiated>
         <apiKey>$apiKey</apiKey>
         <sid>$sid</sid>
      </xs:startupInitiated>
   </soapenv:Body>
</soapenv:Envelope>
EOM

	soap_call var_xmlout var_exception "$3" "startupInitiated" "$soap_xml_request"
	rc=$?

	if [ $rc -eq 0 ] ; then
		soap_parse var_return "$var_xmlout" "<return>" "</return>"
	fi

	eval "$1='"${var_return//[$'\'']/\'\\\'\'}"'"
	eval "$2='"${var_exception//[$'\'']/\'\\\'\'}"'"

	return $rc
}

dvma_startupInitiatedV2() {

	local apiKey
	local sid
	local clientVersion


	local var_return=""
	local var_xmlout=""
	local var_exception=""

	soap_escape_xml apiKey $4
	soap_escape_xml sid $5
	soap_escape_xml clientVersion $6


	read -r -d '' soap_xml_request << EOM
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xs="http://www.w3.org/2001/XMLSchema">
   <soapenv:Header/>
   <soapenv:Body>
      <xs:startupInitiatedV2>
         <apiKey>$apiKey</apiKey>
         <sid>$sid</sid>
         <clientVersion>$clientVersion</clientVersion>
      </xs:startupInitiatedV2>
   </soapenv:Body>
</soapenv:Envelope>
EOM

	soap_call var_xmlout var_exception "$3" "startupInitiatedV2" "$soap_xml_request"
	rc=$?

	if [ $rc -eq 0 ] ; then
		soap_parse var_return "$var_xmlout" "<return>" "</return>"
	fi

	eval "$1='"${var_return//[$'\'']/\'\\\'\'}"'"
	eval "$2='"${var_exception//[$'\'']/\'\\\'\'}"'"

	return $rc
}


dvma_shutdownInitiated() {

	local apiKey
	local sid


	local var_return=""
	local var_xmlout=""
	local var_exception=""

	soap_escape_xml apiKey $4
	soap_escape_xml sid $5


	read -r -d '' soap_xml_request << EOM
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xs="http://www.w3.org/2001/XMLSchema">
   <soapenv:Header/>
   <soapenv:Body>
      <xs:shutdownInitiated>
         <apiKey>$apiKey</apiKey>
         <sid>$sid</sid>
      </xs:shutdownInitiated>
   </soapenv:Body>
</soapenv:Envelope>
EOM

	soap_call var_xmlout var_exception "$3" "shutdownInitiated" "$soap_xml_request"
	rc=$?

	if [ $rc -eq 0 ] ; then
		soap_parse var_return "$var_xmlout" "<return>" "</return>"
	fi

	eval "$1='"${var_return//[$'\'']/\'\\\'\'}"'"
	eval "$2='"${var_exception//[$'\'']/\'\\\'\'}"'"

	return $rc
}

dvma_shutdownInitiatedV2() {

	local apiKey
	local sid
	local clientVersion


	local var_return=""
	local var_xmlout=""
	local var_exception=""

	soap_escape_xml apiKey $4
	soap_escape_xml sid $5
	soap_escape_xml clientVersion $6


	read -r -d '' soap_xml_request << EOM
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xs="http://www.w3.org/2001/XMLSchema">
   <soapenv:Header/>
   <soapenv:Body>
      <xs:shutdownInitiatedV2>
         <apiKey>$apiKey</apiKey>
         <sid>$sid</sid>
         <clientVersion>$clientVersion</clientVersion>
      </xs:shutdownInitiatedV2>
   </soapenv:Body>
</soapenv:Envelope>
EOM

	soap_call var_xmlout var_exception "$3" "shutdownInitiatedV2" "$soap_xml_request"
	rc=$?

	if [ $rc -eq 0 ] ; then
		soap_parse var_return "$var_xmlout" "<return>" "</return>"
	fi

	eval "$1='"${var_return//[$'\'']/\'\\\'\'}"'"
	eval "$2='"${var_exception//[$'\'']/\'\\\'\'}"'"

	return $rc
}


dvma_isMonitoringforVMenabled() {

	local apiKey
	local sid
	local clientVersion

	local var_return=""
	local var_xmlout=""
	local var_exception=""

	soap_escape_xml apiKey $4
	soap_escape_xml sid $5
	soap_escape_xml clientVersion $6

	read -r -d '' soap_xml_request << EOM
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xs="http://www.w3.org/2001/XMLSchema">
   <soapenv:Header/>
   <soapenv:Body>
      <xs:isMonitoringforVMenabled>
         <apiKey>$apiKey</apiKey>
         <sid>$sid></sid>
         <clientVersion>$clientVersion</clientVersion>
      </xs:isMonitoringforVMenabled>
   </soapenv:Body>
</soapenv:Envelope>
EOM

	soap_call var_xmlout var_exception "$3" "isMonitoringforVMenabled" "$soap_xml_request"
	rc=$?

	if [ $rc -eq 0 ] ; then
		soap_parse var_return "$var_xmlout" "<return>" "</return>"
	fi

	eval "$1='"${var_return//[$'\'']/\'\\\'\'}"'"
	eval "$2='"${var_exception//[$'\'']/\'\\\'\'}"'"

	return $rc
}


dvma_rebootInitiated() {

	local apiKey
	local sid
	local clientVersion


	local var_return=""
	local var_xmlout=""
	local var_exception=""

	soap_escape_xml apiKey $4
	soap_escape_xml sid $5
	soap_escape_xml clientVersion $6


	read -r -d '' soap_xml_request << EOM
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xs="http://www.w3.org/2001/XMLSchema">
   <soapenv:Header/>
   <soapenv:Body>
      <xs:rebootInitiated>
         <apiKey>$apiKey</apiKey>
         <sid>$sid</sid>
         <clientVersion>$clientVersion</clientVersion>
      </xs:rebootInitiated>
   </soapenv:Body>
</soapenv:Envelope>
EOM

	soap_call var_xmlout var_exception "$3" "rebootInitiated" "$soap_xml_request"
	rc=$?

	if [ $rc -eq 0 ] ; then
		soap_parse var_return "$var_xmlout" "<return>" "</return>"
	fi

	eval "$1='"${var_return//[$'\'']/\'\\\'\'}"'"
	eval "$2='"${var_exception//[$'\'']/\'\\\'\'}"'"

	return $rc
}

dvma_maintainBackend() {

        local apiKey
        local sid
        local comment
        local reqUser
        local clientVersion
        local reqData


        local var_return=""
        local var_xmlout=""
        local var_exception=""

        soap_escape_xmls apiKey $4
        soap_escape_xmls sid $5
        soap_escape_xmls comment $6
        soap_escape_xmls reqUser $7
        soap_escape_xmls clientVersion $8
        soap_escape_xmls reqData $9


        read -r -d '' soap_xml_request << EOM
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xs="http://www.w3.org/2001/XMLSchema">
   <soapenv:Header/>
   <soapenv:Body>
      <xs:maintainBackend>
         <apiKey>$apiKey</apiKey>
         <sid>$sid</sid>
         <comment>$comment</comment>
         <reqUser>$reqUser</reqUser>
         <clientVersion>$clientVersion</clientVersion>
         <reqData>$reqData</reqData>
      </xs:maintainBackend>
   </soapenv:Body>
</soapenv:Envelope>
EOM

        soap_call var_xmlout var_exception "$3" "maintainBackend" "$soap_xml_request"
        rc=$?

        if [ $rc -eq 0 ] ; then
                soap_parse var_return "$var_xmlout" "<return>" "</return>"
        fi

        eval "$1='"${var_return//[$'\'']/\'\\\'\'}"'"
        eval "$2='"${var_exception//[$'\'']/\'\\\'\'}"'"

        return $rc
}

