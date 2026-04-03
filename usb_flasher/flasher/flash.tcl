#!/bin/sh
# the next line restarts using tclsh\
exec tclsh "$0" "$@"
package require cmdline
set OS [lindex $tcl_platform(os) 0]

proc flash_help {} {
	puts "\nUsage(Command Line):tclsh flash.tcl \[option\] --memory/m \
		<nor/nand> --file/-f <file> --address/-a <address> "
	puts "\nUsage(flasher): flash \[option\] --memory/m \
		<nor/nand> --file/-f <file> --address/-a <address> "
	puts "flash the file on particular base address in nor/nand memory "
	puts "\noptions"
	puts "--port/-p: serial port to send file on device"
	puts "/dev/ttyACMxx:    ACM port (for linux)"
	puts "COMx              COM port (for Windows)"
	puts "\n--file/-f:"
	puts "file to be flashed"
	puts "\n--memory/-m:"
	puts "memory nor/nand"
	puts "\n--address/-a:"
	puts "address at which file will be flashed in the memory"
	puts "\nexample"
	puts "(Command Line)tclsh flash.tcl -port /dev/ttyACM0 -memory nor\
		file ./lsp/spear600_u-boot_usbtty.img -a 0xe6000000"
	puts "(flasher) flash -m nand -file ../lsp/spear600_u-boot_usbtty.img\
		-a 0xf0000000"
	return 0
}

set parameters {
	{-port.arg "" "port: COMx for windows /dev/ttyACMx for Linux \
		, which is optional"}
	{-memory.arg "" "environment variable, it can be nor or nand"}
	{-file.arg "" "file: file to be flashed in nor/nand memory"}
	{-address.arg "" "address: address at which file will be flashed in the memory"}
	{p.arg "" "port: COMx for windows /dev/ttyACMx for \
		Linux, which is optional"}
	{m.arg "" "environment variable, it can be nor or nand"}
	{f.arg "" "file: file to be flashed in nor/nand memory"}
	{a.arg "" "address: address at which file will be flashed in the memory"}
}

if {[catch {array set arg [cmdline::getoptions argv $parameters]} id]} {
	flash_help
	return 0
}

if {$arg(-file) != "" && $arg(f) == ""} {
	set file $arg(-file)
} elseif {$arg(-file) == "" && $arg(f) != ""} {
	set file $arg(f)
} elseif {$arg(-file) != "" && $arg(f) != ""} {
	puts "error: --file & -f option can not be selected together"
	flash_help
	return
} else {
	puts "error: argument for file not found"
	flash_help
	return
}

if {$arg(-port) != "" && $arg(p) == ""} {
	set port $arg(-port)
} elseif {$arg(-port) == "" && $arg(p) != ""} {
	set port $arg(p)
} elseif {$arg(-port) != "" && $arg(p) != ""} {
	puts "error: --port & -p option can not be selected together"
	flash_help
	return
} else {
	set port "port"
	#default value of the port
}

if {$arg(-memory) != "" && $arg(m) == ""} {
	set env1 $arg(-memory)
} elseif {$arg(-memory) == "" && $arg(m) != ""} {
	set env1 $arg(m)
} elseif {$arg(-memory) != "" && $arg(m) != ""} {
	puts "error: --memory & -m option can not be selected together"
	flash_help
	return
} else {
	puts "error: argument for memory not found"
	flash_help
	return
}

if {$arg(-address) != "" && $arg(a) == ""} {
	set address $arg(-address)
} elseif {$arg(-address) == "" && $arg(a) != ""} {
	set address $arg(a)
} elseif {$arg(-address) != "" && $arg(a) != ""} {
	puts "error: --address & -a option can not be selected together"
	flash_help
	return
} else {
	puts "error: argument for address not found"
	flash_help
	return
}

if {$OS == "Windows"} {
	regsub -all {\\} $file {\\\\} file1
	set file $file1
}

if {$argv != "" } {
        puts "error: extra argument found $argv, which is not required"
	flash_help
        return 0
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


if {$port == "port"} {

	if {[catch {get_serial_ports} list_of_ports]} {
		puts "error: no serial port found"
		puts "reset the board and run the connect script"
		return 0
	}
	set port [lindex $list_of_ports end]
}

if {[catch {set fp [open $file]} id]} {
	puts "error: unable to open file $file"
	return 0
}
close $fp

if {[catch {set sp [open $port]} id]} {
	puts "error: unable to open port"
	return 0
}
close $sp

set flashadd $address

if {$env1 == "nor"} {

	set cmd "-f $file"
	set portcmd "-p $port"
	catch {eval exec tclsh send.tcl $cmd $portcmd >@stdout } id
	if {$id == "error" || $id == "0"} {
		return 0
	}
	set filelength [file size $file]
	set align 65536
	set mul [expr double($filelength)/$align]
	set x 1
	while {$mul>1} {
	set mul [expr $mul-1]
	incr x
	}
	set aligned [expr $align*$x]
	set aligned [format "%x" $aligned]
	puts "aligned file length $aligned"

	set cmd "-c \"erase $flashadd +$aligned\""
	catch {eval exec tclsh ucmd.tcl $cmd $portcmd >@stdout } id
	if {$id == "error" || $id == "0"} {
		return 0
	}
	set cmd "-c \"cp.b 0x800000 $flashadd 0x$aligned\" -p $port"
        catch {eval exec tclsh ucmd.tcl $cmd $portcmd >@stdout} id
        if {$id == "error" || $id == "0"} {
                puts "error"
		return 0
        }
} elseif {$env1 == "nand"} {
	set cmd "-f $file"
	set portcmd "-p $port"
        catch {eval exec tclsh send.tcl $cmd $portcmd >@stdout} id
        if {$id == "error" || $id == "0"} {
		return 0
	}
	set filelength [file size $file]
        puts $filelength
	set cmd "-c \"nand info\""
	catch {eval exec tclsh ucmd.tcl $cmd $portcmd} buf
	split $buf " "
	catch {set pos [lsearch $buf "size"]} id
	set val [lindex $buf $pos]
	if {$val == "size"} {
		set pos [expr $pos+1]
		set val [lindex $buf $pos]
	puts "nand sector size: $val"
	} else {
		puts "error: size not found"
		return
	}
	set pos [expr $pos+1]
	set unit [lindex $buf $pos]
	puts "unit of size $unit"
	if {$unit == "KiB"} {
		set align [expr $val*1024]
	} elseif {$unit == "MiB"} {
		set align [expr $val*1024*1024]
	} elseif {$unit == "GiB"} {
		set align [expr $val*1024*1024*1024]
	} else {
		puts "unable to read the size of sector for nand memory"
		puts "sector size assumed 128KiB"
		set align 131072
	}

	set mul [expr double($filelength)/$align]
        set x 1
	while {$mul>1} {
		set mul [expr $mul-1]
		incr x
        }
        set aligned [expr $align*$x]
        set aligned [format "%x" $aligned]
        puts "aligned file length :$aligned"
        set cmd "-c \"nand erase $flashadd  0x$aligned\""
        catch {eval exec tclsh ucmd.tcl $cmd $portcmd >@stdout } id
        if {$id == "error" || $id == "0"} {
		return 0
        }
        set cmd "-c \"nand write.jffs2 0x800000 $flashadd 0x$aligned\""
        catch {eval exec tclsh ucmd.tcl $cmd $portcmd >@stdout } id
        if {$id == "error" || $id == "0"} {
                puts "error"
                return 0
        }
} else {
	puts "error: incorrect env"
	flash_help
	return 0
}
