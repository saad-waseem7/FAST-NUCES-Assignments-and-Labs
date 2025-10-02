#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <ctype.h>

#define FIFO1 "/tmp/fifo1"
#define FIFO2 "/tmp/fifo2"

int main(int argc, char *argv[])
{
    if (argc != 2)
    {
        printf("Usage: %s filename\n", argv[0]);
        return 1;
    }

    mkfifo(FIFO1, 0666);
    mkfifo(FIFO2, 0666);

    FILE *f = fopen(argv[1], "r");
    if (!f)
    {
        perror("Cannot open file");
        return 1;
    }
    fseek(f, 0, SEEK_END);
    long size = ftell(f);
    fclose(f);

    long half = size / 2;

    pid_t p1 = fork();
    if (p1 == 0)
    {
        FILE *f1 = fopen(argv[1], "r");
        fseek(f1, 0, SEEK_SET);
        char *buf = malloc(half);
        fread(buf, 1, half, f1);
        fclose(f1);

        int count = 0, in_word = 0;
        for (int i = 0; i < half; i++)
        {
            if (isspace(buf[i]))
            {
                if (in_word)
                    count++;
                in_word = 0;
            }
            else
                in_word = 1;
        }
        if (in_word)
            count++;

        int fd = open(FIFO1, O_WRONLY);
        write(fd, &count, sizeof(count));
        close(fd);
        free(buf);
        exit(0);
    }

    pid_t p2 = fork();
    if (p2 == 0)
    {
        FILE *f2 = fopen(argv[1], "r");
        fseek(f2, half, SEEK_SET);
        char *buf = malloc(size - half);
        fread(buf, 1, size - half, f2);
        fclose(f2);

        int count = 0, in_word = 0;
        for (int i = 0; i < size - half; i++)
        {
            if (isspace(buf[i]))
            {
                if (in_word)
                    count++;
                in_word = 0;
            }
            else
                in_word = 1;
        }
        if (in_word)
            count++;

        int fd = open(FIFO2, O_WRONLY);
        write(fd, &count, sizeof(count));
        close(fd);
        free(buf);
        exit(0);
    }

    int count1 = 0, count2 = 0;
    int fd1 = open(FIFO1, O_RDONLY);
    int fd2 = open(FIFO2, O_RDONLY);
    read(fd1, &count1, sizeof(count1));
    read(fd2, &count2, sizeof(count2));
    close(fd1);
    close(fd2);

    wait(NULL);
    wait(NULL);

    printf("Total words: %d\n", count1 + count2);

    unlink(FIFO1);
    unlink(FIFO2);

    return 0;
}
