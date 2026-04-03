#
# Make file for compiling host app
#
# (C) Copyright 2008
# Texas Instruments, <www.ti.com>
# Nishanth Menon <nm@ti.com>
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the
# Free Software Foundation version 2.
#
# This program is distributed .as is. WITHOUT ANY WARRANTY of any kind,
# whether express or implied; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston,
# MA 02111-1307 USA

srctree := $(if $(SRC),$(SRC),$(CURDIR))

ifdef WINDOWS
EXE_PREFIX=.exe
#Installation System specific
ifndef COMPILER_PREFIX
COMPILER_PREFIX=C:\\Dev-Cpp\\bin\\
endif
ifndef APP_PREFIX
APP_PREFIX=C:\\Dev-Cpp\\bin\\
endif
endif	

#App source code
USBSEND_FILES=src/main.c

# Final output files
USBSEND_EXE=usb_send$(EXE_PREFIX)

# Object Files
USBSEND_OBJ=$(USBSEND_FILES:.c=.o)

CLEANUPFILES=$(USBSEND_EXE) $(USBSEND_OBJ)

CC=$(COMPILER_PREFIX)gcc
LD=$(COMPILER_PREFIX)gcc
RM=rm
ECHO=echo

ifdef WINDOWS
CFLAGS=-Wall -O3 -I.\include\Win 
LDFLAGS= -L.\lib\Win

else

CFLAGS=-Wall -O3 -I./include/Linux
LDFLAGS= -L./lib/Linux
endif

CFLAGS+=-fdata-sections -ffunction-sections
LDFLAGS+=--gc-sections --print-gc-sections --stdlib
LDFLAGS+=-lusb -L.

ifdef V
    VERBOSE = $(V)
endif
ifndef VERBOSE
  VERBOSE = 0
endif

%.o: %.c
	@$(ECHO) "Compiling: " $<
	$(if $(VERBOSE:1=),@)$(CC) $(CFLAGS) -o $@ -c $<

.PHONY : all

all: $(USBSEND_EXE)

$(USBSEND_EXE): $(USBSEND_OBJ) makefile
	@$(ECHO) "Generating:  $@"
	$(if $(VERBOSE:1=),@)$(LD) $(USBSEND_OBJ) $(LDFLAGS) -o $@
	@$(ECHO)

#.PHONY : clean
clean:
	@$(ECHO) "Cleaning:"
	$(if $(VERBOSE:1=),@)-$(RM) -$(if $(VERBOSE:1=),,v)f $(CLEANUPFILES) core
