#!/bin/bash
#================
# FILE          : config.sh
#----------------
# PROJECT       : openSUSE KIWI Image System
# COPYRIGHT     : (c) 2006 SUSE LINUX Products GmbH. All rights reserved
#               :
# AUTHOR        : Marcus Schaefer <ms@suse.de>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : configuration script for SUSE based
#               : operating systems
#               :
#               :
# STATUS        : BETA
#----------------
#======================================
# Functions...
#--------------------------------------
test -f /.kconfig && . /.kconfig
test -f /.profile && . /.profile

#======================================
# Greeting...
#--------------------------------------
echo "Configure image: [$kiwi_iname]..."

#======================================
# Setup baseproduct link
#--------------------------------------
suseSetupProduct

#======================================
# Setup default runlevel
#--------------------------------------
baseSetRunlevel 3


#======================================
# Activate services
#--------------------------------------
suseActivateDefaultServices
suseInsertService boot.device-mapper
suseInsertService boot.lvm
suseInsertService sshd
suseInsertService sssd 
suseRemoveService iptables 
suseRemoveService ip6tables 
suseRemoveService NetworkManager 
suseRemoveService firewalld 
suseRemoveService SuSEfirewall2 
suseRemoveService SuSEfirewall2_init
suseRemoveService SuSEfirewall2_setup


#======================================
# SuSEconfig
#--------------------------------------
suseConfig

#======================================
# Umount kernel filesystems
#--------------------------------------
baseCleanMount

exit 0
