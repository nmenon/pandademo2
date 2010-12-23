#
# Kick start file for Pandaboard (http://pandaboard.org)
# Discussions in pandaboard@googlegroups.com/meego-porting@lists.meego.com
#
# Author: Jaime Garcia <jagarcia@ti.com>
#
# Revision: 0.1
#
# Copyright (C) 2010 Texas Instruments Incorporated www.ti.com
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.

lang en_US.UTF-8
keyboard us
timezone --utc America/Los_Angeles
auth --useshadow --enablemd5

part /boot --size=64 --ondisk mmcblk0p --fstype=vfat --active
part / --size 1600 --ondisk mmcblk0p --fstype=ext3

rootpw meego
xconfig --startxonboot
desktop --autologinuser=meego --defaultdesktop=DUI --session=/usr/bin/duihome\ -software\ -show-cursor
# Default user
user --name meego --groups audio,video --password meego

# missing users
user --name sshd --homedir=/var/run/sshd --shell=/sbin/nologin --lock
user --name dbus --homedir=/var/run/dbus --shell=/sbin/nologin --lock

# missing groups
group --name=nobody
group --name=dbus
group --name=tty
group --name=polkituser

# Repository - Standard build
repo --name=core    --baseurl=http://repo.meego.com/MeeGo/builds/trunk/1.1.80.11.20101221.1/core/repos/armv7l/packages/ --save --debuginfo --source --gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-meego
repo --name=handset --baseurl=http://repo.meego.com/MeeGo/builds/trunk/1.1.80.11.20101221.1/handset/repos/armv7l/packages/ --save --debuginfo --source --gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-meego
repo --name=non-oss --baseurl=http://repo.meego.com/MeeGo/builds/trunk/1.1.80.11.20101221.1/non-oss/repos/armv7l/packages/ --save --debuginfo --source --gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-meego

# Repository - TI Private
repo --name=panda2demo --baseurl=http://download.meego.com/live/home:/nm:/pandademo2/Trunk --save --debuginfo --source --gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-meego
repo --name=gst-ffmpeg --baseurl=http://download.meego.com/live/home:/suren:/gst-ffmpeg/MeeGo_1.1 --save --debuginfo --source --gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-meego
repo --name=nm-apps --baseurl=http://download.meego.com/live/home:/nm:/applications/Trunk --save --debuginfo --source --gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-meego

# repository for uboot mikimage tool
repo --name=uboot-mkimage --baseurl=http://download.meego.com/live/home:/marko.saukko/standard --save --debuginfo --source --gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-meego

%packages --excludedocs

@MeeGo Core
@MeeGo Base
@X for Handsets
@Minimal Meego X Window System
@MeeGo Handset Desktop
@MeeGo Handset Applications

# Boot images
kernel-panda
u-boot-omap4_panda
x-loader-omap4430panda

# drivers for Xorg
xorg-x11-drv-omapfb
xorg-x11-utils-xinput
xorg-x11-utils-xev
# Gfx accelleration - use s/w for the timebeing
mesa-dri-swrast-driver

# install mkimage
uboot-mkimage

# extra tools
bash
udev
wget
strace
zypper
man
corkscrew

# Multimedia
gstreamer
gst-v4l2-camsrc
gstreamer-tools
alsa-lib
alsa-plugins-pulseaudio
alsa-plugins-samplerate
alsa-plugins-upmix
alsa-plugins-usbstream
alsa-plugins-vdownmix
alsa-utils

# TI Tools
gst-ffmpeg

# Editors
vim
nano

# net tools
iproute
iputils
net-tools
wireless-tools
openssh-server
openssh-clients
ethtool
iptables
wpa_supplicant
wlanconfig

# Devel
qt
python
perl
latencytop
powertop
htop

# Desktop manager
#xfce4-session
#xfce4-desktop-branding-moblin
#twm

%end

%post

# remove unused package
rpm -e xorg-x11-meego-configs
rpm -e meegotouch-inputmethodkeyboard
rpm -e sample-media

# make sure there aren't core files lying around
rm -f /core*

# Prelink can reduce boot time
if [ -x /usr/sbin/prelink ]; then
    /usr/sbin/prelink -aRqm
fi

# open serial line console for embedded system
grep ttyO2 /etc/inittab
if [ "$?" != "0" ] ; then
    echo "o2:235:respawn:/sbin/agetty -L 115200 ttyO2 vt100" >> /etc/inittab
fi
grep ttyO2 /etc/securetty
if [ "$?" != "0" ] ; then
    echo "ttyO2" >> /etc/securetty
fi

# prevent evbug module being loaded
echo "blacklist evbug" >> /etc/modprobe.d/blacklist.conf

# convert vmlinuz to uImage using uboot tools
mkimage  -A arm -O linux -T kernel -C none -a 80008000 -e 80008000 -n vmlinuz -d /boot/vmlinuz* /boot/uImage

# add option to desktop applications to show the mouse cursor
(cd /usr/share/applications; for filename in `ls *.desktop|grep -v "fennec\|xterm\|browser"`; do sed -i 's/\(^Exec=\)\(.*\)/\1\2 -show-cursor/' $filename; done)

%end

%post --nochroot

# we don't need this files for now
rm -f $INSTALL_ROOT/etc/X11/xorg.conf.d/10-input-synaptics.conf

# make sure fennec shows cursor
sed -i '5iARGS=\"$ARGS -show-cursor\"' $INSTALL_ROOT/usr/bin/fennec

# enable software renderer to run apps
echo 'export M_USE_SOFTWARE_RENDERING=1' >> $INSTALL_ROOT/home/meego/.bashrc

# use autodetect as default conf
mv $INSTALL_ROOT/usr/share/meegotouch/targets/Default.conf $INSTALL_ROOT/usr/share/meegotouch/targets/800x600.conf
cp $INSTALL_ROOT/usr/share/meegotouch/targets/autodetect.conf $INSTALL_ROOT/usr/share/meegotouch/targets/Default.conf

# install our software
PKGS="linux-image-2.6.35-903-omap4-2.6.35.tgz \
      libgdata7-0.6.4.tgz \
      libgrilo-0.1-0.1.6.tgz \
      grilo-0.1-plugins-0.1.6.tgz"

for i in $PKGS; do
    if [ -f $i ]; then
       tar zxvf $i -C $INSTALL_ROOT
    fi
done

# configuration for omap video (we need the device conf as well)
cat << OMAPFB >> $INSTALL_ROOT/etc/X11/xorg.conf.d/00-device-omapfb.conf
Section "Device"
    Identifier "omapfb"
    driver     "omapfb"
    Option     "fb" "/dev/fb0"
EndSection
OMAPFB

# Add Meego to sudoers list
cat << SUDOERS >> $INSTALL_ROOT/etc/sudoers
meego ALL=(ALL) ALL
SUDOERS
%end
