import sys, re, time, argparse, traceback
import requests
import subprocess
from requests.auth import HTTPDigestAuth
from xml.etree import ElementTree


# Disable warnings about self-signed certificates 
requests.packages.urllib3.disable_warnings()


DEBUG           = False
SLEEP_SECONDS   = 3

url	=	"https://vcloudtest-muc.t-systems.de/"
vdc_appendix            = "api/vdc/3ef8f5c2-5b41-44e9-81a3-f47e7ce4fcff"

t03_auth                = "Basic dDAzb3NfbG54QHN5c3RlbTohU3RhcnQxMjMh"
T03header               = {'content-type': 'application/vnd.vmware.vcloud.metadata+xml; charset=ISO-8859-1', 'accept' : 'application/*+xml;version=33.0', 'authorization' : t03_auth}

jakukuru_auth           = "Basic amFrdWt1cnVAc3lzdGVtOkpfazE1MHZt"
jakukuruheader          = {'content-type': 'application/vnd.vmware.vcloud.metadata+xml; charset=ISO-8859-1', 'accept' : 'application/*+xml;version=33.0', 'authorization' : jakukuru_auth}

def login(myHeader):
    RESTresponse                = requests.post(url+"api/sessions", headers=myHeader, verify=False)


    # Get cookie
    if(RESTresponse.ok):
        print_time("Login was succesful")

        myHeader['x-vcloud-authorization'] = RESTresponse.headers['x-vcloud-authorization']
        return
    else:
        RESTresponse.raise_for_status()
        sys.exit(-100)

def load_vApp():
    print_time("Retrieving information for vApp: "+ vApp_name)
    RESTresponse = requests.get(url+vdc_appendix, headers=T03header, verify=False)
    if DEBUG:
        print RESTresponse.content
    
    if(RESTresponse.ok):
    
        root = ElementTree.fromstring(re.sub('\\sxmlns="[^"]+"', '', RESTresponse.content, count=1))
        vApp_appendix = None 
        while vApp_appendix == None:
            for child in root.iter('ResourceEntity'):
                if (child.attrib['name'] == vApp_name) and ("vappTemplate" not in child.attrib['href']):
                    vApp_appendix = child.attrib['href'].split("/",3)[-1]
                    print_time("vApp_appendix: "+vApp_appendix)
                    break
            if vApp_appendix:
                wait_for_tasks(vApp_appendix, "vApp")
                return vApp_appendix
            else:
                print_time("Waiting for vApp to be available")
                time.sleep(SLEEP_SECONDS)
    else:
        RESTresponse.raise_for_status()
        sys.exit(-101)



def wait_for_tasks(appendix, description):
    print_time("Waiting for "+description+" tasks to finish", True)
    RESTresponse = requests.get(url+appendix, headers=T03header, verify=False)
    root = ElementTree.fromstring(re.sub('\\sxmlns="[^"]+"', '', RESTresponse.content, count=1))

    while root.find('Tasks') != None:
        running_tasks = False
        for child in root.find('Tasks'):
            if (child.attrib['status'] == "running"):
                running_tasks = True
                break
        if not running_tasks:
            print ""
            return

        time.sleep(SLEEP_SECONDS)
        print ".",
        sys.stdout.flush()
        RESTresponse = requests.get(url+appendix, headers=T03header, verify=False)
        root = ElementTree.fromstring(re.sub('\\sxmlns="[^"]+"', '', RESTresponse.content, count=1))
    print ""



def print_time(message, sameline=False):
    if sameline:
        print time.strftime("[%H:%M:%S] ")+message,
    else:
        print time.strftime("[%H:%M:%S] ")+message



def logout(myHeader):
    RESTresponse                = requests.delete(url+"api/session", headers=myHeader, verify=False)
    if(RESTresponse.ok):
        print_time("Logout was succesful")
    else:
        RESTresponse.raise_for_status()
	sys.exit(-100)


def set_metadata():
    time.sleep(10)
    print_time("Start configuration of metadata")
    metadataHeader      = T03header.copy()
    metadataHeader['content-type'] = "application/vnd.vmware.vcloud.metadata+xml; charset=ISO-8859-1"
    metadata_xml_args   = {'DSI_STATUS' : 'IGNORE'}
   # metadata_xml_args   = { 'DSI_OS' : DSI_OS, 'DSI_FLAG_SID' : '1', 'DSI_STATUS' : 'INITIAL' , 'DSI_IMAGE_TYPE': 'SELFMANAGED' , 'DSI_FLAG_ADMINLAN': '1', 'DSI_FLAG_PWM': '1'}
    metadata_xml_rw	= {'MCS_STATUS' : 'MANAGED' , 'MCS_TYPE' : 'Office'}
   # vm_appendix = "api/vApp/vm-d49a9664-87ed-4db4-af2d-bf19834ad1ea"
    metadata_xml_list   = []
   
   # RESTresponse        = requests.delete(url+vm_appendix+"/metadata/SYSTEM/DSI_TEMPLATE", headers=metadataHeader, verify=False)
    #wait_for_tasks(vApp_appendix, "VM")

    #RESTresponse        = requests.delete(url+vm_appendix+"/metadata/SYSTEM/DSI_HOSTNAME", headers=metadataHeader, verify=False)
    #wait_for_tasks(vApp_appendix, "VM")

    #RESTresponse        = requests.delete(url+vm_appendix+"/metadata/SYSTEM/SID", headers=metadataHeader, verify=False)
    #wait_for_tasks(vApp_appendix, "VM")

    #RESTresponse        = requests.delete(url+vm_appendix+"/metadata/SYSTEM/inventDate", headers=metadataHeader, verify=False)
    #wait_for_tasks(vApp_appendix, "VM")
 

    for key, value in metadata_xml_args.iteritems():
	metadata_xml_list   = []
	metadata_xml_list.append("""<?xml version="1.0" encoding="UTF-8"?><vcloud:Metadata
   	 xmlns:vcloud="http://www.vmware.com/vcloud/v1.5"
   	 xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">""")
        metadata_xml_list.append("""
         <vcloud:MetadataEntry>
            <vcloud:Domain visibility="READONLY">SYSTEM</vcloud:Domain>
            <vcloud:Key>"""+key+"""</vcloud:Key>
            <vcloud:TypedValue xsi:type="vcloud:MetadataStringValue">
                <vcloud:Value>"""+value+"""</vcloud:Value>
            </vcloud:TypedValue>
         </vcloud:MetadataEntry>"""+'\n')
        metadata_xml_list.append("""</vcloud:Metadata>""")

        metadata_xml = ''.join(metadata_xml_list)
       # print_time("METADATA XML"+metadata_xml)
        RESTresponse = requests.post(url+vm_appendix+"/metadata", headers=metadataHeader, data=metadata_xml, verify=False)
        print_time("Waiting for setting metadata field:"+key)
	wait_for_tasks(vApp_appendix, "vApp")
        time.sleep(10)

    for key, value in metadata_xml_rw.iteritems():
        metadata_xml_list   = []
        metadata_xml_list.append("""<?xml version="1.0" encoding="UTF-8"?><vcloud:Metadata
         xmlns:vcloud="http://www.vmware.com/vcloud/v1.5"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">""")
        metadata_xml_list.append("""
         <vcloud:MetadataEntry>
            <vcloud:Key>"""+key+"""</vcloud:Key>
            <vcloud:TypedValue xsi:type="vcloud:MetadataStringValue">
                <vcloud:Value>"""+value+"""</vcloud:Value>
            </vcloud:TypedValue>
         </vcloud:MetadataEntry>"""+'\n')
        metadata_xml_list.append("""</vcloud:Metadata>""")

        metadata_xml = ''.join(metadata_xml_list)
       # print_time("METADATA XML"+metadata_xml)
        RESTresponse = requests.post(url+vm_appendix+"/metadata", headers=metadataHeader, data=metadata_xml, verify=False)
        print_time("Waiting for setting metadata field:"+key)
	wait_for_tasks(vApp_appendix, "vApp")
        time.sleep(10)	  
 
    if DEBUG:
        print RESTresponse.content

    if(RESTresponse.ok):
        print_time("Completed task for configuration of metadata")
    else:
        RESTresponse.raise_for_status()
        sys.exit(-106)

def load_guestcustomization():
    RESTresponse = requests.get(url+vApp_appendix, headers=T03header, verify=False)
    if DEBUG:
        print RESTresponse.content

    if(RESTresponse.ok):
        root = ElementTree.fromstring(re.sub('\\sxmlns="[^"]+"', '', RESTresponse.content, count=1))
        vm_appendix = root.find('Children').find('Vm').attrib['href'].split("/",3)[-1]
        guest_appendix = vm_appendix + "/guestCustomizationSection/"
        print_time("vm_appendix: "+vm_appendix)
        print_time("guest_appendix: "+guest_appendix)
        return (vm_appendix, guest_appendix)
    else:
        RESTresponse.raise_for_status()
        sys.exit(-102)

def set_customization():
    print_time("Changing guest-customization values")
    set_guestHeader = T03header.copy()
    set_guestHeader['content-type'] = "application/vnd.vmware.vcloud.guestCustomizationSection+xml"
        
    wait_for_tasks(vApp_appendix, "vApp")
    wait_for_tasks(vm_appendix, "VM")

    guest_xml = None
    print_time("Using managed guest_xml")
    guest_xml = """<?xml version="1.0" encoding="UTF-8"?>
<GuestCustomizationSection
    xmlns:ovf="http://schemas.dmtf.org/ovf/envelope/1"
    xmlns="http://www.vmware.com/vcloud/v1.5"
    ovf:required="false">
    <ovf:Info>Specifies Guest OS Customization Settings</ovf:Info>
    <Enabled>true</Enabled>
    <AdminPasswordEnabled>false</AdminPasswordEnabled>
    <AdminPasswordAuto>false</AdminPasswordAuto>
    <ComputerName>"""+computer_name+"""</ComputerName>
</GuestCustomizationSection>
"""

    RESTresponse = requests.put(url+guest_appendix, headers=set_guestHeader, data=guest_xml, verify=False)
    if(RESTresponse.ok):
        print_time("Changed guest-customizations successfully.")
    else:
        print RESTresponse.content
        RESTresponse.raise_for_status()


# Main:
if __name__ == "__main__":
    try:
        parser = argparse.ArgumentParser()
        parser.add_argument("vApp_name", help="Name of the vApp you want to modify")
        parser.add_argument("-d", "--debug", help="Enable debug mode", action="store_true")
        parser.add_argument("-o", "--os-type", help="Specify OS-type, e.g. 'sles/12_64'")
        parser.add_argument("-t", "--dsi-template", help="Specify dsi-template, e.g. 'TSY_SLES12.3_MANAGED'")
  #      parser.add_argument("-m", "--managed", help="Set metadata for a managed system. If not specified metadata for selfmanaged are used", action="store_true")
  #      parser.add_argument("-a", "--adminlan", help="Set metadata for a system with adminlan - usually selfmanaged.", action="store_true")
  #      parser.add_argument("--no-delay", help="Do not wait for processes within the OS", action="store_true")
        args = parser.parse_args()
  #      
        if args.vApp_name:
          vApp_name                             =       args.vApp_name
        if args.debug:
          DEBUG                                 =       True
        if args.os_type:
          DSI_OS                                =       args.os_type
        if args.dsi_template:
          DSI_TEMPLATE                          =       args.dsi_template
  #      if args.adminlan:
  #        DSI_ADMINLAN                          =       True
        login(T03header)
        vApp_appendix                   =       load_vApp()
        (vm_appendix, guest_appendix)   =       load_guestcustomization()
	 #computer_name                  =       load_vm(args.managed)
        computer_name                   =       "dsivcloud"
    
   #     if not DEBUG and not args.no_delay:
   #         if args.managed:
   #             print_time("WORKAROUND: Waiting for 5 minutes untill the VM is initially booted successfully.")
   #             time.sleep(300)
   #         else:
   #             wait_for_shutdown()
    
       # undeploy_vApp()
       # set_customization(args.managed)
       # set_metadata(args.managed)

       # print_time("Switch to user kiwi")
       # login(KIWIheader)
       # if not DEBUG and not args.no_delay:
       #     delete_catalogitem(vApp_name+"_n-2")
       #     print_time("Rotation step 1:", True)
       #     rename_catalogitem(vApp_name+"_n-1", vApp_name+"_n-2")
       #     print_time("Rotation step 2:", True)



#print_time("Login as user jakukuru")

#	login(T03header) 

	set_metadata()
	set_customization()
#print_time("Logout as user jakukuru")

#logout(jakukuruheader)
    except KeyboardInterrupt:
        print_time("Interrupted by KeyboardInterrupt")
        traceback.print_exc(file=sys.stdout)
    finally:
        # Was there a successful login? If yes close it
        if 'x-vcloud-authorization' in T03header.keys():
            print_time("Trying to logout")
            logout(T03header)

