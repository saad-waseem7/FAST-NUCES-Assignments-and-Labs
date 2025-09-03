#include <stdio.h>
#include <unistd.h>
#include <sys/wait.h>

int main()
{
    pid_t pid;

    // Child 1 - pwd
    pid = fork();
    if (pid == 0)
    {
        execlp("pwd", "pwd", NULL);
        perror("execlp failed");
        return 1;
    }

    // Child 2 - date
    pid = fork();
    if (pid == 0)
    {
        execlp("date", "date", NULL);
        perror("execlp failed");
        return 1;
    }

    // Child 3 - ls
    pid = fork();
    if (pid == 0)
    {
        execlp("ls", "ls", NULL);
        perror("execlp failed");
        return 1;
    }

    // Parent waits for all children
    for (int i = 0; i < 3; i++)
    {
        wait(NULL);
    }
    printf("Parent: All children finished.\n");
    return 0;
}
