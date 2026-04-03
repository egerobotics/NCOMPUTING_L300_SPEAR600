/*
 * Minimal framebuffer VNC server
 * No external dependencies - standalone implementation
 * Supports 24-bit framebuffer
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <linux/fb.h>
#include <errno.h>

#define VNC_PORT 5900
#define BUF_SIZE 65536

static int fb_fd;
static unsigned char *fb_mem;
static struct fb_var_screeninfo vinfo;
static struct fb_fix_screeninfo finfo;
static int width, height, bpp, line_len;

/* RFB protocol */
static void send_all(int sock, const void *data, int len) {
    const char *p = data;
    while (len > 0) {
        int n = write(sock, p, len);
        if (n <= 0) return;
        p += n;
        len -= n;
    }
}

static int recv_all(int sock, void *data, int len) {
    char *p = data;
    while (len > 0) {
        int n = read(sock, p, len);
        if (n <= 0) return -1;
        p += n;
        len -= n;
    }
    return 0;
}

static void put32(unsigned char *p, unsigned int v) {
    p[0] = (v >> 24) & 0xff;
    p[1] = (v >> 16) & 0xff;
    p[2] = (v >> 8) & 0xff;
    p[3] = v & 0xff;
}

static void put16(unsigned char *p, unsigned short v) {
    p[0] = (v >> 8) & 0xff;
    p[1] = v & 0xff;
}

static unsigned short get16(unsigned char *p) {
    return (p[0] << 8) | p[1];
}

static int fb_open(void) {
    fb_fd = open("/dev/fb0", O_RDONLY);
    if (fb_fd < 0) { perror("open fb0"); return -1; }

    ioctl(fb_fd, FBIOGET_VSCREENINFO, &vinfo);
    ioctl(fb_fd, FBIOGET_FSCREENINFO, &finfo);

    width = vinfo.xres;
    height = vinfo.yres;
    bpp = vinfo.bits_per_pixel / 8;
    line_len = finfo.line_length;

    printf("FB: %dx%d, %d bpp, line_len=%d\n", width, height, bpp*8, line_len);

    fb_mem = mmap(NULL, finfo.smem_len, PROT_READ, MAP_SHARED, fb_fd, 0);
    if (fb_mem == MAP_FAILED) { perror("mmap"); return -1; }

    return 0;
}

static void handle_client(int sock) {
    unsigned char buf[BUF_SIZE];
    unsigned char *pixel_buf;
    int i, x, y;

    /* RFB 3.3 handshake */
    send_all(sock, "RFB 003.003\n", 12);
    if (recv_all(sock, buf, 12) < 0) return;

    /* Security: None */
    put32(buf, 1);
    send_all(sock, buf, 4);

    /* Client init */
    if (recv_all(sock, buf, 1) < 0) return;

    /* Server init */
    memset(buf, 0, 24 + 4 + 10);
    put16(buf, width);      /* width */
    put16(buf+2, height);   /* height */
    /* pixel format */
    buf[4] = 32;            /* bits per pixel */
    buf[5] = 24;            /* depth */
    buf[6] = 0;             /* big endian */
    buf[7] = 1;             /* true colour */
    put16(buf+8, 255);      /* red max */
    put16(buf+10, 255);     /* green max */
    put16(buf+12, 255);     /* blue max */
    buf[14] = 16;           /* red shift */
    buf[15] = 8;            /* green shift */
    buf[16] = 0;            /* blue shift */
    /* name */
    put32(buf+20, 6);       /* name length */
    memcpy(buf+24, "SPEAr6", 6);
    send_all(sock, buf, 30);

    printf("Client connected\n");

    pixel_buf = malloc(width * height * 4);
    if (!pixel_buf) return;

    while (1) {
        if (recv_all(sock, buf, 1) < 0) break;

        switch (buf[0]) {
        case 0: /* SetPixelFormat */
            recv_all(sock, buf, 19);
            break;
        case 2: /* SetEncodings */
            recv_all(sock, buf, 3);
            { int n = get16(buf+1);
              recv_all(sock, buf, n * 4);
            }
            break;
        case 3: /* FramebufferUpdateRequest */
            recv_all(sock, buf, 9);
            {
                /* Send raw framebuffer */
                unsigned char hdr[16];
                hdr[0] = 0; /* message type */
                hdr[1] = 0; /* padding */
                put16(hdr+2, 1); /* number of rectangles */
                put16(hdr+4, 0); /* x */
                put16(hdr+6, 0); /* y */
                put16(hdr+8, width);
                put16(hdr+10, height);
                put32(hdr+12, 0); /* raw encoding */
                send_all(sock, hdr, 16);

                /* Convert FB pixels to VNC format (32-bit RGBX) */
                for (y = 0; y < height; y++) {
                    unsigned char *src = fb_mem + y * line_len;
                    unsigned char *dst = pixel_buf + y * width * 4;
                    for (x = 0; x < width; x++) {
                        /* FB is 24-bit RGB or BGR */
                        dst[0] = src[vinfo.blue.offset/8];
                        dst[1] = src[vinfo.green.offset/8];
                        dst[2] = src[vinfo.red.offset/8];
                        dst[3] = 0;
                        src += bpp;
                        dst += 4;
                    }
                }
                send_all(sock, pixel_buf, width * height * 4);
            }
            break;
        case 4: /* KeyEvent */
            recv_all(sock, buf, 7);
            break;
        case 5: /* PointerEvent */
            recv_all(sock, buf, 5);
            break;
        case 6: /* ClientCutText */
            recv_all(sock, buf, 7);
            { int len = (buf[3]<<24)|(buf[4]<<16)|(buf[5]<<8)|buf[6];
              while (len > 0) {
                  int r = len > BUF_SIZE ? BUF_SIZE : len;
                  recv_all(sock, buf, r);
                  len -= r;
              }
            }
            break;
        default:
            printf("Unknown message type: %d\n", buf[0]);
            goto done;
        }
    }
done:
    free(pixel_buf);
    printf("Client disconnected\n");
}

int main(int argc, char **argv) {
    int srv, cli, opt = 1;
    struct sockaddr_in addr;

    if (fb_open() < 0) return 1;

    srv = socket(AF_INET, SOCK_STREAM, 0);
    setsockopt(srv, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port = htons(VNC_PORT);
    addr.sin_addr.s_addr = INADDR_ANY;

    if (bind(srv, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        perror("bind"); return 1;
    }
    listen(srv, 1);
    printf("VNC server listening on port %d (%dx%d)\n", VNC_PORT, width, height);

    while (1) {
        cli = accept(srv, NULL, NULL);
        if (cli < 0) continue;
        handle_client(cli);
        close(cli);
    }

    return 0;
}
