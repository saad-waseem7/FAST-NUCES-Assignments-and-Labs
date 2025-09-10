#include <stdio.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/wait.h>

int main()
{
    pid_t pid = fork();
    if (pid < 0)
    {
        perror("fork failed");
        return 1;
    }
    else if (pid == 0)
    {
        execlp("./task_run", "./task_run", NULL);
        return 1;
    }
    else
    {
        wait(NULL);
        printf("Child process finished execution\n");
    }
    return 0;
}