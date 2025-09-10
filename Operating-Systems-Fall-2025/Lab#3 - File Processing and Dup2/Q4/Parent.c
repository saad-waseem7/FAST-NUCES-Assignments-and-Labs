#include <stdio.h>
#include <sys/types.h> // for pid type
#include <sys/wait.h>  // for wait command
#include <unistd.h>    // for fork()

int main()
{
    FILE *fp;
    char ch;
    pid_t pid;
    pid = fork();
    if (pid == -1)
    {
        perror("Fork failed");
        return 1;
    }
    if (pid == 0)
    {
        fp = fopen("output1.txt", "w");
        int newfd;
        int dup2(int fp, int newfd);
        char *args[] = {"ls", "-l", NULL};
        execvp("./run_", args);
    }
    else
    {
        wait(NULL);
        fp = fopen("output1.txt", "r");
        while ((ch = getc(fp)) != EOF)
            printf("%c", ch);
        fclose(fp);
    }
    return 0;
}