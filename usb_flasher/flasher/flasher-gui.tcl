# SPEAr-Utils.tcl --
#

#package require Tcl	8.5
package require Tk	8.5
package require Ttk

wm title . "SPEAr Flashing Utilities ..."
wm resizable . 0 0
################################################################################
################################################################################

set mems {Nor Nand}
set Partitions(Nor) 0
set Partitions(Nand) 0
set ShowParts(Nor) 0
set ShowParts(Nand) 0
set size(Nor) 0x0
set size(Nand) 0x0
set sb(Nor) sector
set sb(Nand) block
set OS [lindex $tcl_platform(os) 0]
######## USB and Kermit Binaries are selected based on the OS platform ###
if {$OS == "Windows"} {
	set KERMIT_TOOL ./Tools/Win/ukermit.exe
	set USB_TOOL ./Tools/Win/usb_send.exe
	set att_opt -disabled
} else {
	set KERMIT_TOOL ./Tools/Linux/ukermit
	set USB_TOOL ./Tools/Linux/usb_send
	set att_opt -topmost
}
###### att_opt is the wm attributes option selected based on the OS ##
set conf_dir Configurations
################################################################################
################################################################################
proc SetupWindow {} {
	global mems size Partitions ShowParts
	global sb

	set partition .partition
	toplevel $partition
	wm title $partition "Setup Memories/Partitions"
	wm resizable $partition 0 0

	set es(Nor) {
		0x0 0x10000 0x40000
	}
	set es(Nand) {
		0x0 0x4000 0x10000 0x20000 0x80000 0x100000 0x200000
	}
	set ShowParts(Nor) 0
	set ShowParts(Nand) 0

	foreach i $mems {
		set f $partition.frame$i
		ttk::frame $f
		pack $f -fill x -expand true

		ttk::labelframe $f.lab -text "Select $sb($i) size (minimum erase size) \
			for $i memory"
		set a $es($i)
		ttk::frame $f.lab.mf
		ttk::combobox $f.lab.mf.box -textvariable size($i) -state readonly -values $a


		ttk::button $f.lab.mf.add -width 15 -text "Add Partition" \
			-command "addPart $f.lab $i new"
		ttk::button $f.lab.mf.del -width 15 -text "Remove Partition" \
			-command "delPart $f.lab $i"

		pack $f.lab -pady 5 -padx 10 -fill x
		pack $f.lab.mf -fill x -expand true
		pack $f.lab.mf.box -side left -pady 5 -padx 10
		pack $f.lab.mf.add -side left -pady 5 -padx 10
		pack $f.lab.mf.del -side left -pady 5 -padx 10

		if {$Partitions($i) > 0} {
			for {set j 1} {$j <= $Partitions($i)} {incr j} {
				addPart $f.lab $i old
			}
		}
	}

	#ttk::labelframe $partition.labf -text "Environment Variables"
	#label $partition.labf.lab -text "Environment variables should be saved in "
	#ttk::combobox $partition.labf.box -textvariable envVar -state readonly \
		-values {NOR NAND} -width 8
	#pack $partition.labf -pady 5 -padx 10 -fill x
	#pack $partition.labf.lab -pady 5 -padx {5m 0} -side left
	#pack $partition.labf.box -pady 5 -padx 10 -side left

	ttk::button $partition.but -width 10 -text "Save" \
		-command "saveSetup $partition"
	pack $partition.but -side right -pady 10 -padx 10
}

proc saveSetup {w} {
	global from len names
	global mems size
	global Partitions ShowParts defdev conf_dir

	set sanity PASS
	if {!$ShowParts(Nor) && !$ShowParts(Nand)} {
		tk_messageBox -message "Either Nand or Nor memory should have\
			at least one partition."\
			-parent $w -icon error -title ERROR -type ok
		set sanity FAIL
	}
	foreach mem $mems {
		set max 0
		for {set i 1} {$i <= $ShowParts($mem)} {incr i} {
			set var [expr $from($mem$i)+$len($mem$i)]
			if {$var > $max} {
				set max $var
			}
		}
		for {set j 0} {$j < $max} {incr j} {
			set check($j) 0
		}
		for {set i 1} {$i <= $ShowParts($mem)} {incr i} {
			if {$sanity == "FAIL"} {
				break
			}
			set j $from($mem$i)
			for {set k 0} {$k < $len($mem$i)} {incr k} {
				if {$check($j) == 1} {
					tk_messageBox -message "Partition \"$names($mem$i)\" in $mem\
						memory overlaps with another partition.\
						\nPlease correct the partition table"\
						-parent $w -icon error -title ERROR -type ok
					set sanity FAIL
					break
				} else {
					set check($j) 1
				}
				incr j
			}
		}
	}

	if {$sanity == "PASS"} {
		if {$defdev == "SPEAr300"} {
			set conf_file ./$conf_dir/setup300.ini
		} elseif {$defdev == "SPEAr310"} {
			set conf_file ./$conf_dir/setup310.ini
		} elseif {$defdev == "SPEAr320"} {
			set conf_file ./$conf_dir/setup320.ini
		} elseif {$defdev == "SPEAr600"} {
			set conf_file ./$conf_dir/setup600.ini
		} elseif {$defdev == "SPEAr1300"} {
			set conf_file ./$conf_dir/setup1300.ini
		} elseif {$defdev == "SPEAr1310_reva"} {
			set conf_file ./$conf_dir/setup1310_reva.ini
		} elseif {$defdev == "SPEAr1310"} {
			set conf_file ./$conf_dir/setup1310.ini
		} elseif {$defdev == "SPEAr900"} {
			set conf_file ./$conf_dir/setup900.ini
		} else {
			set conf_file ./$conf_dir/setup1340.ini
		}
		set conf [open $conf_file w+]
		foreach mem $mems {
			set line "$mem@$size($mem)"
			puts $conf $line
			set Partitions($mem) $ShowParts($mem)
			set p $Partitions($mem)
			set i 0
			while {$i < $p} {
				incr i
				set line "$names($mem$i)@$from($mem$i)@$len($mem$i)"
				puts $conf $line
			}
		}
		close $conf
		destroy $w
	}
}

proc delPart {p mem} {
	global ShowParts
	set i $ShowParts($mem)
	if {$i > 0} {
		set ShowParts($mem) [expr $ShowParts($mem)-1]
		if {$i == 1} {
			$p.mf.box configure -state normal
		}
	}
	destroy $p.$i
}

proc focusAndFlash {W fg bg {count 9}} {
	focus -force $W
	if {$count<1} {
		$W configure -foreground $fg -background $bg
	} else {
		if {$count%2} {
			$W configure -foreground $bg -background $fg
		} else {
			$W configure -foreground $fg -background $bg
		}
		after 200 [list focusAndFlash $W $fg $bg [expr {$count-1}]]
	}
}

proc addPart {p mem n} {
	global size from len names
	global ShowParts sb

	if {$size($mem) == 0x0} {
		tk_messageBox -message "Sector/Block Size not selected yet"\
			-parent .partition -icon error -title ERROR -type ok
	} else {
		$p.mf.box configure -state disabled

		set ShowParts($mem) [expr $ShowParts($mem)+1]
		set i $ShowParts($mem)
		set f [frame $p.$i]
		label $f.lab -text "Partition Name "
		entry $f.name -width 15 -textvariable names($mem$i)
		label $f.fromlab -text "Starts from $sb($mem) no.:"
		entry $f.from -width 5 -textvariable from($mem$i) -validate focus \
			-vcmd {string is integer %P}
		$f.from configure -invalidcommand \
			"focusAndFlash %W [$f.from cget -fg] [$f.from cget -bg]"

		label $f.lenlab -text "Length:"
		entry $f.len -width 5 -textvariable len($mem$i) -validate focus \
			-vcmd {string is integer %P}
		$f.len configure -invalidcommand \
			"focusAndFlash %W [$f.len cget -fg] [$f.len cget -bg]"

		label $f.endlab -text "$sb($mem)s"
		pack $f.lab -side left -padx {5m 0}
		pack $f.name -side left
		pack $f.fromlab -side left -padx {2m 0}
		pack $f.from -side left
		pack $f.lenlab -side left -padx {2m 0}
		pack $f.len -side left
		pack $f.endlab -side left -padx {0 2m}
		pack $f -pady 1m -anchor w

		if {$n == "new"} {
			$f.name delete 0 end
			$f.from delete 0 end
			$f.len delete 0 end
			$f.name insert end "Partition $i"
			if {$i > 1} {
				set a $from($mem[expr $i-1])
				set b $len($mem[expr $i-1])
				$f.from insert end [expr $a + $b]
			} else {
				$f.from insert end 0
			}
			$f.len insert end 1
		}
	}
}

################################################################################
################################################################################
proc device_write {defdev} {
	global conf_dir
	set dev_w [open ./$conf_dir/device.txt w+]
	puts $dev_w "$defdev"
	close $dev_w
}

proc device_read {} {
	global defdev conf_dir
	set dev_r [open ./$conf_dir/device.txt r]
	gets $dev_r line
	set defdev $line
	close $dev_r
	return $defdev
}

proc init {} {
	global defdev
	set conf [open "console.txt" w+]
	close $conf

	conf_read $defdev
}

proc conf_read {defdev} {
	global Partitions size from len names
	global conf_dir opstatus
	if {$defdev == "SPEAr300"} {
		set conf_file ./$conf_dir/setup300.ini
	} elseif {$defdev == "SPEAr310"} {
		set conf_file ./$conf_dir/setup310.ini
	} elseif {$defdev == "SPEAr320"} {
		set conf_file ./$conf_dir/setup320.ini
	} elseif {$defdev == "SPEAr600"} {
		set conf_file ./$conf_dir/setup600.ini
	} elseif {$defdev == "SPEAr1300"} {
		set conf_file ./$conf_dir/setup1300.ini
	} elseif {$defdev == "SPEAr1310_reva"} {
		set conf_file ./$conf_dir/setup1310_reva.ini
	} elseif {$defdev == "SPEAr1310"} {
		set conf_file ./$conf_dir/setup1310.ini
	} elseif {$defdev == "SPEAr900"} {
		set conf_file ./$conf_dir/setup900.ini
	} else {
		set conf_file ./$conf_dir/setup1340.ini
	}
	if {[catch {open $conf_file r} id]} {
		set answer [tk_messageBox -message "Partition setup not done yet. \
			Setup Partitions?" -title Setup -type yesno -icon question]
		switch -- $answer {
			yes SetupWindow
			no exit
		}
	} else {
		set conf [open $conf_file r]
		set contents [read $conf]
		close $conf
		set iNor 0
		set iNand 0

		set lines [split $contents "\n"]
		for {set i 0} {$i < [llength $lines]} {incr i} {
			set line [lindex $lines $i]
			set words [split $line "@"]
			if {[lindex $words 0] == "Nor"} {
				set size(Nor) [lindex $words 1]
				set mem Nor
				continue
			} elseif {[lindex $words 0] == "Nand"} {
				set size(Nand) [lindex $words 1]
				set mem Nand
				continue
			}
			if {[llength $words] == 3} {
				if {$mem == "Nor"} {
					incr iNor
					set names($mem$iNor) [lindex $words 0]
					set from($mem$iNor) [lindex $words 1]
					set len($mem$iNor) [lindex $words 2]
				} elseif {$mem == "Nand"} {
					incr iNand
					set names($mem$iNand) [lindex $words 0]
					set from($mem$iNand) [lindex $words 1]
					set len($mem$iNand) [lindex $words 2]
				}
			}
		}
		set opstatus "Configuration selected for $defdev"
		set Partitions(Nor) $iNor
		set Partitions(Nand) $iNand
	}
}

set menu .menu
set status .statusBar
set opstatus "   "
frame $status
label $status.label -textvariable opstatus -relief sunken -bd 1 -anchor w
pack $status.label -side left -padx 2 -expand yes -fill both
pack $status -side bottom -fill x -pady 2

menu $menu -tearoff 0

set file $menu.file
menu $file -tearoff 0
$menu add cascade -label "File" -menu $file -underline 0
$menu add separator
$file add command -label "Exit" -command "destroy ."

set setup $menu.setup
menu $setup -tearoff 0
$menu add cascade -label "Setup" -menu $setup -underline 0
$setup add command -label "Setup Memories/Partitions" -command "SetupWindow"

set help $menu.help
menu $help -tearoff 0
$menu add cascade -label "Help" -menu $help -underline 0
$help add command -label "About" -command "aboutWindow"

. configure -menu $menu

proc aboutWindow {} {
	set about .about
	toplevel $about
	wm title $about "About Flashing Utils"
	wm resizable $about 0 0

	label $about.lab1 -text "SPEAr USB Flashing Utility" -font 14
	label $about.lab2 -text "Version (2.4)" -font 14
	label $about.lab3 -text "Copyright ST Microelectronics"
	pack $about.lab1 -padx 15m -pady 5m
	pack $about.lab2 -padx 5m -pady {0m 5m}
	pack $about.lab3 -padx 5m -pady {0m 5m}
}

################################################################################
################################################################################
proc connect {} {
	global USB_TOOL display combox defCOM lastenvopt defdev
	global att_opt
	set conf [open "console.txt" w+]
	if [winfo exists $display] {
		$display configure -state normal
		$display delete 1.0 end
		$display configure -state disabled
	}
	close $conf
	wm attributes . $att_opt true
	if {$defdev != ""} {
		if {[catch {exec $USB_TOOL -dev $defdev} id]} {
			tk_messageBox -title "ERROR" -message "Firmware could not be uploaded.\
			Please restart the board and try\
			again."\
			-icon error -type ok
		} else {
			after 5000
			catch {get_serial_ports} coms
			$combox configure -values $coms
			set defCOM [lindex $coms end]
			tk_messageBox -title "Ready to upgrade" -message "Firmware uploaded.\
				Board ready to upgrade flashes."\
				-icon info -type ok
		}
	} else {
		tk_messageBox -title "ERROR" -message "Please select the device before\
			clicking on the connect button."\
			-icon error -type ok
	}
wm attributes . $att_opt false
}

set framec .framec
set frame1 $framec.frame1
set frame2 $framec.frame2

ttk::frame $framec
ttk::frame $frame1
ttk::frame $frame2
pack $frame1 -side left -expand true -fill x
pack $frame2 -side right -expand true -fill x

if {[catch {device_read} defdev]} {
	set defdev "SPEAr300"
}

set sprdevs {
	SPEAr300 SPEAr310 SPEAr320 SPEAr600 SPEAr1300 SPEAr1310_reva SPEAr900 SPEAr1340 SPEAr1310
}

ttk::labelframe $frame1.label -text "Select SPEAr Device"
ttk::combobox $frame1.label.box -textvariable defdev -state readonly \
	-values $sprdevs -width 12
set combox $frame1.label.box

bind $frame1.label.box <<ComboboxSelected>> {
	conf_read $defdev
	device_write $defdev
}

pack $frame1.label -pady 5 -padx 10 -fill x
pack $frame1.label.box -pady 2m -side left -padx 15m

ttk::labelframe $frame2.label -text "Upload Firmware to SPEAr Board"
ttk::button $frame2.label.but -text "Connect" -width 15 -command "connect"

pack $frame2.label -pady 5 -padx 10 -fill x
pack $frame2.label.but -pady 2m -side right -padx 15m
pack $framec -expand true -fill x

#########################################
init
##########################################

################################################################################
################################################################################
proc runscript {} {
	global opstatus eop

	#   Type names        Extension(s)    Mac File Type(s)
	#---------------------------------------------------------
	set types {
		{"All files"        *}
	}

	set file [tk_getOpenFile -initialdir ./Scripts \
		-filetypes $types -typevariable "All Files"]

	if {[string compare $file ""]} {
		if {![catch {set conf [open "$file" r]}]} {
			set contents [read $conf]
			close $conf

			set lines [split $contents "\n"]
			set opstatus "Running Script"
			for {set i 0} {$i < [llength $lines]} {incr i} {
				set line [lindex $lines $i]
				if {[string compare $line ""]} {
					catch {ucmd $line $eop} id
					if {$id == "error"} {
						uerr
						break
					}
				}
			}
			set opstatus "   "
		}
	}
}

set framed .framed
set framed1 $framed.frame1
set framed2 $framed.frame2

ttk::frame $framed
ttk::frame $framed1
ttk::frame $framed2

pack $framed1 -side left -expand true -fill x
pack $framed2 -side right -expand true -fill x

if {$OS == "Windows"} {
	package require registry
}

proc get_serial_ports {} {
	global OS
	if {$OS == "Windows"} {
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

#set COMPorts {
#    COM1 COM2 COM3 COM4 COM5 COM6
#    COM7 COM8 COM9 COM10 COM11 COM12
#}
set defCOM " "
set coms " "
catch {get_serial_ports} coms
set COMPorts $coms

ttk::labelframe $framed1.label -text "Select COM Port"
ttk::combobox $framed1.label.box -textvariable defCOM -state readonly \
	-values $COMPorts -width 12
set combox $framed1.label.box
$combox configure -values $coms
set defCOM [lindex $coms end]

pack $framed1.label -pady 5 -padx 10 -fill x
pack $framed1.label.box -pady 2m -side left -padx 15m

ttk::labelframe $framed2.label -text "Run U-Boot command script"
ttk::button $framed2.label.but -text "Run Script" -width 15 -command "runscript"

pack $framed2.label -pady 5 -padx 10 -fill x
pack $framed2.label.but -pady 2m -side right -padx 15m

pack $framed -expand true -fill x


################################################################################
################################################################################
set upgrade .upgrade

ttk::frame $upgrade
pack $upgrade -fill x -expand true

ttk::labelframe $upgrade.label -text "Upgrade Flashes"
ttk::button $upgrade.label.erase -text "Erase" -width 15 -command "EraseWindow"
ttk::button $upgrade.label.program -text "Program" -width 15 -command "ProgramWindow"

pack $upgrade.label -pady 5 -padx 10 -fill x
pack $upgrade.label.erase -side left -padx 15m -pady 2m
pack $upgrade.label.program -side right -padx 15m -pady 2m

################################################################################
################################################################################
set eop "u-boot> "
set checkcmdlist [list]
lappend checkcmdlist "bootm"
lappend checkcmdlist "reset"

proc runCmd {} {
	global command eop checkcmdlist opstatus att_opt

	set endstr $eop
	wm attributes . $att_opt true
	set cmd $command
	if {$cmd == ""} {
		tk_messageBox -message "Enter the command before pressing Run."\
			-icon warning -title Run -type ok
	} else {
		set command ""
		set checkcmd [string range $cmd 0 [expr [string first " " $cmd] - 1]]
		if {$checkcmd == ""} {
			set checkcmd $cmd
		}
		for {set i 0} {$i < [llength $checkcmdlist]} {incr i} {
			if {$checkcmd == [lindex $checkcmdlist $i]} {
				set endstr " "
				break
			}
		}
		set opstatus "Running user command"
		catch {ucmd $cmd $endstr} id
		if {$id == "error"} {
			uerr
		}
		set opstatus "   "
	}
	wm attributes . $att_opt false
}

	################################################################################
	################################################################################
set frame2 .frame2

ttk::frame $frame2
pack $frame2 -fill x -expand true
set command ""
ttk::labelframe $frame2.label -text "Run U-Boot Command"
ttk::combobox $frame2.label.box -textvariable command -width 60
ttk::button $frame2.label.button -text "Run" -width 10 -command "runCmd"
bind $frame2.label.box <Return> {
	if {[%W get] ni [%W cget -values]} {
		%W configure -values [concat [%W cget -values] [list [%W get]]]
	}
	runCmd
}

pack $frame2.label -pady 5 -padx 10 -fill x
pack $frame2.label.box -side left -fill both -padx 2m -pady 2m
pack $frame2.label.button -side left -fill y -padx 10 -pady 2m

################################################################################
################################################################################
set expand .expand
ttk::button $expand -text ">>" -width 5 -command "displayWindow"

pack $expand -padx 2m -pady 2m
set dispframe .displayframe
set display $dispframe.text

proc displayWindow {} {
	global dispframe display
	set scrolly $dispframe.scrolly
	set scrollx $dispframe.scrollx
	set expand .expand

	if {[winfo exists $dispframe]} {
		destroy $dispframe
		destroy $expand
		ttk::button $expand -text ">>" -width 5 -command "displayWindow"
		pack $expand -padx 2m -pady 2m
	} else {
		destroy $expand
		ttk::button $expand -text "<<" -width 5 -command "displayWindow"
		pack $expand -padx 2m -pady 2m

		frame $dispframe -highlightthickness 1 -borderwidth 1 -relief sunken

		text $display -yscrollcommand "$scrolly set" -highlightthickness 10 \
			-xscrollcommand "$scrollx set" -wrap none\
			-borderwidth 1 -relief sunken -bg grey \
			-width [winfo width $dispframe] -height 20 -state disabled

		scrollbar $scrolly -command "$display yview"
		scrollbar $scrollx -orient horiz -command "$display xview"
		pack $scrolly -side right -fill y
		pack $scrollx -side bottom -fill x

		updatedisplayfromfile
		pack $display -fill both
		pack $dispframe -fill both
	}
}

################################################################################
################################################################################
proc EraseWindow {} {
	global mems Partitions names erase
	set erasew .erase
	toplevel $erasew
	wm title $erasew "Erase Partitions"
	wm resizable $erasew 0 0

	set f [frame $erasew.frame]
	pack $f -pady 5 -padx 5 -expand true -fill both

	foreach i $mems {
		ttk::frame $f.frame$i
		pack $f.frame$i -side left -padx 2m -pady 2m -fill both

		set frame $f.frame$i
		set label $frame.label
		ttk::labelframe $label
		checkbutton $label.cb -text "Select $i partitions to erase" \
			-variable eraseall($i) -command "EraseAllPart $i" \
			-onvalue "on" -offvalue "off"

		$label configure -labelwidget $label.cb
		pack $label -pady 2 -padx 2 -fill both -expand true
		for { set j 1 } { $j <= $Partitions($i) } { incr j } {
			checkbutton $label.b$j -text "$names($i$j)" -variable erase($i$j) \
				-onvalue "on" -offvalue "off" -command "ErasePart"
			pack $label.b$j -pady 1 -padx 5m -anchor nw
			set erase($i$j) off
		}
		pack $label -side left -fill both -expand true
	}

	set eraseb $erasew.button
	ttk::button $eraseb -text "Erase" -width 10 -command "EraseSec $erasew"

	pack $eraseb -side right -padx 5m -pady {0 2m}
}

proc EraseAllPart {mem} {
	global erase eraseall
	global mems Partitions

	if {$eraseall($mem) == "on"} {
		for { set j 1 } { $j <= $Partitions($mem) } { incr j } {
			set erase($mem$j) "on"
		}
	}
}

proc ErasePart {} {
	global erase eraseall
	global mems Partitions

	foreach i $mems {
		for { set j 1 } { $j <= $Partitions($i) } { incr j } {
			if { $erase($i$j) == "off" } {
				set eraseall($i) "off"
			}
		}
	}
}

proc EraseSec {p} {
	global Partitions eop names att_opt
	global erase from len size eraseall opstatus
	destroy $p
	set id ok
	wm attributes . $att_opt true
	for {set i 1} {$i <= $Partitions(Nor)} {incr i} {
		if {$erase(Nor$i) == "on"} {
			set eraseall(Nor) off
			set erase(Nor$i) off

			set cmd "erase 1:$from(Nor$i)-[expr $from(Nor$i) + $len(Nor$i) - 1]"
			set opstatus "Erasing Nor Partition \"$names(Nor$i)\""
			catch {ucmd $cmd $eop} id
			if {$id == "error"} {
				break
			}
		}
	}
	for {set i 1} {$i <= $Partitions(Nand)} {incr i} {
		if {$erase(Nand$i) == "on"} {
			set eraseall(Nand) off
			set erase(Nand$i) off
			set fromadd [expr $from(Nand$i) * $size(Nand)]
			set fromadd [format "%x" $fromadd]
			set length [expr $len(Nand$i) * $size(Nand)]
			set length [format "%x" $length]

			set cmd "nand erase 0x$fromadd 0x$length"
			set opstatus "Erasing Nand Partition \"$names(Nand$i)\""
			catch {ucmd $cmd $eop} id
			if {$id == "error"} {
				break
			}
		}
	}
	if {$id == "error"} {
		uerr
	} else {
		tk_messageBox -message "Erasing operation complete."\
			-icon info -title "Erase" -type ok
	}
	set opstatus "   "
	wm attributes . $att_opt false
}

proc uerr {} {
	global defCOM
	tk_messageBox -message "Unable to transmit or recieve on $defCOM.\
		Select the correct COM Port.\
		\nOR Try powering on the board and reconnecting"\
		-icon error -title "COM Port Error" -type ok
}

		################################################################################
		################################################################################

proc send_expect {fh outstr regexp seconds} {
	global send_exp

	# make sure global vars are initialized properly
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
proc ucmd {cmd end} {
	global defCOM inucmd OS
	set timeout 180
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
		updatedisplay $buf
		set out [open "console.txt" a+]
		puts -nonewline $out "$buf"
		close $out
	} else {
		tk_messageBox -message "Command timed out. Reset the board\
			and try the operations again."\
			-icon error -title "COM Port Error" -type ok
	}
	send_exp_end $fh
	close $fh
	set inucmd 0
}

set inukermit 0
proc ukermit {file} {
	global inukermit defCOM eop KERMIT_TOOL
	set ret ok
	while {$inukermit} {}
	set inukermit 1
	catch {ucmd "loadb 0x800000" "..."} id
	if {$id == "error"} {
		set inukermit 0
		return error
	}

	#set console [open "|ukermit.exe -p $defCOM -f {$file}" r]
	#while {![eof $console]} {
	#gets $console line
	#}
	#close $console
	set fname [string range $file [expr [string last / $file] + 1] end]
	if {[catch {exec $KERMIT_TOOL -p $defCOM -f $file} err]} {
		tk_messageBox -message "Error while sending \"$file\"."\
			-icon error -title "ERROR" -type ok
	}

	catch {ucmd " " "$eop"} id
	if {$id == "error"} {
		set inukermit 0
		return error
	}
	set inukermit 0
	return ok
}

proc updatedisplay {char} {
	global display
	if [winfo exists $display] {
		$display configure -state normal
		$display insert end $char
		$display yview end
		$display xview moveto 0
		$display configure -state disabled
		update
	}
}

proc updatedisplayfromfile {} {
	global display
	if [winfo exists $display] {
		set file [open "console.txt" r]
		$display configure -state normal
		$display delete 1.0 end
		gets $file line
		$display insert 1.0 $line

		while {![eof $file]} {
			gets $file line
			$display insert end $line\n
		}
		close $file
		$display yview end
		$display configure -state disabled
	}
}
################################################################################
################################################################################
proc loadConf {file p} {
	global image prog rootfs

	if {![catch {set conf [open "$file" r]}]} {
		set contents [read $conf]
		close $conf
		set iNor 1
		set iNand 1

		set lines [split $contents "\n"]
		for {set i 0} {$i < [llength $lines]} {incr i} {
			set line [lindex $lines $i]
			set words [split $line "@"]
			if {[lindex $words 0] == "Nor"} {
				set prog(Nor$iNor) [lindex $words 1]
				set image(Nor$iNor) [lindex $words 2]
				incr iNor
			} elseif {[lindex $words 0] == "Nand"} {
				set prog(Nand$iNand) [lindex $words 1]
				set rootfs(Nand$iNand) [lindex $words 2]
				set image(Nand$iNand) [lindex $words 3]
				incr iNand
			}
		}
		ProgPart $p
	}
}

proc ProgramWindow {} {
	global mems Partitions image prog names progall rootfs
	set program .program
	toplevel $program
	wm title $program "Program Partitions with Binaries"
	wm resizable $program 0 0

	foreach i $mems {
		ttk::frame $program.frame$i
		pack $program.frame$i -padx 2m -pady 2m -fill x -expand true

		set frame $program.frame$i
		set label $frame.label
		ttk::labelframe $label
		checkbutton $label.cb -text "Select $i partitions to program and Images for partitions" \
			-variable progall($i) -command "ProgAllPart $program $i" \
			-onvalue "on" -offvalue "off"
		set progall($i) off

		$label configure -labelwidget $label.cb
		pack $label -pady 5 -padx 10 -fill x -expand true

		set filesys {JFFS2 YAFFS2}
		for { set j 1 } { $j <= $Partitions($i) } { incr j } {
			set f [frame $label.$j]
			checkbutton $f.cb -variable prog($i$j) -command "ProgPart $program" \
				-onvalue "on" -offvalue "off"
			set prog($i$j) off
			label $f.lab -text "$names($i$j): "
			if {$i == "Nand"} {
				set rootfs($i$j) JFFS2
				ttk::combobox $f.fs -textvariable rootfs($i$j) \
					-values $filesys -width 6 -state disabled
			}
			entry $f.ent -width 35 -state disabled -textvariable image($i$j)
			set image($i$j) ""
			button $f.but -text "Browse"  -width 10 -command "fileDialog $f $f.ent" \
				-state disabled
			pack $f.cb -side left
			pack $f.lab -side left
			pack $f.but -side right -padx 2m
			pack $f.ent -side right -padx 5m
			if {$i == "Nand"} {
				pack $f.fs -side right
			}
			pack $f -fill x -padx 5m -pady 3
		}
	}

	set save $program.save
	ttk::button $save -text "Save Configuration" -width 20 \
		-command "fileSaveDialog $f"
	pack $save -padx 10m -pady 5m -side left

	set load $program.load
	ttk::button $load -text "Load Configuration" -width 20 \
		-command "fileLoadDialog $f $program"
	pack $load -padx 12m -pady 5m -side left

	set flash $program.flash
	ttk::button $flash -text "Program Binaries" -width 20 \
		-command "flashImages $f $program"
	pack $flash -padx 10m -pady 5m -side right

	set f "./Configurations/defConf.conf"
	loadConf $f $program
}

proc flashImages {f w} {
	global Partitions image eop defdev att_opt
	global prog from len size names rootfs opstatus
	set id "nosel"

	destroy $w

	switch -regexp --$defdev {
		SPEAr900 {
			set norbase 0xe6000000
		}
		SPEAr1300 {
			set norbase 0xe6000000
		}
		SPEAr1310_reva {
			set norbase 0xe6000000
		}
		SPEAr1310 {
			set norbase 0xe6000000
		}
		SPEAr1340 {
			set norbase 0xe6000000
		}
		default {
			set norbase 0xf8000000
		}
	}

	wm attributes . $att_opt true
	for {set i 1} {$i <= $Partitions(Nor)} {incr i} {
		if {$prog(Nor$i) == "on"} {
			set fromadd [expr $from(Nor$i) * $size(Nor)]
			set fromadd [expr $fromadd + $norbase]
			set fromadd [format "%x" $fromadd]
			set length [expr $len(Nor$i) * $size(Nor)]

			if {[catch {set o [open $image(Nor$i) r]} id]} {
				tk_messageBox -message "File $image(Nor$i) does not exist for\
					\"$names(Nor$i)\" partition in NOR memory"\
					-icon error -title "Flash Images" -type ok
			} else {
				close $o
				set filelength [file size $image(Nor$i)]
				if {$length >= $filelength} {
					set filelength [format "%x" $filelength]
					set fname [string range $image(Nor$i) [expr [string last / $image(Nor$i)] + 1] end]
					set opstatus "Uploading file \"$fname\""
					catch {ukermit $image(Nor$i)} id
					if {$id == "error"} {
						break
					}
					set opstatus "Erasing Nor Partition \"$names(Nor$i)\""
					set cmd "erase 1:$from(Nor$i)-[expr $from(Nor$i) + $len(Nor$i) - 1]"
					catch {ucmd $cmd $eop} id
					if {$id == "error"} {
						break
					}
					set opstatus "Flashing Nor Partition \"$names(Nor$i)\" with \"$fname\""
						set cmd "cp.b 0x800000 0x$fromadd 0x$filelength"
					catch {ucmd $cmd $eop} id
					if {$id == "error"} {
						break
					}
				} else {
					tk_messageBox -message "File is larger than the partion size for\
						\"$names(Nor$i)\" partition in NOR memory.\
						\nPlease select another file or increase\
						partition length.\nContinuing to flash\
						other partitions"\
						-icon warning -title "Flash Images" -type ok
				}
			}
		}
	}

	for {set i 1} {$i <= $Partitions(Nand)} {incr i} {
		if {$prog(Nand$i) == "on"} {
			set fromadd [expr $from(Nand$i) * $size(Nand)]
			set fromadd [format "%x" $fromadd]
			set length [expr $len(Nand$i) * $size(Nand)]

			if {[catch {set o [open $image(Nand$i) r]} id]} {
				tk_messageBox -message "File $image(Nand$i) does not exist for\
					\"$names(Nand$i)\" partition in NAND memory"\
					-icon error -title "Flash Images" -type ok
			} else {
				close $o
				set filelength [file size $image(Nand$i)]
				if {$length >= $filelength} {
					set length [format "%x" $length]
					if {$size(Nand) == "0x4000"} {
						set align 512
					} elseif {$size(Nand) == "0x10000"} {
						set align 2048
					} elseif {$size(Nand) == "0x20000"} {
						set align 2048
					} else {
						set align 4096
					}
					set alignlen [expr [expr [expr $filelength + [expr $align - 1]] / $align] * $align]
					set alignlen [format "%x" $alignlen]
					set fname [string range $image(Nand$i) [expr [string last / $image(Nand$i)] + 1] end]
					set opstatus "Uploading file \"$fname\""
					catch {ukermit $image(Nand$i)} id
					if {$id == "error"} {
						break
					}
					set opstatus "Erasing Nand Partition \"$names(Nand$i)\""
					set cmd "nand erase 0x$fromadd 0x$length"
					catch {ucmd $cmd $eop} id
					if {$id == "error"} {
						break
					}

					set opstatus "Flashing Nand Partition \"$names(Nand$i)\" with \"$fname\""
					if {$rootfs(Nand$i) == "YAFFS2"} {
						set cmd "nand write.yaffs2 0x800000 0x$fromadd 0x$alignlen"
					} else {
						set cmd "nand write.jffs2 0x800000 0x$fromadd 0x$alignlen"
					}
					catch {ucmd $cmd $eop} id
					if {$id == "error"} {
					break
					}
				} else {
					tk_messageBox -message "File is larger than the partion size for\
						\"$names(Nand$i)\" partition in NAND memory.\
						\nPlease select another file or increase\
						partition length.\nContinuing to flash\
						other partitions"\
						-icon warning -title "Flash Images" -type ok
				}
			}
		}
	}
	if {$id == "nosel"} {
		tk_messageBox -message "No selection made."
	} elseif {$id == "error"} {
		uerr
	} else {
		set cmd "imls"
		ucmd $cmd $eop
		tk_messageBox -message "Flashing operation complete."\
			-icon info -title "Program" -type ok
	}
	set opstatus "   "
	wm attributes . $att_opt false
}

proc ProgAllPart {w mem} {
	global prog progall
	global mems Partitions

	if {$progall($mem) == "on"} {
		for { set j 1 } { $j <= $Partitions($mem) } { incr j } {
			set prog($mem$j) "on"
		}
	}
	ProgPart $w
}

proc ProgPart {w} {
	global prog progall rootfs
	global mems Partitions image

	foreach i $mems {
		set lab $w.frame$i.label
		for { set j 1 } { $j <= $Partitions($i) } { incr j } {
			if { $prog($i$j) == "off" } {
				set progall($i) "off"
				set image($i$j) ""
				if {$i == "Nand"} {
					$lab.$j.fs configure -state disabled
					set rootfs($i$j) JFFS2
				}
				$lab.$j.ent configure -state disabled
				$lab.$j.but configure -state disabled
			} else {
				if {$i == "Nand"} {
					$lab.$j.fs configure -state readonly
				}
				$lab.$j.ent configure -state normal
				$lab.$j.but configure -state normal
			}
		}
	}
}

set browsepath ./Binaries
proc fileDialog {w ent} {
	global browsepath

	#   Type names        Extension(s)    Mac File Type(s)
	#---------------------------------------------------------
	set types {
		{"All Files"           *                        }
		{"Bianry Files"        {.bin .uimg .img}        }
	}

	set file [tk_getOpenFile -initialdir $browsepath\
		-filetypes $types -parent $w \
		-typevariable "All Files"]
	if {[string compare $file ""]} {
		set browsepath [string range $file 0 [expr [string last / $file] - 1]]
		$ent delete 0 end
		$ent insert 0 $file
		$ent xview end
	}
}

proc fileSaveDialog {w} {
	#   Type names        Extension(s)    Mac File Type(s)
	#---------------------------------------------------------
	set types {
	{"Conf Files"        {.conf}}
	{"All files"        *}
	}
	global mems image Partitions prog rootfs

	set file [tk_getSaveFile -initialdir ./Configurations \
		-filetypes $types -parent $w -defaultextension conf\
		-typevariable "Conf Files"]

	if {[string compare $file ""]} {
		set conf [open $file w+]
		foreach mem $mems {
			for {set j 1} {$j <= $Partitions($mem)} {incr j} {
				if {$mem == "Nor"} {
					set line "$mem@$prog($mem$j)@$image($mem$j)"
				} else {
					set line "$mem@$prog($mem$j)@$rootfs($mem$j)@$image($mem$j)"
				}
				puts $conf $line
			}
		}
		close $conf
	}
}

proc fileLoadDialog {w p} {
	#   Type names        Extension(s)    Mac File Type(s)
	#---------------------------------------------------------
	set types {
	{"Conf Files"        {.conf}}
	{"All files"        *}
	}

	set file [tk_getOpenFile -initialdir ./Configurations \
		-filetypes $types -parent $w \
		-typevariable "Conf Files"]

	if {[string compare $file ""]} {
		loadConf $file $p
	}
}

################################################################################
################################################################################
