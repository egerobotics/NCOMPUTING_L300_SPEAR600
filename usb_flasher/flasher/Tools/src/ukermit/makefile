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

# Windows Specific handling
ifdef WINDOWS
EXE_PREFIX=.exe
#Installation System specific
ifndef COMPILER_PREFIX
COMPILER_PREFIX=C:\\Dev-Cpp\\bin\\
endif
ifndef APP_PREFIX
APP_PREFIX=C:\\Dev-Cpp\\bin\\
endif
endif #windows

# Selective Library
ifdef WINDOWS
LIB_FILES=lib/serial_win32.c lib/file_win32.c
else
LIB_FILES=lib/serial_posix.c lib/file_posix.c
endif
LIB_FILES+=lib/f_status.c

#App source code
KERMIT_FILES=src/ukermit.c

# Final output files
KERMIT_EXE=ukermit$(EXE_PREFIX)

# Object Files
KERMIT_OBJ=$(KERMIT_FILES:.c=.o)

LIB_OBJ=$(LIB_FILES:.c=.o)

CLEANUPFILES=$(LIB_OBJ) $(KERMIT_EXE) $(KERMIT_OBJ)

CC=$(COMPILER_PREFIX)gcc
LD=$(COMPILER_PREFIX)gcc
RM=$(APP_PREFIX)rm$(EXE_PREFIX)
ECHO=echo

CFLAGS=-Wall -O3 -Iinclude
LDFLAGS=

CFLAGS+=-fdata-sections -ffunction-sections
LDFLAGS+=--gc-sections --print-gc-sections --stdlib
LDFLAGS_USB=-lusb

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

all: $(KERMIT_EXE)

$(KERMIT_EXE): $(KERMIT_OBJ) $(LIB_OBJ) makefile
	@$(ECHO) "Generating:  $@"
	$(if $(VERBOSE:1=),@)$(LD) $(KERMIT_OBJ) $(LIB_OBJ) $(LDFLAGS) -o $@
	@$(ECHO)

.PHONY : clean
clean:
	@$(ECHO) "Cleaning:"
	$(if $(VERBOSE:1=),@)-$(RM) -$(if $(VERBOSE:1=),,v)f $(CLEANUPFILES) core

