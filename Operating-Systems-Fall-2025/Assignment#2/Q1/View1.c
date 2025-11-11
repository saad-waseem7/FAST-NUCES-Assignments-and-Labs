#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <sys/select.h>

#define fifo_send "/tmp/fifo1to2"
#define fifo_recv "/tmp/fifo2to1"
#define window 10

void show_lines(int start) {
    FILE *fp = fopen("inputAssign-2.txt", "r");
    if (!fp) { perror("file"); exit(1); }

    system("clear");
    printf("--- Viewer 1 ---\n");

    char line[256];
    int line_no = 0;

    while (fgets(line, sizeof(line), fp)) {
        if (line_no >= start && line_no < start + window)
            printf("%s", line);
        line_no++;
        if (line_no >= start + window) break;
    }

    fclose(fp);
    printf("\nCommands: d=down, u=up, x=exit\n> ");
    fflush(stdout);
}

int count_lines() {
    FILE *fp = fopen("inputAssign-2.txt", "r");
    if (!fp) { perror("file"); exit(1); }

    int count = 0;
    char temp[256];
    while (fgets(temp, sizeof(temp), fp)) count++;
    fclose(fp);
    return count;
}

int main() {
    mkfifo(fifo_send, 0666);
    mkfifo(fifo_recv, 0666);

    int fdSend = open(fifo_send, O_RDWR);
    int fdRecv = open(fifo_recv, O_RDWR);
    if (fdSend < 0 || fdRecv < 0) { perror("fifo"); exit(1); }

    int total = count_lines();
    int top = 0;
    char cmd;
    show_lines(top);

    fd_set set;
    while (1) {
        FD_ZERO(&set);
        FD_SET(0, &set);
        FD_SET(fdRecv, &set);
        int maxfd = fdRecv + 1;

        select(maxfd, &set, NULL, NULL, NULL);

        if (FD_ISSET(fdRecv, &set)) {
            if (read(fdRecv, &cmd, 1) > 0) {
                if (cmd == 'd' && top + window < total) top++;
                else if (cmd == 'u' && top > 0) top--;
                else if (cmd == 'x') break;
                show_lines(top);
            }
        }

        if (FD_ISSET(0, &set)) {
            cmd = getchar();
            if (cmd == '\n') continue;

            if (cmd == 'd' && top + window < total) top++;
            else if (cmd == 'u' && top > 0) top--;
            else if (cmd == 'x') {
                write(fdSend, &cmd, 1);
                break;
            }

            write(fdSend, &cmd, 1);
            show_lines(top);
        }
    }

    close(fdSend);
    close(fdRecv);
    unlink(fifo_send);
    unlink(fifo_recv);
    return 0;
}
