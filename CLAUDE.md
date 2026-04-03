# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Embedded Linux workspace for the **nComputing L300** thin client board based on the **STMicroelectronics SPEAr600** ARM SoC (ARM926EJ-S, ARMv5TEJ). The board has 128MB DDR2 RAM, 128MB NAND flash, VGA framebuffer (1024x768x24), ethernet (RTL8201CL PHY), and USB host.

## Working System

The board runs **Linux 2.6.19.2** (original nComputing BSP kernel) with a modified initramfs. Modern kernels (5.4, 6.19) boot but have an unresolvable stmmac/DWMAC1000 DMA reset issue that prevents ethernet TX.

**Access:** SSH/telnet to `root@192.168.1.200` (password: `root`). Board gets IP via DHCP (typically 192.168.1.201).

**Current initramfs includes:**
- `fbterm` — framebuffer terminal (draws directly to /dev/fb0, green-on-black, 128x48 chars)
- `fbvnc_server` — VNC server on port 5900 with keyboard input via FIFO `/tmp/vnc_kbd`
- Network auto-config with fixed MAC `00:1A:2B:3C:4D:5E`
- Dropbear SSH + telnetd

## NAND Flash Layout

| Offset | File | Description |
|--------|------|-------------|
| 0x00000000 | xloader_image.bin | DDR init, loaded by BootROM (5436 bytes, uImage header) |
| 0x00080000 | l300_fwd_mod.fwd | Binary boot config (console=ttyS0, kernel/rootfs sizes) |
| 0x000E0000 | u-boot.img | nComputing U-Boot 1.2.2 (208KB, uImage header) |
| 0x001A0000 | uImage | Kernel (1.6MB, 0x1913e0) |
| 0x00600000 | l300_initramfs_mod.gz | cpio+gzip rootfs (~11.6MB, 0xb158d8) |

## Critical Hardware Facts

- **Console is `ttyS0`**, not `ttyAMA0`. The SPEAr UART driver uses a different name than PL011.
- **I2C EEPROM is missing** — MAC address reads as `ff:ff:ff:ff:ff:ff`. Must be fixed at boot via `ip link set eth0 address 00:1A:2B:3C:4D:5E`.
- **BootROM reads NAND with its own ECC** — data written by the old U-Boot's `nand write.jffs2` command is compatible. Linux `nandwrite` and `nandwrite --noecc` do NOT produce BootROM-compatible data.
- **FWD file controls boot** — U-Boot reads boot parameters from the FWD binary at 0x80000, not from `saveenv`. FWD binary structure: offset 0x20=console string, 0x4C=kernel_size (u32 LE), 0x54=rootfs_size (u32 LE).
- **FWD auto-boot works** — The `boot` command runs FWD-based bootsteps which include mtdparts. Board boots automatically on power-up.
- **mtdparts is CRITICAL in bootargs** — Without mtdparts, the kernel uses a built-in partition table where mtdblock2 overlaps the initramfs area (0x600000). Mounting jffs2 on mtdblock2 erases the initramfs from NAND. Always include mtdparts when booting manually.
- **saveenv is dangerous** — May write to NAND areas overlapping kernel/rootfs. Avoid using it.
- **OABI only** — kernel 2.6.19 does not have `CONFIG_AEABI`. All userspace binaries must be GNU EABI (OABI), ELF flags `0x602`. EABI5 binaries cause `Illegal instruction`.
- **network_daemon resets MAC** — must be disabled in inittab, replaced with manual network init in rc.sh.

## Cross-Compilation

### ELDK 4.1 (Required for OABI binaries)

```bash
export PATH=/home/test/spear600/eldk41/usr/bin:/home/test/spear600/eldk41/bin:$PATH
export ELDKARM=/home/test/spear600/eldk41/arm
arm-linux-gcc -static -O2 \
    -I${ELDKARM}/usr/include \
    -L${ELDKARM}/lib -L${ELDKARM}/usr/lib \
    -o output source.c
```

GCC 4.0.0 (DENX ELDK 4.1) — produces OABI binaries with flags `0x602`, compatible with kernel 2.6.19. The `-I` and `-L` flags are mandatory; `--sysroot` is not supported by GCC 4.0.

### Buildroot Toolchain (NOT for board binaries)

Located at `buildroot/output/host/bin/arm-buildroot-linux-uclibcgnueabi-gcc` (GCC 14.3). Produces EABI5 binaries that cause `Illegal instruction` on kernel 2.6.19. Only use for building newer kernels (5.4+), not for userspace.

## Flashing NAND

### Via USB Flasher (initial boot)
```bash
cd usb_flasher/flasher
sudo tclsh flasher.tcl -f Scripts/flash_working_system.txt
# Script: connect, then flash xloader/fwd/u-boot/uImage/initramfs
```

### Via U-Boot TFTP (kernel/rootfs updates)
```
setenv serverip 192.168.11.121
setenv ipaddr 192.168.11.200
setenv ethaddr 00:1A:2B:3C:4D:5E
tftpboot 0x800000 <file>
nand erase <offset> <size>
nand write.jffs2 0x800000 <offset> <size>
```

### Boot Commands

**Automatic (default):** FWD auto-boot runs on power-up — no intervention needed. The `boot` command executes `run bootsteps` which includes mtdparts, console, kernel and rootfs loading.

**Manual (if autoboot interrupted):**
```
setenv bootargs console=ttyS0,115200 mem=108M initrd=0x1000000,0xb158d8 mtdparts=spear-nand:38400k@0k(part_0),82432k@38400k(part_1),2048k@120832k(part_2),8192k@122880k(part_3)
nand read.jffs2 0x800000 0x1a0000 0x1913e0
nand read.jffs2 0x1000000 0x600000 0xb158d8
bootm 0x800000
```

**WARNING:** Never omit mtdparts from manual bootargs — the kernel's built-in partition table maps mtdblock2 over the initramfs NAND area (0x600000). Booting without mtdparts causes jffs2 mount to erase the initramfs.

## Modifying the Initramfs

```bash
cd firmware/initramfs_orig/
# Make changes (edit etc/rc.sh, etc/inittab, add files)
sudo chown -R root:root .    # CRITICAL — non-root ownership breaks init
find . | sudo cpio -o -H newc 2>/dev/null | gzip > ../l300_initramfs_mod.gz
```

Then update FWD rootfs_size field at offset 0x54 (u32 LE) and update boot commands to match:
```bash
# Example: update FWD with new size 0xb158d8
printf '\xd8\x58\xb1\x00' | dd of=firmware/l300_fwd_mod.fwd bs=1 seek=84 conv=notrunc
```

## Framebuffer Tools

Source in `fbvnc/`:

- **fbterm.c** — Framebuffer terminal. Draws 8x16 bitmap font directly to /dev/fb0 (1024x768x24, 128x48 chars). Runs /bin/sh via PTY. Reads keyboard from stdin + `/tmp/vnc_kbd` FIFO. Green on black.
- **fbvnc_server.c** — VNC server (port 5900). Reads /dev/fb0, serves via RFB protocol. Keyboard input forwarded to `/tmp/vnc_kbd` FIFO for fbterm. Supports incremental updates with dirty-rect detection.
- **Start order matters:** fbterm first (creates FIFO), then fbvnc_server (opens FIFO for writing).

Compile:
```bash
arm-linux-gcc -static -O2 -I${ELDKARM}/usr/include -L${ELDKARM}/lib -L${ELDKARM}/usr/lib -o fbvnc/fbterm fbvnc/fbterm.c
arm-linux-gcc -static -O2 -I${ELDKARM}/usr/include -L${ELDKARM}/lib -L${ELDKARM}/usr/lib -o fbvnc/fbvnc_server fbvnc/fbvnc_server.c
```

## Building opkg Packages

```bash
# Cross-compile with ELDK
arm-linux-gcc -static -O2 -I${ELDKARM}/usr/include -L${ELDKARM}/lib -L${ELDKARM}/usr/lib -o binary source.c
# Package
mkdir -p /tmp/pkg/usr/bin && cp binary /tmp/pkg/usr/bin/
./packages/build_pkg.sh <name> <version> "<description>" /tmp/pkg
# Deploy via TFTP to board, then: opkg install /tmp/<name>_<ver>_arm.ipk
```

## Firmware Source

Original nComputing firmware extracted from vSpace: `l300_FW_ver_*.tar.gz` → `image.bot` (SquashFS 3.1) → extract with `binwalk -e` → `data/update.cfg` has NAND layout, `data/` has all images.

## Key Directories

- `firmware/initramfs_orig/` — extracted+modified rootfs (busybox 1.14.2, dropbear, uClibc 0.9.27)
- `firmware/` — all boot images and FWD variants
- `fbvnc/` — framebuffer terminal + VNC server source and binaries
- `tftpboot/` — files ready for TFTP/NAND flashing
- `eldk41/` — OABI cross-compilation toolchain
- `packages/repo/` — opkg .ipk packages
- `tools/deploy.sh` — SCP deploy helper (`./deploy.sh file` or `./deploy.sh --cmd "command"`)
- `usb_flasher/flasher/Scripts/flash_working_system.txt` — USB flash script for full system
