#!/bin/sh

#---------------------------------------------
# Set up dynamic devices

/bin/mount -t sysfs sysfs /sys
/bin/mount -t proc proc /proc
/bin/mount -t usbfs none /proc/bus/usb
/bin/mkdir /dev/pts
/bin/mount -t devpts devpts /dev/pts
/bin/echo /sbin/mdev > /proc/sys/kernel/hotplug
/sbin/mdev -s

#---------------------------------------------

#---------------------------------------------
# Send kernel and system logs to /tmp
# 4 syslog files.  256K each.

/sbin/syslogd -O /var/log/syslog -s 256 -b 4
/sbin/klogd -c 1

#---------------------------------------------
# Patch for bugs in user applications

/bin/mkdir /dev/input
/bin/ln -s ../mice /dev/input/mice
/bin/ln -s ../event0 /dev/input/event0
/bin/ln -s ../event1 /dev/input/event1
/bin/ln -s ../event2 /dev/input/event2
/bin/ln -s ../event3 /dev/input/event3
/bin/ln -s ../event4 /dev/input/event4
/bin/ln -s ../event5 /dev/input/event5
/bin/ln -s ../event6 /dev/input/event6
/bin/ln -s ../event7 /dev/input/event7
/bin/ln -s ../event8 /dev/input/event8
/bin/ln -s ../event9 /dev/input/event9
/bin/ln -s ../event10 /dev/input/event10
/bin/ln -s ../event11 /dev/input/event11
/bin/ln -s ../event12 /dev/input/event12
/bin/ln -s ../event13 /dev/input/event13
/bin/ln -s ../event14 /dev/input/event14
/bin/ln -s ../event15 /dev/input/event15

#---------------------------------------------
# Mount the writable storage FS

/bin/mount -t jffs2 /dev/mtdblock2 /writable

(
/usr/local/bin/flock -x 200 || exit 1
# verify the existence and size of config files during boot and do according adjustments
[ -d /writable/config ] || /bin/mkdir -p /writable/config
if [ ! -s /writable/config/uxp ] || ! /usr/local/bin/uxp_sanity_check.sh uxp ; then
        if [ ! -s /writable/config/uxp_backup ] || ! /usr/local/bin/uxp_sanity_check.sh uxp_backup ; then
                /bin/cp /etc/config/uxp.bak /writable/config/uxp_backup
        fi
        /bin/cp /writable/config/uxp_backup /writable/config/uxp
else
         /bin/cp /writable/config/uxp /writable/config/uxp_backup
fi
	grep "discovery_type" /writable/config/uxp > /dev/null && type=$(/usr/bin/uci -c /writable/config get uxp.service0.discovery_type)
        if [ $type = 1 ]; then
                /usr/bin/uci -c /writable/config set uxp.service0.discovery_type=5
        fi
sync
if [ ! -L /etc/config/uxp ]; then
	/bin/ln -s /writable/config/uxp /etc/config/uxp
fi

if [ ! -L /etc/config/uxp_backup ]; then
	/bin/ln -s /writable/config/uxp_backup /etc/config/uxp_backup
fi

dn=`/usr/bin/uci get uxp.device0.name`
echo device name is ....... $dn
if [ $dn = "Tempest-template" ]; then
	model=$(getdevprop sn|cut -c1-4)
	model_s=$(getdevprop sn|cut -c5-5)
	echo "dev name is ........ $dn"
	if [ "${model}" = "L300" -a "${model_s}" = "E" ]; then
		dn="L250-`/sbin/getdevprop mac| sed "s/://g" | tr '[:lower:]' '[:upper:]'`"
	else
        	dn="NC-`/sbin/getdevprop mac| sed "s/://g" | tr '[:lower:]' '[:upper:]'`"
	fi
        echo "updated to $dn"
	/usr/bin/uci set uxp.device0.name=$dn
	/usr/bin/uci commit uxp
        /bin/cp -f /writable/config/uxp /writable/config/uxp_backup
	
fi
echo $dn > /etc/hostname
sync

)200>/ncconfig.lock
# copying the logos if present any 
/bin/mount -t jffs2 /dev/mtdblock3 /readable
if [ ! -f /qtgui/partner.png  -a  -f /readable/partner.png ]; then
	/bin/cp /readable/partner*.png /qtgui/.
fi
# Setup network with fixed MAC
ip link set eth0 down
ip link set eth0 address 00:1A:2B:3C:4D:5E
ip link set eth0 up
udhcpc -i eth0 -n -q
echo "Network configured with MAC 00:1A:2B:3C:4D:5E"

# Start telnetd for remote access
/usr/sbin/telnetd -l /bin/sh
echo "Telnetd started"

# Start dropbear SSH - keys pre-installed in /etc/dropbear
dropbear -r /etc/dropbear/dropbear_rsa_host_key -d /etc/dropbear/dropbear_dss_host_key
echo "Dropbear SSH started"
# if wireless module exist, then run it
if [ -f /etc/rc.local ]; then
	echo "Installing wireless module"
	/etc/rc.local
fi

model=$(getdevprop sn|cut -c1-4)
if [ "${model}" != "L350" ]; then
	insmod /lib/modules/tempest_usb.ko
	insmod /lib/modules/tempest_i2s.ko
fi

# Start framebuffer terminal
fbterm &
sleep 1
echo "fbterm started"

# Start VNC server with keyboard support
fbvnc_server &
echo "VNC server started on port 5900"
