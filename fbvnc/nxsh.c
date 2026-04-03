/*
 * Minimal Nano-X shell terminal for nComputing L300
 * Displays a simple terminal window running /bin/sh
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <signal.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <sys/select.h>

#define MWINCLUDECOLORS
#include <microwin/nano-X.h>

#define TERM_COLS  80
#define TERM_ROWS  24
#define CHAR_W     8
#define CHAR_H     16
#define WIN_W      (TERM_COLS * CHAR_W)
#define WIN_H      (TERM_ROWS * CHAR_H)

static GR_WINDOW_ID wid;
static GR_GC_ID gc;
static int master_fd;
static pid_t child_pid;

/* Simple screen buffer */
static char screen[TERM_ROWS][TERM_COLS + 1];
static int cur_row = 0, cur_col = 0;

static void redraw_line(int row)
{
	/* Clear line */
	GrSetGCForeground(gc, BLACK);
	GrFillRect(wid, gc, 0, row * CHAR_H, WIN_W, CHAR_H);

	/* Draw text */
	GrSetGCForeground(gc, GREEN);
	GrSetGCBackground(gc, BLACK);
	GrText(wid, gc, 0, row * CHAR_H, screen[row], strlen(screen[row]),
	       GR_TFASCII | GR_TFTOP);
}

static void redraw_all(void)
{
	int i;
	GrSetGCForeground(gc, BLACK);
	GrFillRect(wid, gc, 0, 0, WIN_W, WIN_H);
	for (i = 0; i < TERM_ROWS; i++) {
		if (screen[i][0])
			redraw_line(i);
	}
}

static void scroll_up(void)
{
	int i;
	for (i = 0; i < TERM_ROWS - 1; i++)
		memcpy(screen[i], screen[i + 1], TERM_COLS + 1);
	memset(screen[TERM_ROWS - 1], 0, TERM_COLS + 1);
	cur_row = TERM_ROWS - 1;
	redraw_all();
}

static void term_putchar(char c)
{
	if (c == '\n' || c == '\r') {
		cur_col = 0;
		cur_row++;
		if (cur_row >= TERM_ROWS)
			scroll_up();
		return;
	}
	if (c == '\b' || c == 127) {
		if (cur_col > 0) {
			cur_col--;
			screen[cur_row][cur_col] = ' ';
			redraw_line(cur_row);
		}
		return;
	}
	if (c == '\t') {
		int spaces = 8 - (cur_col % 8);
		int i;
		for (i = 0; i < spaces && cur_col < TERM_COLS; i++)
			screen[cur_row][cur_col++] = ' ';
		redraw_line(cur_row);
		return;
	}
	/* Ignore other control chars */
	if (c < 32)
		return;

	if (cur_col >= TERM_COLS) {
		cur_col = 0;
		cur_row++;
		if (cur_row >= TERM_ROWS)
			scroll_up();
	}

	screen[cur_row][cur_col++] = c;
	redraw_line(cur_row);
}

static void term_write(const char *buf, int len)
{
	int i;
	/* Simple ANSI escape filter — just strip them */
	static int in_esc = 0;
	for (i = 0; i < len; i++) {
		if (in_esc) {
			if ((buf[i] >= 'A' && buf[i] <= 'Z') ||
			    (buf[i] >= 'a' && buf[i] <= 'z') ||
			    buf[i] == '@' || buf[i] == '~') {
				in_esc = 0;
			}
			continue;
		}
		if (buf[i] == '\033') {
			in_esc = 1;
			continue;
		}
		term_putchar(buf[i]);
	}
}

static int setup_pty(void)
{
	int master, slave;
	char *slave_name;

	master = open("/dev/ptmx", O_RDWR | O_NOCTTY);
	if (master < 0) {
		/* Try old-style PTY */
		master = open("/dev/ptyp0", O_RDWR);
		if (master < 0) {
			perror("open pty");
			return -1;
		}
		slave = open("/dev/ttyp0", O_RDWR);
		if (slave < 0) {
			perror("open tty");
			close(master);
			return -1;
		}
	} else {
		grantpt(master);
		unlockpt(master);
		slave_name = ptsname(master);
		if (!slave_name) {
			perror("ptsname");
			close(master);
			return -1;
		}
		slave = open(slave_name, O_RDWR);
		if (slave < 0) {
			perror("open slave");
			close(master);
			return -1;
		}
	}

	child_pid = fork();
	if (child_pid < 0) {
		perror("fork");
		return -1;
	}

	if (child_pid == 0) {
		/* Child */
		close(master);
		setsid();
		dup2(slave, 0);
		dup2(slave, 1);
		dup2(slave, 2);
		if (slave > 2)
			close(slave);
		setenv("TERM", "dumb", 1);
		setenv("USER", "root", 1);
		setenv("HOME", "/", 1);
		setenv("PS1", "# ", 1);
		execl("/bin/sh", "sh", NULL);
		_exit(1);
	}

	/* Parent */
	close(slave);
	master_fd = master;
	return 0;
}

int main(void)
{
	GR_EVENT event;
	int nanox_fd;

	if (GrOpen() < 0) {
		fprintf(stderr, "Cannot open Nano-X\n");
		return 1;
	}

	memset(screen, 0, sizeof(screen));

	wid = GrNewWindowEx(GR_WM_PROPS_APPWINDOW | GR_WM_PROPS_CAPTION,
			    "Terminal",
			    GR_ROOT_WINDOW_ID,
			    50, 50, WIN_W, WIN_H,
			    BLACK);

	gc = GrNewGC();
	GrSetGCForeground(gc, GREEN);
	GrSetGCBackground(gc, BLACK);
	GrSetGCFont(gc, GrCreateFont(GR_FONT_SYSTEM_FIXED, 0, NULL));

	GrSelectEvents(wid, GR_EVENT_MASK_EXPOSURE |
			    GR_EVENT_MASK_KEY_DOWN |
			    GR_EVENT_MASK_CLOSE_REQ);
	GrMapWindow(wid);

	if (setup_pty() < 0)
		return 1;

	while (1) {
		fd_set rfds;
		int maxfd, ret;

		FD_ZERO(&rfds);
		FD_SET(master_fd, &rfds);
		maxfd = master_fd;

		GrPrepareSelect(&maxfd, &rfds);

		ret = select(maxfd + 1, &rfds, NULL, NULL, NULL);
		if (ret < 0) {
			if (errno == EINTR)
				continue;
			break;
		}

		/* Check for shell output */
		if (FD_ISSET(master_fd, &rfds)) {
			char buf[256];
			int n = read(master_fd, buf, sizeof(buf));
			if (n <= 0)
				break;
			term_write(buf, n);
		}

		/* Check for Nano-X events */
		GrServiceSelect(&rfds, NULL);
		while (GrPeekEvent(&event)) {
			GrGetNextEvent(&event);
			switch (event.type) {
			case GR_EVENT_TYPE_EXPOSURE:
				redraw_all();
				break;
			case GR_EVENT_TYPE_KEY_DOWN:
				{
					char c = event.keystroke.ch;
					write(master_fd, &c, 1);
				}
				break;
			case GR_EVENT_TYPE_CLOSE_REQ:
				goto done;
			}
		}
	}

done:
	if (child_pid > 0)
		kill(child_pid, SIGTERM);
	GrClose();
	return 0;
}
