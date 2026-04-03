/*
 * Minimal framebuffer VNC server for SPEAr600
 * RFB protocol 003.003 - view only, no authentication
 * Shares /dev/fb0 over VNC on port 5900
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <sys/mman.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <sys/select.h>
#include <netinet/in.h>
#include <linux/fb.h>
#include <arpa/inet.h>

#define VNC_PORT 5900
#define MAX_CLIENTS 4

static int fb_fd;
static unsigned char *fb_mem;
static int xres, yres, bpp, line_len, fb_size;
static struct fb_var_screeninfo vinfo;

/* RFB protocol helpers */
static void send_u8(int fd, unsigned char v) { write(fd, &v, 1); }
static void send_u16(int fd, unsigned short v) { v = htons(v); write(fd, &v, 2); }
static void send_u32(int fd, unsigned int v) { v = htonl(v); write(fd, &v, 4); }

static unsigned char read_u8(int fd) {
    unsigned char v; read(fd, &v, 1); return v;
}
static unsigned short read_u16(int fd) {
    unsigned short v; read(fd, &v, 2); return ntohs(v);
}
static unsigned int read_u32(int fd) {
    unsigned int v; read(fd, &v, 4); return ntohl(v);
}

static int send_all(int fd, const void *buf, int len) {
    int sent = 0;
    while (sent < len) {
        int n = write(fd, (char*)buf + sent, len - sent);
        if (n <= 0) return -1;
        sent += n;
    }
    return sent;
}

/* Convert RGB565 to RGB888 */
static void convert_fb_to_rgb(unsigned char *dst, int x, int y, int w, int h) {
    int i, j;
    unsigned short *fb16 = (unsigned short *)fb_mem;
    for (j = 0; j < h; j++) {
        for (i = 0; i < w; i++) {
            int sx = x + i, sy = y + j;
            if (sx < xres && sy < yres) {
                unsigned short pixel = fb16[sy * (line_len/2) + sx];
                int r = ((pixel >> 11) & 0x1f) << 3;
                int g = ((pixel >> 5) & 0x3f) << 2;
                int b = (pixel & 0x1f) << 3;
                *dst++ = r;
                *dst++ = g;
                *dst++ = b;
                *dst++ = 0; /* padding */
            } else {
                *dst++ = 0; *dst++ = 0; *dst++ = 0; *dst++ = 0;
            }
        }
    }
}

static int handle_client(int client_fd) {
    char buf[256];
    int len;
    unsigned char *pixel_buf;

    /* RFB protocol version handshake */
    write(client_fd, "RFB 003.003\n", 12);
    len = read(client_fd, buf, 12);
    if (len < 12) return -1;

    /* Security: None (type 1) */
    send_u32(client_fd, 1);

    /* ClientInit: shared flag */
    read_u8(client_fd);

    /* ServerInit */
    send_u16(client_fd, xres);  /* width */
    send_u16(client_fd, yres);  /* height */

    /* Pixel format: 32bpp, 24depth, RGB888 */
    send_u8(client_fd, 32);     /* bits per pixel */
    send_u8(client_fd, 24);     /* depth */
    send_u8(client_fd, 0);      /* big endian */
    send_u8(client_fd, 1);      /* true color */
    send_u16(client_fd, 255);   /* red max */
    send_u16(client_fd, 255);   /* green max */
    send_u16(client_fd, 255);   /* blue max */
    send_u8(client_fd, 16);     /* red shift */
    send_u8(client_fd, 8);      /* green shift */
    send_u8(client_fd, 0);      /* blue shift */
    send_u8(client_fd, 0);      /* padding */
    send_u8(client_fd, 0);
    send_u8(client_fd, 0);

    /* Name */
    send_u32(client_fd, 7);
    write(client_fd, "SPEAr600", 7);

    printf("VNC client connected\n");

    pixel_buf = malloc(xres * yres * 4);
    if (!pixel_buf) return -1;

    while (1) {
        fd_set rfds;
        struct timeval tv;
        FD_ZERO(&rfds);
        FD_SET(client_fd, &rfds);
        tv.tv_sec = 0;
        tv.tv_usec = 100000; /* 100ms */

        int ret = select(client_fd + 1, &rfds, NULL, NULL, &tv);
        if (ret < 0) break;

        if (ret > 0 && FD_ISSET(client_fd, &rfds)) {
            unsigned char msg_type = read_u8(client_fd);

            switch (msg_type) {
            case 0: /* SetPixelFormat */
                read(client_fd, buf, 19);
                break;
            case 2: /* SetEncodings */
                {
                    read_u8(client_fd); /* padding */
                    int nenc = read_u16(client_fd);
                    int i;
                    for (i = 0; i < nenc; i++) read_u32(client_fd);
                }
                break;
            case 3: /* FramebufferUpdateRequest */
                {
                    int incremental = read_u8(client_fd);
                    int rx = read_u16(client_fd);
                    int ry = read_u16(client_fd);
                    int rw = read_u16(client_fd);
                    int rh = read_u16(client_fd);

                    /* Send raw framebuffer update */
                    send_u8(client_fd, 0);  /* FramebufferUpdate */
                    send_u8(client_fd, 0);  /* padding */
                    send_u16(client_fd, 1); /* number of rects */

                    send_u16(client_fd, rx);
                    send_u16(client_fd, ry);
                    send_u16(client_fd, rw);
                    send_u16(client_fd, rh);
                    send_u32(client_fd, 0); /* Raw encoding */

                    convert_fb_to_rgb(pixel_buf, rx, ry, rw, rh);
                    if (send_all(client_fd, pixel_buf, rw * rh * 4) < 0)
                        goto done;
                }
                break;
            case 4: /* KeyEvent */
                read(client_fd, buf, 7);
                break;
            case 5: /* PointerEvent */
                read(client_fd, buf, 5);
                break;
            case 6: /* ClientCutText */
                {
                    read(client_fd, buf, 3);
                    int tlen = read_u32(client_fd);
                    while (tlen > 0) {
                        int r = read(client_fd, buf, tlen > 256 ? 256 : tlen);
                        if (r <= 0) goto done;
                        tlen -= r;
                    }
                }
                break;
            default:
                printf("Unknown VNC message: %d\n", msg_type);
                goto done;
            }
        }
    }

done:
    free(pixel_buf);
    printf("VNC client disconnected\n");
    return 0;
}

int main(int argc, char **argv) {
    struct fb_fix_screeninfo finfo;
    int server_fd, client_fd;
    struct sockaddr_in addr;
    int opt = 1;

    /* Open framebuffer */
    fb_fd = open("/dev/fb0", O_RDONLY);
    if (fb_fd < 0) { perror("/dev/fb0"); return 1; }

    ioctl(fb_fd, FBIOGET_FSCREENINFO, &finfo);
    ioctl(fb_fd, FBIOGET_VSCREENINFO, &vinfo);

    xres = vinfo.xres;
    yres = vinfo.yres;
    bpp = vinfo.bits_per_pixel;
    line_len = finfo.line_length;
    fb_size = finfo.smem_len;

    printf("Framebuffer: %dx%d %dbpp\n", xres, yres, bpp);

    fb_mem = mmap(0, fb_size, PROT_READ, MAP_SHARED, fb_fd, 0);
    if (fb_mem == MAP_FAILED) { perror("mmap"); return 1; }

    /* Create TCP server */
    server_fd = socket(AF_INET, SOCK_STREAM, 0);
    setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = INADDR_ANY;
    addr.sin_port = htons(VNC_PORT);

    if (bind(server_fd, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        perror("bind"); return 1;
    }
    listen(server_fd, 2);

    printf("VNC server listening on port %d\n", VNC_PORT);
    printf("Connect with: vncviewer 192.168.1.200\n");

    while (1) {
        socklen_t alen = sizeof(addr);
        client_fd = accept(server_fd, (struct sockaddr*)&addr, &alen);
        if (client_fd < 0) continue;

        printf("Connection from %s\n", inet_ntoa(addr.sin_addr));
        handle_client(client_fd);
        close(client_fd);
    }

    return 0;
}
