#======================================
# Functions...
#--------------------------------------
test -f /.kconfig && . /.kconfig
test -f /.profile && . /.profile

#rpm -Uvh /tmp/*.rpm

chmod 755 /etc /usr /usr/lib /opt
chmod 644 /etc/passwd
chmod 644 /etc/group

##########TEST
#sed -i 's/tsy-dsi_boot.log/mytest_boot.log/g' /usr/local/sbin/tsy-dsi_boot.sh


#======================================
# Settings from Bootfile
#--------------------------------------
vmware-toolbox-cmd timesync disable 

# Bugfix for SLES15 open-vm-tools
#touch /etc/issue

echo 'export TZ=${TZ-:/etc/localtime}' > /etc/profile.d/tz.sh
echo 'if ($?TZ == 0) setenv TZ :/etc/localtime' > /etc/profile.d/tz.csh

TSY_LIB="/usr/local/lib/tsy_lib.sh"
if [ -f ${TSY_LIB} ];then
        . ${TSY_LIB}
else
        echo "ERROR: Not able to use the standard TSY library [${TSY_LIB}]!"
        exit 1
fi

# Manage Users
#func_run_command "passwd -x 99999 root"
#func_run_command "chage -d $(date '+%D') root"
func_msg DEBUG "Setting sudo rights for mcs user."
echo "mcs ALL=(ALL) NOPASSWD:ALL">>/etc/sudoers
func_delete_file /etc/security/opasswd
func_run_command "touch /etc/security/opasswd"


#func_ensure_line_in_file /etc/profile "alias rooter='sudo /usr/bin/rootsh -i -u root'"

#rm -rf /tmp/pwm_key

func_run_command "useradd adm"
func_run_command "userdel adm"
func_run_command "usermod -p '!!' man"
func_run_command "usermod -s '/bin/false' man"

#Sudo configuration to ensure sudo will ask source user password

sed -i 's/Defaults targetpw/#Defaults targetpw/g' /etc/sudoers
sed -i 's/ALL   ALL=(ALL) ALL/#ALL   ALL=(ALL) ALL/g' /etc/sudoers

#Ssh moduli configuration according security requirements.

(awk '{if($5>2046)print$0}' < /etc/ssh/moduli)>>/tmp/moduli
mv /etc/ssh/moduli /etc/ssh/bck.moduli.bck
mv /tmp/moduli /etc/ssh/moduli

#======================================
# Greeting...
#--------------------------------------
echo "Configure image: [$kiwi_iname]..."

#======================================
# Call configuration code/functions
#--------------------------------------

#rpm --import /tmp/T-SYSTEMS-PACKAGING-KEY.pub
rpmdb --rebuilddb
#rm -f /tmp/T-SYSTEMS-PACKAGING-KEY.pub
rm -rf hosts.equiv
mv /tmp/sshd_config /etc/ssh/sshd_config
systemctl set-default multi-user.target 

#Needed for patching service
mv /tmp/rmt-az* /etc/pki/trust/anchors/
update-ca-certificates

echo "/dev/vg00/lv_swap swap swap defaults 0 0" >> /etc/fstab
# Enable platform-specific bootservice here
systemctl enable tsy-patch-service.service
systemctl enable polkit.service
systemctl disable firewalld.service
systemctl enable chronyd
echo "-e 2" >> /etc/audit/rules.d/audit.rules
ln -s /usr/bin/gunzip /usr/bin/uncompress
echo "vmconaws" > /etc/hostname

RELEASE="2021-01 VMConAWS Managed"

echo -n '
*******************************************************************************
\ \   / /  \/  |/ ___|___  _ ___   / \ \      / / ___|
 \ \ / /| |\/| | |   / _ \| _ \ | / _ \ \ /\ / /\___ \
  \ V / | |  | | |__| (_) | | | |/ ___ \ V  V /  ___) |
   \_/  |_|  |_|\____\___/|_| |_/_/   \_\_/\_/  |____/

** Build-Date:' $(date +"%d-%m-%Y %H:%M") '
** OS-Type: Suse Linux Enterprise Server 15
** Image-Version:' $RELEASE '
** Copyright (c) T-Systems International GmbH
*******************************************************************************
' > /etc/motd
chmod 444 /etc/motd

#======================================
# Exit safely
#--------------------------------------
exit
