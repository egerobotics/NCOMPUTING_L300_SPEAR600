# Flashing the System from Scratch

## Files

| File | NAND Offset | Size (hex) | Description |
|------|------------|------------|-------------|
| xloader_image.bin | 0x00000000 | 0x153C | DDR init, loaded by BootROM |
| l300_fwd_mod.fwd | 0x00080000 | 0xB4 | Boot config (console, kernel/rootfs sizes) |
| u-boot.img | 0x000E0000 | 0x33014 | U-Boot 1.2.2 |
| uImage | 0x001A0000 | 0x1913E0 | Linux 2.6.19.2 kernel |
| l300_initramfs_minimal.gz | 0x00600000 | 0x31EA50 | Minimal initramfs (3.2MB) |

## Method 1: USB Flasher (blank board)

```bash
cd usb_flasher/flasher
sudo tclsh flasher.tcl -f Scripts/flash_working_system.txt
```

## Method 2: U-Boot TFTP

Copy files to the TFTP server directory (`/var/lib/tftpboot/`), then in U-Boot:

```
setenv serverip 192.168.1.100
setenv ipaddr 192.168.1.200
setenv ethaddr 00:1A:2B:3C:4D:5E

# X-Loader
tftpboot 0x800000 xloader_image.bin
nand erase 0x0 0x20000
nand write.jffs2 0x800000 0x0 0x153c

# FWD
tftpboot 0x800000 l300_fwd_mod.fwd
nand erase 0x80000 0x20000
nand write.jffs2 0x800000 0x80000 0xb4

# U-Boot
tftpboot 0x800000 u-boot.img
nand erase 0xe0000 0x40000
nand write.jffs2 0x800000 0xe0000 0x33014

# Kernel
tftpboot 0x800000 uImage
nand erase 0x1a0000 0x200000
nand write.jffs2 0x800000 0x1a0000 0x1913e0

# Initramfs
tftpboot 0x800000 l300_initramfs_minimal.gz
nand erase 0x600000 0xC00000
nand write.jffs2 0x800000 0x600000 0x31ea50
```

After reset, the board auto-boots. Do NOT press any key during bootdelay.

## Important Notes

- Do NOT use `saveenv` — it corrupts NAND
- The `boot` command does not work from the U-Boot prompt — use the autoboot timer instead
- For manual boot: `run step00` through `run step04`, then `bootm 800000`
- TFTP directory: `/var/lib/tftpboot/`
