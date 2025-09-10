#include <stdio.h>
#include <sys/types.h> // for pid type
#include <sys/wait.h>  // for wait command
#include <unistd.h>    // for fork()

int main()
{
    pid_t pid;
    pid = fork(); // Create a new child process
    if (pid == -1)
    {
        perror("Fork failed"); // Handle error if fork() fails
        return 1;
    }
    if (pid == 0)
    {
        printf("\nC1 child process, child PID = %d, C1 parent PID = %d\n", getpid(), getppid());
        pid = fork(); // Create a new child process
        if (pid == -1)
        {
            perror("Fork failed"); // Handle error if fork() fails
            return 1;
        }
        if (pid == 0)
        {
            printf("\nGC1 child process, GC1 child PID = %d, GC1 parent PID = %d\n", getpid(), getppid());
        }
        else
        {
            wait(NULL);
            printf("\nGC2 child process, PID = %d, GC2 parent PID = %d\n", getpid(), getppid());
        }
    }
    else
    {
        printf("P process, PID = %d", getpid());
    }
    return 0;
}