// pipebridge.exe - runs inside Wine.
// Serves \\.\pipe\discord-ipc-0 (what Windows games use for Discord RPC) and
// forwards each connection over TCP to 127.0.0.1:6473, where discord-relay.py
// passes it on to the real macOS Discord socket.
#include <winsock2.h>
#include <windows.h>
#include <stdio.h>

#define PIPE_NAME "\\\\.\\pipe\\discord-ipc-0"
#define RELAY_PORT 6473
#define BUF 65536

typedef struct {
    HANDLE pipe;
    SOCKET sock;
} conn_t;

static void log_msg(const char *m) {
    fprintf(stderr, "[pipebridge] %s\n", m);
    fflush(stderr);
}

// pipe -> socket
static DWORD WINAPI pipe_to_sock(LPVOID arg) {
    conn_t *c = (conn_t *)arg;
    char buf[BUF];
    OVERLAPPED ov = {0};
    ov.hEvent = CreateEventA(NULL, TRUE, FALSE, NULL);
    for (;;) {
        DWORD n = 0;
        ResetEvent(ov.hEvent);
        if (!ReadFile(c->pipe, buf, BUF, &n, &ov)) {
            if (GetLastError() != ERROR_IO_PENDING) break;
            if (!GetOverlappedResult(c->pipe, &ov, &n, TRUE)) break;
        }
        if (n == 0) break;
        DWORD off = 0;
        while (off < n) {
            int s = send(c->sock, buf + off, (int)(n - off), 0);
            if (s <= 0) goto done;
            off += (DWORD)s;
        }
    }
done:
    CloseHandle(ov.hEvent);
    shutdown(c->sock, SD_BOTH);
    return 0;
}

int main(void) {
    WSADATA wsa;
    if (WSAStartup(MAKEWORD(2, 2), &wsa) != 0) {
        log_msg("WSAStartup failed");
        return 1;
    }
    log_msg("started, serving " PIPE_NAME);

    for (;;) {
        HANDLE pipe = CreateNamedPipeA(PIPE_NAME,
            PIPE_ACCESS_DUPLEX | FILE_FLAG_OVERLAPPED,
            PIPE_TYPE_BYTE | PIPE_READMODE_BYTE | PIPE_WAIT,
            1, BUF, BUF, 0, NULL);
        if (pipe == INVALID_HANDLE_VALUE) {
            log_msg("CreateNamedPipe failed (another bridge running?)");
            return 1;
        }

        OVERLAPPED cov = {0};
        cov.hEvent = CreateEventA(NULL, TRUE, FALSE, NULL);
        BOOL ok = ConnectNamedPipe(pipe, &cov);
        if (!ok) {
            DWORD e = GetLastError();
            if (e == ERROR_IO_PENDING) {
                DWORD dummy;
                ok = GetOverlappedResult(pipe, &cov, &dummy, TRUE);
            } else if (e == ERROR_PIPE_CONNECTED) {
                ok = TRUE;
            }
        }
        CloseHandle(cov.hEvent);
        if (!ok) {
            CloseHandle(pipe);
            continue;
        }
        log_msg("game connected");

        SOCKET sock = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
        struct sockaddr_in addr = {0};
        addr.sin_family = AF_INET;
        addr.sin_port = htons(RELAY_PORT);
        addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
        if (sock == INVALID_SOCKET || connect(sock, (struct sockaddr *)&addr, sizeof(addr)) != 0) {
            log_msg("could not reach relay on 127.0.0.1:6473");
            if (sock != INVALID_SOCKET) closesocket(sock);
            DisconnectNamedPipe(pipe);
            CloseHandle(pipe);
            Sleep(1000);
            continue;
        }
        log_msg("relay connected");

        conn_t c = { pipe, sock };
        HANDLE t = CreateThread(NULL, 0, pipe_to_sock, &c, 0, NULL);

        // socket -> pipe
        char buf[BUF];
        OVERLAPPED wov = {0};
        wov.hEvent = CreateEventA(NULL, TRUE, FALSE, NULL);
        for (;;) {
            int n = recv(sock, buf, BUF, 0);
            if (n <= 0) break;
            DWORD w = 0;
            ResetEvent(wov.hEvent);
            if (!WriteFile(pipe, buf, (DWORD)n, &w, &wov)) {
                if (GetLastError() != ERROR_IO_PENDING) break;
                if (!GetOverlappedResult(pipe, &wov, &w, TRUE)) break;
            }
        }
        CloseHandle(wov.hEvent);

        // tear down: closing the pipe unblocks the reader thread
        CancelIoEx(pipe, NULL);
        DisconnectNamedPipe(pipe);
        WaitForSingleObject(t, 5000);
        CloseHandle(t);
        closesocket(sock);
        CloseHandle(pipe);
        log_msg("session closed");
    }
}
