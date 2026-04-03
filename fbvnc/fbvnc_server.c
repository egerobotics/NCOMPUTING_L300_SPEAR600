/*
 * Minimal framebuffer VNC server for nComputing L300
 * Read-only, no auth, raw encoding
 * Framebuffer: /dev/fb0 1024x768x24 (RGB888)
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <sys/socket.h>
#include <sys/mman.h>
#include <sys/ioctl.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <linux/fb.h>
#include <signal.h>
#include <sys/stat.h>

#define VNC_PORT 5900
#define FB_DEV "/dev/fb0"
#define KBD_FIFO "/tmp/vnc_kbd"

/* RFB message types (client to server) */
#define RFB_SET_PIXEL_FORMAT     0
#define RFB_SET_ENCODINGS        2
#define RFB_FB_UPDATE_REQUEST    3
#define RFB_KEY_EVENT            4
#define RFB_POINTER_EVENT        5
#define RFB_CLIENT_CUT_TEXT      6

/* RFB encoding types */
#define RFB_ENCODING_RAW         0

static int kbd_fd = -1;
static int fb_fd = -1;
static unsigned char *fb_mem = NULL;
static int fb_width, fb_height, fb_bpp, fb_stride;
static unsigned char *prev_frame = NULL;

static void write_u8(unsigned char *buf, unsigned char val)
{
	buf[0] = val;
}

static void write_u16(unsigned char *buf, unsigned short val)
{
	buf[0] = (val >> 8) & 0xff;
	buf[1] = val & 0xff;
}

static void write_u32(unsigned char *buf, unsigned int val)
{
	buf[0] = (val >> 24) & 0xff;
	buf[1] = (val >> 16) & 0xff;
	buf[2] = (val >> 8) & 0xff;
	buf[3] = val & 0xff;
}

static unsigned short read_u16(unsigned char *buf)
{
	return (buf[0] << 8) | buf[1];
}

static unsigned int read_u32(unsigned char *buf)
{
	return (buf[0] << 24) | (buf[1] << 16) | (buf[2] << 8) | buf[3];
}

static int write_all(int fd, unsigned char *buf, int len)
{
	int sent = 0;
	while (sent < len) {
		int n = write(fd, buf + sent, len - sent);
		if (n <= 0)
			return -1;
		sent += n;
	}
	return 0;
}

static int read_all(int fd, unsigned char *buf, int len)
{
	int got = 0;
	while (got < len) {
		int n = read(fd, buf + got, len - got);
		if (n <= 0)
			return -1;
		got += n;
	}
	return 0;
}

static int fb_open(void)
{
	struct fb_var_screeninfo vinfo;
	struct fb_fix_screeninfo finfo;

	fb_fd = open(FB_DEV, O_RDONLY);
	if (fb_fd < 0) {
		perror("open " FB_DEV);
		return -1;
	}

	if (ioctl(fb_fd, FBIOGET_VSCREENINFO, &vinfo) < 0) {
		perror("FBIOGET_VSCREENINFO");
		close(fb_fd);
		return -1;
	}

	if (ioctl(fb_fd, FBIOGET_FSCREENINFO, &finfo) < 0) {
		perror("FBIOGET_FSCREENINFO");
		close(fb_fd);
		return -1;
	}

	fb_width = vinfo.xres;
	fb_height = vinfo.yres;
	fb_bpp = vinfo.bits_per_pixel / 8;
	fb_stride = finfo.line_length;

	printf("Framebuffer: %dx%d, %d bpp, stride %d\n",
	       fb_width, fb_height, fb_bpp * 8, fb_stride);

	fb_mem = mmap(NULL, fb_stride * fb_height, PROT_READ, MAP_SHARED, fb_fd, 0);
	if (fb_mem == MAP_FAILED) {
		perror("mmap");
		close(fb_fd);
		return -1;
	}

	prev_frame = malloc(fb_stride * fb_height);
	if (prev_frame)
		memset(prev_frame, 0, fb_stride * fb_height);

	return 0;
}

/* Find bounding box of changed region, return 0 if no change */
static int find_changed_rect(int *rx, int *ry, int *rw, int *rh)
{
	int x_min = fb_width, x_max = 0;
	int y_min = fb_height, y_max = 0;
	int x, y;
	int changed = 0;

	for (y = 0; y < fb_height; y++) {
		unsigned char *cur = fb_mem + y * fb_stride;
		unsigned char *prev = prev_frame + y * fb_stride;
		for (x = 0; x < fb_width; x++) {
			int off = x * fb_bpp;
			if (cur[off] != prev[off] ||
			    cur[off+1] != prev[off+1] ||
			    cur[off+2] != prev[off+2]) {
				changed = 1;
				if (x < x_min) x_min = x;
				if (x > x_max) x_max = x;
				if (y < y_min) y_min = y;
				if (y > y_max) y_max = y;
			}
		}
	}

	if (!changed)
		return 0;

	*rx = x_min;
	*ry = y_min;
	*rw = x_max - x_min + 1;
	*rh = y_max - y_min + 1;

	memcpy(prev_frame, fb_mem, fb_stride * fb_height);
	return 1;
}

static int send_fb_update(int cfd, int x, int y, int w, int h)
{
	unsigned char hdr[16];
	unsigned char *row;
	int r, c;

	/* FramebufferUpdate header */
	write_u8(hdr, 0);        /* message type */
	write_u8(hdr + 1, 0);    /* padding */
	write_u16(hdr + 2, 1);   /* number of rectangles */

	/* Rectangle header */
	write_u16(hdr + 4, x);
	write_u16(hdr + 6, y);
	write_u16(hdr + 8, w);
	write_u16(hdr + 10, h);
	write_u32(hdr + 12, RFB_ENCODING_RAW);

	if (write_all(cfd, hdr, 16) < 0)
		return -1;

	/* Send pixel data as 32-bit BGRA (VNC standard) */
	row = malloc(w * 4);
	if (!row)
		return -1;

	for (r = y; r < y + h; r++) {
		unsigned char *src = fb_mem + r * fb_stride + x * fb_bpp;
		for (c = 0; c < w; c++) {
			/* FB is RGB (r/g/b at offsets 0/1/2), VNC wants BGRA */
			row[c * 4 + 0] = src[c * fb_bpp + 2]; /* blue */
			row[c * 4 + 1] = src[c * fb_bpp + 1]; /* green */
			row[c * 4 + 2] = src[c * fb_bpp + 0]; /* red */
			row[c * 4 + 3] = 0;                    /* alpha/pad */
		}
		if (write_all(cfd, row, w * 4) < 0) {
			free(row);
			return -1;
		}
	}

	free(row);
	return 0;
}

static int handle_client(int cfd)
{
	unsigned char buf[256];
	unsigned char *server_name = (unsigned char *)"L300 FB";
	int name_len = strlen((char *)server_name);
	int incremental = 0;

	/* Protocol version */
	if (write_all(cfd, (unsigned char *)"RFB 003.003\n", 12) < 0)
		return -1;
	if (read_all(cfd, buf, 12) < 0)
		return -1;

	/* Security: None (RFB 3.3 sends u32 security type) */
	write_u32(buf, 1);
	if (write_all(cfd, buf, 4) < 0)
		return -1;

	/* Wait for ClientInit (1 byte: shared flag) */
	if (read_all(cfd, buf, 1) < 0)
		return -1;

	/* ServerInit */
	write_u16(buf, fb_width);
	write_u16(buf + 2, fb_height);

	/* Pixel format: 32-bit, depth 24, big-endian=0, true-color=1 */
	buf[4] = 32;       /* bits-per-pixel */
	buf[5] = 24;       /* depth */
	buf[6] = 0;        /* big-endian */
	buf[7] = 1;        /* true-color */
	write_u16(buf + 8, 255);   /* red-max */
	write_u16(buf + 10, 255);  /* green-max */
	write_u16(buf + 12, 255);  /* blue-max */
	buf[14] = 16;      /* red-shift */
	buf[15] = 8;       /* green-shift */
	buf[16] = 0;       /* blue-shift */
	buf[17] = 0;       /* padding */
	buf[18] = 0;
	buf[19] = 0;

	/* Name */
	write_u32(buf + 20, name_len);
	if (write_all(cfd, buf, 24) < 0)
		return -1;
	if (write_all(cfd, server_name, name_len) < 0)
		return -1;

	printf("Client connected, serving %dx%d\n", fb_width, fb_height);

	/* Reset prev frame to force full update on first request */
	if (prev_frame)
		memset(prev_frame, 0xff, fb_stride * fb_height);

	/* Main loop */
	while (1) {
		if (read_all(cfd, buf, 1) < 0)
			break;

		switch (buf[0]) {
		case RFB_SET_PIXEL_FORMAT:
			if (read_all(cfd, buf, 19) < 0)
				return -1;
			/* Ignore — we always send our format */
			break;

		case RFB_SET_ENCODINGS:
			if (read_all(cfd, buf, 3) < 0)
				return -1;
			{
				int nenc = read_u16(buf + 1);
				int i;
				for (i = 0; i < nenc; i++) {
					if (read_all(cfd, buf + 4, 4) < 0)
						return -1;
				}
			}
			break;

		case RFB_FB_UPDATE_REQUEST:
			if (read_all(cfd, buf, 9) < 0)
				return -1;
			incremental = buf[0];
			{
				int rx, ry, rw, rh;
				if (!incremental) {
					/* Non-incremental: send full screen */
					if (send_fb_update(cfd, 0, 0, fb_width, fb_height) < 0)
						return -1;
					if (prev_frame)
						memcpy(prev_frame, fb_mem, fb_stride * fb_height);
				} else {
					/* Incremental: send only changed region */
					if (find_changed_rect(&rx, &ry, &rw, &rh)) {
						if (send_fb_update(cfd, rx, ry, rw, rh) < 0)
							return -1;
					} else {
						/* No changes — send empty update */
						unsigned char empty[4];
						write_u8(empty, 0);
						write_u8(empty + 1, 0);
						write_u16(empty + 2, 0);
						if (write_all(cfd, empty, 4) < 0)
							return -1;
					}
				}
			}
			break;

		case RFB_KEY_EVENT:
			if (read_all(cfd, buf, 7) < 0)
				return -1;
			/* Forward key press to FIFO */
			if (buf[0] && kbd_fd >= 0) {
				unsigned int key = read_u32(buf + 3);
				char ch = 0;
				/* Map VNC keysyms to ASCII */
				if (key == 0xff0d) ch = '\n';       /* Return */
				else if (key == 0xff08) ch = '\b';  /* Backspace */
				else if (key == 0xff09) ch = '\t';  /* Tab */
				else if (key == 0xff1b) ch = '\033'; /* Escape */
				else if (key == 0xffe3 || key == 0xffe4) ch = 0; /* Ctrl */
				else if (key >= 0x20 && key <= 0x7e) ch = key; /* Printable ASCII */
				else if (key == 0xff54) { write(kbd_fd, "\033[B", 3); break; } /* Down */
				else if (key == 0xff52) { write(kbd_fd, "\033[A", 3); break; } /* Up */
				else if (key == 0xff51) { write(kbd_fd, "\033[D", 3); break; } /* Left */
				else if (key == 0xff53) { write(kbd_fd, "\033[C", 3); break; } /* Right */
				if (ch)
					write(kbd_fd, &ch, 1);
			}
			break;

		case RFB_POINTER_EVENT:
			if (read_all(cfd, buf, 5) < 0)
				return -1;
			/* Ignore pointer events (read-only) */
			break;

		case RFB_CLIENT_CUT_TEXT:
			if (read_all(cfd, buf, 7) < 0)
				return -1;
			{
				unsigned int tlen = read_u32(buf + 3);
				while (tlen > 0) {
					int chunk = tlen > sizeof(buf) ? sizeof(buf) : tlen;
					if (read_all(cfd, buf, chunk) < 0)
						return -1;
					tlen -= chunk;
				}
			}
			break;

		default:
			printf("Unknown message type: %d\n", buf[0]);
			return -1;
		}
	}

	return 0;
}

int main(int argc, char **argv)
{
	int sfd, cfd, opt = 1;
	struct sockaddr_in addr;
	int port = VNC_PORT;

	signal(SIGPIPE, SIG_IGN);

	if (argc > 1)
		port = atoi(argv[1]);

	if (fb_open() < 0)
		return 1;

	/* Create keyboard FIFO */
	unlink(KBD_FIFO);
	if (mkfifo(KBD_FIFO, 0666) < 0) {
		perror("mkfifo");
	}
	kbd_fd = open(KBD_FIFO, O_WRONLY | O_NONBLOCK);
	if (kbd_fd < 0)
		printf("Warning: cannot open %s for writing (start fbterm first)\n", KBD_FIFO);

	printf("Framebuffer VNC server on port %d\n", port);

	sfd = socket(AF_INET, SOCK_STREAM, 0);
	if (sfd < 0) {
		perror("socket");
		return 1;
	}

	setsockopt(sfd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

	memset(&addr, 0, sizeof(addr));
	addr.sin_family = AF_INET;
	addr.sin_addr.s_addr = INADDR_ANY;
	addr.sin_port = htons(port);

	if (bind(sfd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
		perror("bind");
		close(sfd);
		return 1;
	}

	if (listen(sfd, 1) < 0) {
		perror("listen");
		close(sfd);
		return 1;
	}

	while (1) {
		struct sockaddr_in caddr;
		socklen_t clen = sizeof(caddr);

		printf("Waiting for VNC client...\n");
		cfd = accept(sfd, (struct sockaddr *)&caddr, &clen);
		if (cfd < 0) {
			perror("accept");
			continue;
		}

		opt = 1;
		setsockopt(cfd, IPPROTO_TCP, TCP_NODELAY, &opt, sizeof(opt));

		handle_client(cfd);

		close(cfd);
		printf("Client disconnected\n");
	}

	return 0;
}
