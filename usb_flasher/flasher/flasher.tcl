#!/bin/sh
# the next line restarts using tclsh\
exec tclsh "$0" "$@"
set OS [lindex $tcl_platform(os) 0]

proc help_int {} {
puts "1 \[c\]onnect: connect to a spear device"
puts "2 \[s\]end: send a file to device at a particular memory address"
puts "3 \[f\]lash: flash an image/binary to nor/nand"
puts "4 \[u\]cmd: send a command to device (u-boot) and execute"
puts "5 c\[o\]nfig: print the configuration file of the device"
puts "6 e\[x\]it: exit the interactive mode"
puts "7 \[h\]elp: command help for interactive mode"
puts "for command argument help write flasher>command help Ex flasher>connect help"
return
}


proc help_cmdint {} {
	puts "\nUsage: tclsh flasher.tcl <mode> \[file\] "
	puts "\nmode:"
	puts " -i	interactive mode"
	puts " -f	script mode"
	puts "\nexamples:"
	puts "tclsh flasher.tcl -i			opens interactive mode of the flasher"
	puts "tclsh flasher.tcl -f script.txt		opens script mode of the flasher and read commands from script.txt"
}

proc print_config {v2} {
	if {$v2 == "SPEAr300" || $v2 == "300"} {
	        catch {set fp [open "./Configurations/setup300.ini" r]} id
        } elseif {$v2 == "SPEAr310" || $v2 == "310"} {
                catch {set fp [open "./Configurations/setup310.ini" r]} id
        } elseif {$v2 == "SPEAr320" || $v2 == "320"} {
                catch {set fp [open "./Configurations/setup320.ini" r]} id
        } elseif {$v2 == "SPEAr600" || $v2 == "600"} {
                catch {set fp [open "./Configurations/setup600.ini" r]} id
        } elseif {$v2 == "SPEAr900" || $v2 == "900"} {
                catch {set fp [open "./Configurations/setup900.ini" r]} id
        } elseif {$v2 == "SPEAr1300" || $v2 == "1300"} {
                catch {set fp [open "./Configurations/setup1300.ini" r]} id
        } elseif {$v2 == "SPEAr1310_reva" || $v2 == "1310_reva"} {
                catch {set fp [open "./Configurations/setup1310_reva.ini" r]} id
        } elseif {$v2 == "SPEAr1310" || $v2 == "1310"} {
                catch {set fp [open "./Configurations/setup1310.ini" r]} id
        } elseif {$v2 == "SPEAr1340" || $v2 == "1340"} {
                catch {set fp [open "./Configurations/setup1340.ini" r]} id
        } else {
                puts "not able to read the configuration file"
        }
	set file_data [read $fp]
	puts $file_data
	close $fp
	return
}

proc cmdopt {} {
	puts "Commands:"
	puts "1: \[c\]onnect  2: \[s\]end   3: \[f\]lash  4: \[u\]cmd "
	puts "5: c\[o\]nfig   6: e\[x\]it   7: \[h\]elp "
}

proc remove {id} {
	regsub -all "tclsh" $id "" id1
	regsub -all ".tcl" $id1 "" id2
	set id $id2
	return $id
}
if {$argc == 1} {
        lassign $argv option
        if {$option == "-i"} {
		puts "interactive option"
		while { 1 } {
			puts ""
			cmdopt
			puts " "
			puts -nonewline "flasher> "
			flush stdout
			gets stdin cmdarg
			set pos [string first " " $cmdarg]
			set cmd [string range $cmdarg 0 [expr $pos-"1"] ]
			set arg [string range $cmdarg [expr $pos+"1"] end]
			if {$cmd == ""} {
				set cmd $cmdarg
				set arg ""
			}
			if {$arg != ""} {
				if {$OS == "Windows"} {
					regsub -all {\\} $arg {\\\\} arg1
					set arg $arg1
				}
			}
			if {$cmd == "connect" || $cmd == "c" || $cmd == "1"} {
				catch {eval exec tclsh connect.tcl $arg >@stdout } id
			} elseif {$cmd == "send" || $cmd == "s" || $cmd == "2"} {
				catch {eval exec tclsh send.tcl $arg >@stdout } id
			} elseif {$cmd == "flash" || $cmd == "f" || $cmd == "3"} {
                                catch {eval exec tclsh flash.tcl $arg >@stdout } id
                        } elseif {$cmd == "ucmd" || $cmd == "u" || $cmd == "4"} {
                                catch {eval exec tclsh ucmd.tcl $arg >@stdout} id
                        } elseif {$cmd == "help" || $cmd == "h" || $cmd == "7" } {
				help_int
				continue
			} elseif {$cmd == "exit" || $cmd == "x" || $cmd == "6" } {
                                exit
                        } elseif {$cmd == "config" || $cmd == "o" || $cmd == "5" } {
				set defdev $arg
				if {$defdev == "600" || $defdev == "300" || $defdev == "310" || $defdev == "320" || $defdev == \
				        "1300" || $defdev == "1310_reva" || $defdev == "1310" || $defdev == "900" || $defdev == "1340" || \
				        $defdev == "900"} {
					set defdev "SPEAr$defdev"
				}

				if {$defdev == "SPEAr600" || $defdev == "SPEAr900" || $defdev == "SPEAr310" || \
				        $defdev == "SPEAr300" || $defdev == "SPEAr1300" || $defdev == "SPEAr1340" \
				        || $defdev == "SPEAr1310_reva" || $defdev == "SPEAr1310" || $defdev ==  "SPEAr320"} {
				print_config $defdev
			        } else {
					puts "Usage:"
					puts "flasher> config <device>"
					puts "prints the config file "
				}


                        } elseif {$cmd == ""} {
				continue
			} else {
				puts "Running as u-boot cmd"
				set cmd "-c \"$cmdarg\""
				catch {eval exec tclsh ucmd.tcl $cmd >@stdout } id
			}
		}

	} else {
		help_cmdint
	}
} elseif {$argc == 2} {

	lassign $argv option file
	if {$option == "-f"} {

		if {[catch {set fp [open "$file" r]} id]} {
			puts "error: unable to open file"
			return 0
		}
		set file_data [read $fp]
		close $fp
		set line [split $file_data "\n"]
		foreach inline1 $line {
			puts "\n$inline1"
			set cmdarg $inline1
                        set pos [string first " " $cmdarg]
                        set cmd [string range $cmdarg 0 [expr $pos-"1"] ]
                        set arg [string range $cmdarg [expr $pos+"1"] end]
                        if {$cmd == ""} {
                                set cmd $cmdarg
                                set arg ""
                        }
                        if {$cmd == "connect" || $cmd == "c" || $cmd == "1"} {
                                catch {eval exec tclsh connect.tcl $arg >@stdout } id
                        } elseif {$cmd == "send" || $cmd == "s" || $cmd == "2"} {
                                catch {eval exec tclsh send.tcl $arg >@stdout } id
                        } elseif {$cmd == "flash" || $cmd == "f" || $cmd == "3"} {
                                catch {eval exec tclsh flash.tcl $arg >@stdout } id
                        } elseif {$cmd == "ucmd" || $cmd == "u" || $cmd == "4"} {
                                catch {eval exec tclsh ucmd.tcl $arg >@stdout } id
                        } elseif {$cmd == "exit" || $cmd == "x" || $cmd == "6" } {
                                exit
                        } elseif {$cmd == "config" || $cmd == "o" || $cmd == "5" } {
                                set defdev $arg
                                if {$defdev == "600" || $defdev == "300" || $defdev == "310" || $defdev == "320" || $defdev == \
                                        "1300" || $defdev == "1310_reva" || $defdev == "1310" || $defdev == "900" || $defdev == "1340" || \
                                        $defdev == "900"} {
                                        set defdev "SPEAr$defdev"
                                }

                                if {$defdev == "SPEAr600" || $defdev == "SPEAr900" || $defdev == "SPEAr310" || \
                                        $defdev == "SPEAr300" || $defdev == "SPEAr1300" || $defdev == "SPEAr1340" \
                                        || $defdev == "SPEAr1310_reva" || $defdev == "1310" || $defdev ==  "SPEAr320"} {
                                print_config $defdev
                                } else {
                                        puts "Usage:"
                                        puts "flasher> config <device>"
                                        puts "prints the config file "
                                }


                        } elseif {$cmd == ""} {
                                exit
                        } else {
                                puts "Running as u-boot cmd"
                                set cmd "-c \"$cmdarg\""
                                catch {eval exec tclsh ucmd.tcl $cmd >@stdout } id
                                puts $id
                        }

	}
	} else {
		help_cmdint
	}
} else {
	exec wish flasher-gui.tcl
	exit
	#help_cmdint
}
