#!/bin/sh
# the next line restarts using tclsh\
exec tclsh "$0" "$@"

package require cmdline

set OS [lindex $tcl_platform(os) 0]

if {$OS == "Windows"} {
	set KERMIT_TOOL ./Tools/Win/ukermit.exe
} else {
	set KERMIT_TOOL ./Tools/Linux/ukermit
}


proc send_help {} {
        puts "\nUsage (Command line):tclsh send \[option\] --file/-f <file>"
        puts "\nUsage (flasher):send \[option\] \
	--file/f <file>"
	puts "file to be loaded at the address in the memory"
        puts "\noptions"
        puts "--port/-p:"
        puts "serial port to load file, which is optional"
        puts "/dev/ttyACMxx:    ACM port (for linux)"
        puts "COMx              COM port (for Windows)"
        puts "--address/-a:"
        puts "load address in memory, which is optional. Its default value is 0x800000"
        puts "\n--file/-f:"
        puts "file to be loaded"
        puts "\nexample"
        puts "(Command Line)tclsh send.tcl --file ./lsp/spear600_u-boot_usbtty.img "
        puts "(flasher) send --port /dev/ttyACM0 --file ./lsp/spear600_u-boot_usbtty.img "
}



set parameters {
        {-port.arg "" "port: COMx for windows /dev/ttyACMx for Linux , which is optional"}
        {-file.arg "" "file: file to be loaded in the memory "}
        {-address.arg "" "address: address at which file is loaded"}
	{p.arg "" "port: COMx for windows /dev/ttyACMx for Linux, which is optional"}
	{f.arg "" "file: file to be loaded in the memory"}
	{a.arg "" "address: address at which
			file is loaded"}

}

if {[catch {array set arg [cmdline::getoptions argv $parameters]} id]} {
	send_help
	return 0
}

if {$arg(-port) != "" && $arg(p) == ""} {
	set port $arg(-port)
} elseif {$arg(-port) == "" && $arg(p) != ""} {
	set port $arg(p)
} elseif {$arg(-port) != "" && $arg(p) != ""} {
	puts "error: --port and -p option can not be used together"
	send_help
	return
} else {
	#default value of port.It finds the port with get_serial_ports
	set port "port"
}

if {$arg(-file) != "" && $arg(f) == ""} {
	set file $arg(-file)
} elseif {$arg(-file) == "" && $arg(f) != ""} {
	set file $arg(f)
} elseif {$arg(-file) != "" && $arg(f) != ""} {
	puts "error: --file and -f option can not be used together"
	send_help
	return
} else {
	puts "error: unable to find the file option"
	send_help
	return
}

if {$arg(-address) != "" && $arg(a) == ""} {
	set address $arg(-address)
} elseif {$arg(-address) == "" && $arg(a) != ""} {
	set address $arg(a)
} elseif {$arg(-address) != "" && $arg(a) != ""} {
	puts "error: --address and -a option can not be used together"
	return
} else {
	#default value of address
	set address "0x800000"
}

if {$argv != "" } {
        puts "error: extra argument found $argv, which is not required"
        send_help
	return 0
}

if {[catch {set fp [open $file]} id]} {
        puts "error: unable to open file: $file"
        send_help
	return 0
}
close $fp

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


proc uerr {} {
	global defCOM
	puts "Unable to transmit or recieve on $defCOM.\
		Select the correct COM Port.\
		\nOR Try powering on the board and reconnecting"
}

set inukermit 0

if {$port == "port"} {
	if {[catch {get_serial_ports} list_of_ports]} {
		puts "error : no serial port Found"
		puts "first run the connect script"
                return 0
        }
	set port [lindex $list_of_ports end]
}

if {[catch {set sp [open $port]} id]} {
	puts "error: unable to open port"
return 0
}
close $sp

puts "Transfering file $file on Port $port  on address $address"
set defCOM $port
set cmd "-c \"loadb $address\""
set portcmd "-p $defCOM"
set end "-e \"...\""

catch {eval exec tclsh ucmd.tcl $cmd $portcmd $end >@stdout } id

set fname [string range $file [expr [string last / $file] + 1] end]
if {[catch {exec $KERMIT_TOOL -p $defCOM -f $file >@stdout } err]} {
	puts "Error while sending $err"
}

set cmd "-c \" \""
catch {eval exec tclsh ucmd.tcl $cmd $portcmd >@stdout } id

set cmd "-c imi"
catch {eval exec tclsh ucmd.tcl $cmd $portcmd >@stdout } id

################################################################################
################################################################################
