#======================================
# Functions...
#--------------------------------------
test -f /.kconfig && . /.kconfig
test -f /.profile && . /.profile

#rpm -Uvh /tmp/*.rpm

chmod 755 /etc /usr /usr/lib /opt
chmod 644 /etc/passwd
chmod 644 /etc/group

#======================================
# Settings from Bootfile
#--------------------------------------
vmware-toolbox-cmd timesync disable 

echo 'export TZ=${TZ-:/etc/localtime}' > /etc/profile.d/tz.sh
echo 'if ($?TZ == 0) setenv TZ :/etc/localtime' > /etc/profile.d/tz.csh

sed -i 's/DHCLIENT_WAIT_AT_BOOT=.*/DHCLIENT_WAIT_AT_BOOT=\"30\"/' /etc/sysconfig/network/dhcp 2>/dev/null

TSY_LIB="/usr/local/lib/tsy_lib.sh"
if [ -f ${TSY_LIB} ];then
        . ${TSY_LIB}
else
        echo "ERROR: Not able to use the standard TSY library [${TSY_LIB}]!"
        exit 1
fi

# Manage Users
func_run_command "passwd -x 99999 root"
func_run_command "chage -d $(date '+%D') root"
func_msg DEBUG "Setting sudo rights for mcs user."
echo "mcs ALL=(ALL) NOPASSWD:ALL">>/etc/sudoers
func_delete_file /etc/security/opasswd
func_run_command "touch /etc/security/opasswd"

func_run_command "passwd -x 99999 pwadm"
func_run_command "chage -d $(date '+%D') pwadm"
func_run_command "usermod --lock pwadm"
func_run_command "mkdir -m 700 -p /home/pwadm/.ssh"
cat /tmp/pwm_key >> /home/pwadm/.ssh/authorized_keys
func_run_command "chown -R pwadm:pwadm /home/pwadm/.ssh"
func_run_command "chmod 600 /home/pwadm/.ssh/authorized_keys"
rm -rf /tmp/pwm_key
sed -i -e 's/\/boot\/vmlinuz/\/vmlinuz/' -e 's/\/boot\/initramfs/\/initramfs/' /boot/loader/entries/*.conf

for i in adm sync shutdown halt operator; do
 useradd $i
 userdel $i
done

for i in news man uucp wwwrun; do
 usermod -p '!!' $i
 usermod -s '/bin/false' $i
done

func_run_command "usermod -s '/bin/false' man"

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
rpm --import /tmp/T-SYSTEMS-PACKAGING-KEY.pub
#rm -f /tmp/T-SYSTEMS-PACKAGING-KEY.pub


systemctl set-default multi-user.target 

mv /tmp/sshd_config /etc/ssh/sshd_config
echo "-e 2" >> /etc/audit/rules.d/audit.rules
echo "/dev/vg00/lv_swap swap swap defaults 0 0" >> /etc/fstab
# Enable platform-specific bootservice here
systemctl enable NetworkManager
systemctl enable patch-service
systemctl enable polkit.service 
systemctl disable firewalld.service 

ln -s /usr/bin/gunzip /usr/bin/uncompress

echo "vmconaws" > /etc/hostname

RELEASE="2021-01 VMConAWS Managed"

echo -n '
*******************************************************************************
\ \   / /  \/  |/ ___|___  _ __    / \ \      / / ___|
 \ \ / /| |\/| | |   / _ \|  _ \  / _ \ \ /\ / /\___ \
  \ V / | |  | | |__| (_) | | | |/ ___ \ V  V /  ___) |
   \_/  |_|  |_|\____\___/|_| |_/_/   \_\_/\_/  |____/

** Build-Date:' $(date +"%d-%m-%Y %H:%M") '
** OS-Type: Red Hat Linux Enterprise 8
** Image-Version:' $RELEASE '
** Copyright (c) T-Systems International GmbH
*******************************************************************************
' > /etc/motd
chmod 444 /etc/motd


#======================================
# Exit safely
#--------------------------------------
exit
