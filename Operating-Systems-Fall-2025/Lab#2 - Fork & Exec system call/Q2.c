#include <stdio.h>
#include <unistd.h>
#include <sys/wait.h>

int main()
{
    pid_t pid1, pid2, pid3;

    // First child
    pid1 = fork();
    if (pid1 == 0)
    {
        printf("Child 1 (PID: %d, Parent: %d)\n", getpid(), getppid());
        return 0;
    }

    // Second child
    pid2 = fork();
    if (pid2 == 0)
    {
        printf("Child 2 (PID: %d, Parent: %d)\n", getpid(), getppid());
        return 0;
    }

    // Third child
    pid3 = fork();
    if (pid3 == 0)
    {
        printf("Child 3 (PID: %d, Parent: %d)\n", getpid(), getppid());
        return 0;
    }

    // Parent waits for all children
    wait(NULL);
    wait(NULL);
    wait(NULL);

    printf("Parent (PID: %d) done.\n", getpid());
    return 0;
}

/*
Total processes: 8 if fork() is called consecutively without control.
Here we create exactly 3 child processes.
*/
