# Sıfırdan Sistem Yükleme Rehberi

## Dosyalar

| Dosya | NAND Offset | Boyut (hex) | Açıklama |
|-------|------------|-------------|----------|
| xloader_image.bin | 0x00000000 | 0x153C | DDR init, BootROM tarafından yüklenir |
| l300_fwd_mod.fwd | 0x00080000 | 0xB4 | Boot config (console, kernel/rootfs boyutları) |
| u-boot.img | 0x000E0000 | 0x33014 | U-Boot 1.2.2 |
| uImage | 0x001A0000 | 0x1913E0 | Linux 2.6.19.2 kernel |
| l300_initramfs_minimal.gz | 0x00600000 | 0x31EA50 | Minimal initramfs (3.2MB) |

## Yöntem 1: USB Flasher ile (board boş iken)

```bash
cd usb_flasher/flasher
sudo tclsh flasher.tcl -f Scripts/flash_working_system.txt
```

## Yöntem 2: U-Boot TFTP ile

Dosyaları TFTP sunucusuna kopyala (`/var/lib/tftpboot/`), sonra U-Boot'ta:

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

Reset sonrası otomatik boot eder. Bootdelay sırasında tuşa BASMAYIN.

## Önemli Notlar

- `saveenv` KULLANMAYIN — NAND'ı bozar
- `boot` komutu U-Boot prompt'ında çalışmaz — autoboot timer'ı kullanın
- Manuel boot gerekirse: `run step00` ... `run step04` sonra `bootm 800000`
- TFTP dizini: `/var/lib/tftpboot/`
