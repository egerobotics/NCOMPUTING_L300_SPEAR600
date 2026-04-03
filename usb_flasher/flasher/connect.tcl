#!/bin/sh
# the next line restarts using tclsh\
exec tclsh "$0" "$@"
package require cmdline

proc connect_help {} {
	puts "\nUsage (command line) :tclsh connect.tcl -d/--device <device> "
	puts "\nUsage (flasher) : connect/c/1 \
			-d/--device <device> "
	puts "connects to the SPEAr device"
	puts "\ndevice: SPEAr device "
	puts "SPEAr300 / 300    SPEAr310 / 310       SPEAr320 / 320       SPEAr600 / 600"
	puts "SPEAr900 / 900    SPEAr1300 / 1300     SPEAr1310_reva / 1310_reva     SPEAr1340 / 1340"
	puts "SPEAr1310 / 1310"
	return
}



set parameters {
	{-device.arg "" "SPEAr device: SPEAr300 SPEAr310 SPEAr320 SPEAr600 \
		SPEAr900 SPEAr1300 SPEAr1310_reva SPEAr1340 SPEAr1310"}
	{d.arg "" "SPEAr device: SPEAr300 SPEAr310 SPEAr320 SPEAr600 \
		SPEAr900 SPEAr1300 SPEAr1310_reva SPEAr1340 SPEAr1310"}
}
if {[catch {array set arg [cmdline::getoptions argv $parameters]} id]} {
	connect_help
	return 0
}

if {$arg(-device) != "" && $arg(d) == ""} {
	set defdev $arg(-device)
} elseif { $arg(-device) == "" && $arg(d) != ""} {
	set defdev $arg(d)
} elseif { $arg(-device) != "" && $arg(d) != ""} {
	puts "error: --device option and -d option can not be used together"
	connect_help
	return
} else {
	puts "error: device argument is not read"
	connect_help
	return
}

if {$argv != "" } {
	puts "error: extra argument found $argv, which is not required"
	connect_help
	return 0
}

set OS [lindex $tcl_platform(os) 0]
if {$OS == "Windows"} {
	set USB_TOOL ".\\Tools\\Win\\usb_send.exe"
} else {
	set USB_TOOL "./Tools/Linux/usb_send"
}

proc get_serial_ports {} {
	global OS
	if {$OS == "Windows"} {
		package require registry
		set serial_base "HKEY_LOCAL_MACHINE\\HARDWARE\\DEVICEMAP\\SERIALCOMM"
		set values [ registry values $serial_base ]
		set result {}

		foreach valueName $values {
			lappend result [ registry get $serial_base $valueName ]
		}
	} else {
		if {[catch {eval exec ls [glob /dev/ttyA*]} result]} {
			set result {}
		}
	}
	return $result
}

proc connect {defdev} {
	global OS USB_TOOL
	if {[catch {exec $USB_TOOL -dev $defdev} id]} {
	puts "Connection Error"
		return 0
	} else {
		puts "connecting to $defdev"
		after 5000
		catch {get_serial_ports} list_of_ports
		set port [lindex $list_of_ports end]
		puts "Connected to $defdev"
		puts "Port: $port"
		return 1
	}
}


if {$defdev == "600" || $defdev == "300" || $defdev == "310" || $defdev == "320" || $defdev == \
	"1300" || $defdev == "1310_reva" || $defdev == "900" || $defdev == "1340" || \
	$defdev == "900" || $defdev == "1310"} {
		set defdev "SPEAr$defdev"
}

if {$defdev == "SPEAr600" || $defdev == "SPEAr900" || $defdev == "SPEAr310" || \
	$defdev == "SPEAr300" || $defdev == "SPEAr1300" || $defdev == "SPEAr1340" \
	|| $defdev == "SPEAr1310_reva" || $defdev == "SPEAr1310" || $defdev ==	 "SPEAr320"} {
	#uts "Correct Board Selected"
} else {
	puts "error :select correct board"
	connect_help
	return
}

connect $defdev
