/*
 * Minimal framebuffer VNC server - bare syscalls, no libc TLS
 * For Linux 2.6.19 ARM926EJ-S
 */

/* Syscall numbers for ARM EABI */
#define __NR_exit       1
#define __NR_read       3
#define __NR_write      4
#define __NR_open       5
#define __NR_close      6
#define __NR_brk        45
#define __NR_ioctl      54
#define __NR_mmap2      192
#define __NR_socket     281
#define __NR_bind       282
#define __NR_listen     284
#define __NR_accept     285
#define __NR_setsockopt 294

typedef unsigned int uint32_t;
typedef unsigned short uint16_t;
typedef unsigned long size_t;

static long syscall1(int nr, long a1) {
    register long r7 __asm__("r7") = nr;
    register long r0 __asm__("r0") = a1;
    __asm__ volatile("swi 0" : "=r"(r0) : "r"(r7), "0"(r0));
    return r0;
}
static long syscall2(int nr, long a1, long a2) {
    register long r7 __asm__("r7") = nr;
    register long r0 __asm__("r0") = a1;
    register long r1 __asm__("r1") = a2;
    __asm__ volatile("swi 0" : "=r"(r0) : "r"(r7), "0"(r0), "r"(r1));
    return r0;
}
static long syscall3(int nr, long a1, long a2, long a3) {
    register long r7 __asm__("r7") = nr;
    register long r0 __asm__("r0") = a1;
    register long r1 __asm__("r1") = a2;
    register long r2 __asm__("r2") = a3;
    __asm__ volatile("swi 0" : "=r"(r0) : "r"(r7), "0"(r0), "r"(r1), "r"(r2));
    return r0;
}
static long syscall5(int nr, long a1, long a2, long a3, long a4, long a5) {
    register long r7 __asm__("r7") = nr;
    register long r0 __asm__("r0") = a1;
    register long r1 __asm__("r1") = a2;
    register long r2 __asm__("r2") = a3;
    register long r3 __asm__("r3") = a4;
    register long r4 __asm__("r4") = a5;
    __asm__ volatile("swi 0" : "=r"(r0) : "r"(r7), "0"(r0), "r"(r1), "r"(r2), "r"(r3), "r"(r4));
    return r0;
}
static long syscall6(int nr, long a1, long a2, long a3, long a4, long a5, long a6) {
    register long r7 __asm__("r7") = nr;
    register long r0 __asm__("r0") = a1;
    register long r1 __asm__("r1") = a2;
    register long r2 __asm__("r2") = a3;
    register long r3 __asm__("r3") = a4;
    register long r4 __asm__("r4") = a5;
    register long r5 __asm__("r5") = a6;
    __asm__ volatile("swi 0" : "=r"(r0) : "r"(r7), "0"(r0), "r"(r1), "r"(r2), "r"(r3), "r"(r4), "r"(r5));
    return r0;
}

#define O_RDONLY 0
#define PROT_READ 1
#define MAP_SHARED 1
#define AF_INET 2
#define SOCK_STREAM 1
#define SOL_SOCKET 1
#define SO_REUSEADDR 2

#define FBIOGET_VSCREENINFO 0x4600
#define FBIOGET_FSCREENINFO 0x4602

struct fb_bitfield { uint32_t offset, length, msb_right; };
struct fb_var { uint32_t xres, yres, xres_virtual, yres_virtual, xoffset, yoffset, bits_per_pixel, grayscale; struct fb_bitfield red, green, blue, transp; };
struct fb_fix { char id[16]; unsigned long smem_start; uint32_t smem_len; uint32_t type, type_aux, visual; uint16_t xpanstep, ypanstep, ywrapstep; uint32_t line_length; };
struct sockaddr_in { uint16_t family; uint16_t port; uint32_t addr; char pad[8]; };

static int my_open(const char *p, int f) { return syscall2(__NR_open, (long)p, f); }
static int my_close(int fd) { return syscall1(__NR_close, fd); }
static int my_read(int fd, void *b, int n) { return syscall3(__NR_read, fd, (long)b, n); }
static int my_write(int fd, const void *b, int n) { return syscall3(__NR_write, fd, (long)b, n); }
static int my_ioctl(int fd, int req, void *arg) { return syscall3(__NR_ioctl, fd, req, (long)arg); }
static void *my_mmap(void *a, int len, int p, int f, int fd, int off) { return (void*)syscall6(__NR_mmap2, (long)a, len, p, f, fd, off/4096); }
static int my_socket(int d, int t, int p) { return syscall3(__NR_socket, d, t, p); }
static int my_bind(int s, void *a, int l) { return syscall3(__NR_bind, s, (long)a, l); }
static int my_listen(int s, int b) { return syscall2(__NR_listen, s, b); }
static int my_accept(int s, void *a, void *l) { return syscall3(__NR_accept, s, (long)a, (long)l); }
static int my_setsockopt(int s, int l, int n, void *v, int ol) { return syscall5(__NR_setsockopt, s, l, n, (long)v, ol); }
static void my_exit(int c) { syscall1(__NR_exit, c); }

static void *my_memset(void *s, int c, int n) { char *p=s; while(n--) *p++=c; return s; }
static void *my_memcpy(void *d, const void *s, int n) { char *dp=d; const char *sp=s; while(n--) *dp++=*sp++; return d; }

static void puts_s(const char *s) { int i=0; while(s[i]) i++; my_write(1, s, i); }

static void send_all(int s, const void *d, int len) {
    const char *p = d; while(len>0) { int n=my_write(s,p,len); if(n<=0) return; p+=n; len-=n; }
}
static int recv_all(int s, void *d, int len) {
    char *p = d; while(len>0) { int n=my_read(s,p,len); if(n<=0) return -1; p+=n; len-=n; } return 0;
}

static void put32(unsigned char *p, uint32_t v) { p[0]=(v>>24)&0xff; p[1]=(v>>16)&0xff; p[2]=(v>>8)&0xff; p[3]=v&0xff; }
static void put16(unsigned char *p, uint16_t v) { p[0]=(v>>8)&0xff; p[1]=v&0xff; }
static uint16_t get16(unsigned char *p) { return (p[0]<<8)|p[1]; }
static uint16_t htons(uint16_t v) { return (v>>8)|(v<<8); }

static unsigned char buf[4096];
static unsigned char fb_var_buf[sizeof(struct fb_var)];
static unsigned char fb_fix_buf[sizeof(struct fb_fix)];

/* Simple heap using brk */
static unsigned long heap_end = 0;
static void *my_malloc(int size) {
    if (!heap_end) heap_end = syscall1(__NR_brk, 0);
    unsigned long old = heap_end;
    heap_end = syscall1(__NR_brk, heap_end + size);
    return (void*)old;
}

void _start(void) {
    struct fb_var *vi = (struct fb_var*)fb_var_buf;
    struct fb_fix *fi = (struct fb_fix*)fb_fix_buf;
    int fb_fd, srv, cli, opt=1, width, height, bpp, line_len;
    unsigned char *fb_mem, *pixel_buf;
    struct sockaddr_in addr;
    int x, y;

    fb_fd = my_open("/dev/fb0", O_RDONLY);
    if (fb_fd < 0) { puts_s("ERR: open fb0\n"); my_exit(1); }

    my_ioctl(fb_fd, FBIOGET_VSCREENINFO, vi);
    my_ioctl(fb_fd, FBIOGET_FSCREENINFO, fi);

    width = vi->xres; height = vi->yres; bpp = vi->bits_per_pixel / 8;
    line_len = fi->line_length;

    puts_s("VNC: fb ready\n");

    fb_mem = my_mmap(0, fi->smem_len, PROT_READ, MAP_SHARED, fb_fd, 0);
    if ((long)fb_mem < 0) { puts_s("ERR: mmap\n"); my_exit(1); }

    srv = my_socket(AF_INET, SOCK_STREAM, 0);
    my_setsockopt(srv, SOL_SOCKET, SO_REUSEADDR, &opt, 4);

    my_memset(&addr, 0, sizeof(addr));
    addr.family = AF_INET;
    addr.port = htons(5900);
    addr.addr = 0;

    if (my_bind(srv, &addr, sizeof(addr)) < 0) { puts_s("ERR: bind\n"); my_exit(1); }
    my_listen(srv, 1);
    puts_s("VNC: port 5900\n");

    while(1) {
        cli = my_accept(srv, 0, 0);
        if (cli < 0) continue;
        puts_s("VNC: client\n");

        /* RFB 3.3 */
        send_all(cli, "RFB 003.003\n", 12);
        if (recv_all(cli, buf, 12) < 0) goto disc;
        put32(buf, 1); send_all(cli, buf, 4); /* no auth */
        if (recv_all(cli, buf, 1) < 0) goto disc; /* client init */

        /* server init */
        my_memset(buf, 0, 30);
        put16(buf, width); put16(buf+2, height);
        buf[4]=32; buf[5]=24; buf[6]=0; buf[7]=1;
        put16(buf+8,255); put16(buf+10,255); put16(buf+12,255);
        buf[14]=16; buf[15]=8; buf[16]=0;
        put32(buf+20, 5); my_memcpy(buf+24, "L300\0", 5);
        send_all(cli, buf, 29);

        pixel_buf = my_malloc(width * height * 4);
        if (!pixel_buf) goto disc;

        while(1) {
            if (recv_all(cli, buf, 1) < 0) break;
            switch(buf[0]) {
            case 0: recv_all(cli, buf, 19); break;
            case 2: recv_all(cli, buf, 3); { int n=get16(buf+1); recv_all(cli,buf,n*4); } break;
            case 3:
                recv_all(cli, buf, 9);
                {
                    unsigned char hdr[16];
                    hdr[0]=0; hdr[1]=0; put16(hdr+2,1);
                    put16(hdr+4,0); put16(hdr+6,0);
                    put16(hdr+8,width); put16(hdr+10,height);
                    put32(hdr+12,0);
                    send_all(cli, hdr, 16);
                    for(y=0;y<height;y++) {
                        unsigned char *src=fb_mem+y*line_len;
                        unsigned char *dst=pixel_buf+y*width*4;
                        for(x=0;x<width;x++) {
                            dst[0]=src[vi->blue.offset/8];
                            dst[1]=src[vi->green.offset/8];
                            dst[2]=src[vi->red.offset/8];
                            dst[3]=0;
                            src+=bpp; dst+=4;
                        }
                    }
                    send_all(cli, pixel_buf, width*height*4);
                }
                break;
            case 4: recv_all(cli, buf, 7); break;
            case 5: recv_all(cli, buf, 5); break;
            case 6: recv_all(cli,buf,7); { int l=(buf[3]<<24)|(buf[4]<<16)|(buf[5]<<8)|buf[6]; while(l>0){int r=l>4096?4096:l; recv_all(cli,buf,r); l-=r;} } break;
            default: goto disc;
            }
        }
disc:
        my_close(cli);
        puts_s("VNC: disc\n");
    }
}
