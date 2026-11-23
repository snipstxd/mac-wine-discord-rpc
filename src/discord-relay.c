// discord-relay - runs natively on macOS.
//
// Listens on 127.0.0.1:6473 (localhost only) and forwards every connection to
// the Discord desktop app's IPC socket ($TMPDIR/discord-ipc-N). pipebridge.exe,
// running inside Wine, connects here on behalf of the game.
//
// Build: clang -O2 -arch arm64 -arch x86_64 -o discord-relay discord-relay.c
#include <arpa/inet.h>
#include <errno.h>
#include <netinet/in.h>
#include <poll.h>
#include <pthread.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/un.h>
#include <time.h>
#include <unistd.h>

#define PORT 6473
#define BUF 65536

static void logf_(const char *fmt, const char *arg) {
    time_t t = time(NULL);
    char ts[32];
    strftime(ts, sizeof ts, "%Y-%m-%d %H:%M:%S", localtime(&t));
    fprintf(stderr, "[%s] ", ts);
    fprintf(stderr, fmt, arg ? arg : "");
    fputc('\n', stderr);
    fflush(stderr);
}

// Find Discord's IPC socket. Checks the per-user temp dir first (where macOS
// Discord puts it), then $TMPDIR, $XDG_RUNTIME_DIR and /tmp.
static int find_socket(char *out, size_t outlen) {
    char dirs[4][1024];
    int n = 0;
    size_t len = confstr(_CS_DARWIN_USER_TEMP_DIR, dirs[n], sizeof dirs[n]);
    if (len > 0 && len <= sizeof dirs[n]) n++;
    const char *envs[] = {"TMPDIR", "XDG_RUNTIME_DIR"};
    for (int i = 0; i < 2; i++) {
        const char *v = getenv(envs[i]);
        if (v && *v) snprintf(dirs[n++], sizeof dirs[0], "%s", v);
    }
    snprintf(dirs[n++], sizeof dirs[0], "/tmp");

    for (int d = 0; d < n; d++) {
        for (int i = 0; i < 10; i++) {
            const char *dir = dirs[d];
            size_t dl = strlen(dir);
            const char *sep = (dl && dir[dl - 1] == '/') ? "" : "/";
            snprintf(out, outlen, "%s%sdiscord-ipc-%d", dir, sep, i);
            struct stat st;
            if (stat(out, &st) == 0 && S_ISSOCK(st.st_mode)) return 0;
        }
    }
    return -1;
}

static int write_all(int fd, const char *buf, ssize_t n) {
    while (n > 0) {
        ssize_t w = write(fd, buf, (size_t)n);
        if (w < 0) {
            if (errno == EINTR) continue;
            return -1;
        }
        buf += w;
        n -= w;
    }
    return 0;
}

static void *session(void *arg) {
    int tcp = (int)(intptr_t)arg;
    char path[1100];
    if (find_socket(path, sizeof path) != 0) {
        logf_("Discord socket not found - is the Discord app open?%s", NULL);
        close(tcp);
        return NULL;
    }
    int ux = socket(AF_UNIX, SOCK_STREAM, 0);
    struct sockaddr_un sa = {0};
    sa.sun_family = AF_UNIX;
    snprintf(sa.sun_path, sizeof sa.sun_path, "%s", path);
    if (ux < 0 || connect(ux, (struct sockaddr *)&sa, sizeof sa) != 0) {
        logf_("could not connect to %s", path);
        if (ux >= 0) close(ux);
        close(tcp);
        return NULL;
    }
    logf_("game connected, bridging to %s", path);

    struct pollfd p[2] = {{tcp, POLLIN, 0}, {ux, POLLIN, 0}};
    char *buf = malloc(BUF);
    for (;;) {
        if (poll(p, 2, -1) < 0) {
            if (errno == EINTR) continue;
            break;
        }
        int done = 0;
        for (int i = 0; i < 2 && !done; i++) {
            if (!(p[i].revents & (POLLIN | POLLHUP | POLLERR))) continue;
            ssize_t r = read(p[i].fd, buf, BUF);
            if (r <= 0 || write_all(p[1 - i].fd, buf, r) != 0) done = 1;
        }
        if (done) break;
    }
    free(buf);
    close(ux);
    close(tcp);
    logf_("game disconnected%s", NULL);
    return NULL;
}

int main(void) {
    signal(SIGPIPE, SIG_IGN);
    int srv = socket(AF_INET, SOCK_STREAM, 0);
    int one = 1;
    setsockopt(srv, SOL_SOCKET, SO_REUSEADDR, &one, sizeof one);
    struct sockaddr_in a = {0};
    a.sin_family = AF_INET;
    a.sin_port = htons(PORT);
    a.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    if (bind(srv, (struct sockaddr *)&a, sizeof a) != 0 || listen(srv, 8) != 0) {
        logf_("port 6473 is busy - is another relay already running?%s", NULL);
        // Sleep so launchd's KeepAlive doesn't respawn us in a tight loop.
        sleep(30);
        return 1;
    }
    logf_("listening on 127.0.0.1:6473%s", NULL);
    for (;;) {
        int c = accept(srv, NULL, NULL);
        if (c < 0) {
            if (errno == EINTR) continue;
            sleep(1);
            continue;
        }
        pthread_t t;
        if (pthread_create(&t, NULL, session, (void *)(intptr_t)c) == 0)
            pthread_detach(t);
        else
            close(c);
    }
}
