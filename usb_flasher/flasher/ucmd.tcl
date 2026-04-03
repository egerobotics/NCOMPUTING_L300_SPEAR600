#!/bin/sh
# the next line restarts using tclsh\
exec tclsh "$0" "$@"

package require cmdline
################################################################################

set OS [lindex $tcl_platform(os) 0]

################################################################################




proc ucmd_help {} {
	puts "\nUsage(Command Line):tclsh ucmd.tcl \[option\] -c/--command <command>"
	puts "\nUsage(flasher):ucmd/u/4 \[option\] -c/--command <command>"
	puts "runs the u-boot command"
	puts "\noptions: "
	puts "-p/--port:"
	puts "serial port to run u-boot commands"
	puts "/dev/ttyACMxx:    ACM port (for linux)"
	puts "COMx              COM port (for Windows)"
	puts "-e/--end:"
	puts "to indicate expect string, which is optional. Its default value is \"u-boot>\""
	puts "\n-c/--command:"
	puts "for command help : tclsh ucmd.tcl -cmd ?"
	puts "\nexample"
	puts "(Command line)tclsh ucmd.tcl -p /dev/ttyACM -c imi -e \"u-boot>\""
	puts "(flasher) ucmd -c \"erase all\""
	return
}

###############################################################################




################################################################################





set parameters {
	{p.arg "" "port: COMx for windows /dev/ttyACMx for Linux , which is optio nal"}
	{c.arg "" "command: command to execute on u-boot"}
	{e.arg "" "end: expect string , which is optional"}
	{-port.arg "" "port: COMx for windows /dev/ttyACMx for Linux, which is optional"}
	{-command.arg "" "command: command to execute on u-boot"}
	{-end.arg "" "end: expect string , which is optional"}
}
if {[catch {array set arg [cmdline::getoptions argv $parameters]} id]} {
        ucmd_help
	return 0
}

if {$arg(-command) !="" && $arg(c) == ""} {
	set cmd $arg(-command)
} elseif {$arg(-command) == "" && $arg(c) != ""} {
	set cmd $arg(c)
} elseif {$arg(-command) != "" && $arg(c) != ""} {
	puts "error: --command and -c option can not be used to together"
	ucmd_help
	return
} else {
	puts "error: command argument not found"
	ucmd_help
	return
}

if {$arg(-port) != "" && $arg(p) == ""} {
	set port $arg(-port)
} elseif {$arg(-port) == "" && $arg(p) != ""} {
	set port $arg(p)
} elseif {$arg(-port) != "" && $arg(p) != ""} {
	puts "error: --port and -p option can not be used together"
	ucmd_help
	return
} else {
	set port "port"
	#default value of the port
}

if {$arg(-end) != "" && $arg(e) == ""} {
	set end $arg(-end)
} elseif {$arg(-end) == "" && $arg(e) != ""} {
	set end $arg(e)
} elseif {$arg(-end) != "" && $arg(e) != ""} {
	puts "error: --end and -e option can not be used together"
	ucmd_help
	return
} else {
	set end "u-boot>"
	#default value of the end
}

if {$argv != "" } {
        puts "error: extra argument found $argv, which is not required"
        ucmd_help
	return 0
}

if {$cmd == ""} {
	puts "error: command not entered"
	ucmd_help
	return
}


################################################################################
################################################################################


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

###############################################################################


################################################################################
################################################################################





################################################################################
################################################################################


proc send_expect {fh outstr regexp seconds} {
	global send_exp

	set send_exp($fh.matched)        0
	if {![info exists send_exp($fh.buffer)]} {
		set send_exp($fh.buffer) {}
	}

	# set up our Read handler before outputting the string.
	if {![info exists send_exp($fh.setReader)]} {
	fileevent $fh readable [list private_send_exp_reader \
		$fh $regexp]
	set send_exp($fh.setReader) 1
	}

	# output the string to send
	puts -nonewline $fh $outstr
	flush $fh

	# set up a timer so that we wait a limited amt of seconds
	set afterId [after [expr {$seconds*1000}] \
	[list set send_exp($fh.matched) 0]]
	vwait send_exp($fh.matched)
	set matched $send_exp($fh.matched)
	unset send_exp($fh.matched)
	catch [list after cancel $afterId]

	# If we got an eof, then throw an error
	if {$matched < 0} {
	error "Channel EOF while waiting for data"
	return 0
	}
	return $matched
}

#
# PRIVATE channel read event handler for send_expect.  Should
# not be called by user.
#
proc private_send_exp_reader {fh regexp} {
	global send_exp

	if {[eof $fh]} {
		close $fh
		set send_exp($fh.matched) -1
		return
	}
	append send_exp($fh.buffer) [read $fh]
	if {[regexp $regexp $send_exp($fh.buffer)]} {
		set send_exp($fh.matched) 1
	}
}

#
# Return the current contents of the send_expect buffer
#
# @param fh
#        channel identifier that was used with send_expect
#
# @returns string
#        the current contents of the buffer for the channel
#
proc send_exp_getbuf {fh} {
	global send_exp
	return $send_exp($fh.buffer)
}

#
# Reset the send_expect buffer, returning its contents
#
# @param fh
#        channel identifier that was used with send_expect
#
# @returns string
#        the current contents of the buffer for the channel
#
proc send_exp_resetbuf {fh} {
	global send_exp

	set buf $send_exp($fh.buffer)
	set send_exp($fh.buffer) {}
	return $buf
}

#
# Close out a send_expect session, closing I/O event handler
#
# @param fh
#        channel identifier that was used with send_expect
#
# @returns
#        the channel identifier passed as the fh parameter
#
proc send_exp_end {fh} {
	global send_exp

	fileevent $fh readable {}
	foreach v [array names send_exp $fh.*] {
		catch [list unset send_exp($v)]
	}
	return $fh
}

set inucmd 0
proc ucmd {defCOM cmd end} {
	global inucmd OS
	set timeout 180
	#puts $defCOM
	while {$inucmd} {}
	set inucmd 1
	if {$OS == "Windows"} {
		if {[catch {set fh [open "\\\\.\\$defCOM" RDWR]}]} {
			set inucmd 0
			return error
		}
	} else {
		if {[catch {set fh [open $defCOM RDWR]}]} {
			set inucmd 0
			return error
		}
	}
	catch {fconfigure $fh -blocking 0 -buffering none\
	-mode 115200,n,8,1 -translation binary -eofchar ""}

	if {$cmd != ""} {
		set cmd "$cmd\r"
		if {[send_expect $fh " \r" "$end" 3]} {
			if {$OS == "Windows"} {
				regsub -all "\n\n" [send_exp_getbuf $fh] "\n" buf
			} else {
				regsub -all "\n\r" [send_exp_getbuf $fh] "\n" buf
			}
			#updatedisplay $buf
			#set out [open "console.txt" a+]
			#puts -nonewline $out "$buf"
			#close $out
		} else {
			set inucmd 0
			send_exp_end $fh
			close $fh
			return error
		}
		send_exp_end $fh
	}

	if {[send_expect $fh "$cmd" "$end" $timeout]} {
		if {$OS == "Windows"} {
			regsub -all "\n\n" [send_exp_getbuf $fh] "\n" buf
		} else {
			regsub -all "\n\r" [send_exp_getbuf $fh] "\n" buf
		}
		#updatedisplay $buf
		set out [open "console.txt" a+]
		puts -nonewline $out "$buf"
		puts $buf
		close $out
	} else {
		puts "Command timed out. Reset the board and try the operations again."
	}
	send_exp_end $fh
	close $fh
	set inucmd 0
#	puts "reach at the end of ucmd"
return $buf
}



################################################################################
################################################################################

if {$port == "port"} {
	if {[catch {get_serial_ports} list_of_ports]} {
		puts "error: No serial port found"
		puts "first run the connect script"
		return 0
	}
	set port [lindex $list_of_ports end]
}


proc main_ucmd {port cmd end} {
        if {[catch {set sp [open $port]} id]} {
                puts "error: unable to open port"
                return 0
        }
	close $sp
	puts "Port : $port"
	set defCOM $port
	catch {ucmd $defCOM $cmd $end} id
		if {$id == "error"} {
			puts "error"
			return error
		}
	return $id

}

main_ucmd $port $cmd $end
################################################################################
################################################################################
