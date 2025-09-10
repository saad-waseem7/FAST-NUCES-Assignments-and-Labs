#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/wait.h>

int main()
{
    const char *filename = "output.txt";
    if (fork() == 0)
    {
        FILE *f = fopen(filename, "w");
        if (!f)
            exit(1);
        fprintf(f, "Hello from the child process!\nThis is some sample text.\n");
        fclose(f);
        exit(0);
    }
    else
    {
        wait(NULL);
        FILE *f = fopen(filename, "r");
        if (!f)
            return 1;
        char c;
        while ((c = fgetc(f)) != EOF)
            putchar(c);
        fclose(f);
    }
    return 0;
}