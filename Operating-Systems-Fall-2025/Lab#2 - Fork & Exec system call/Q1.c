#include <stdio.h>
#include <unistd.h>

int counter = 0; // Global counter

int main()
{
    pid_t pid = fork(); // Create a child process

    if (pid < 0)
    {
        perror("fork failed");
        return 1;
    }

    if (pid == 0)
    { // Child process
        for (int i = 0; i < 5; i++)
        {
            counter++;
            printf("Child: counter = %d\n", counter);
            sleep(1);
        }
    }
    else
    { // Parent process
        for (int i = 0; i < 5; i++)
        {
            counter++;
            printf("Parent: counter = %d\n", counter);
            sleep(1);
        }
    }
    return 0;
}

/*
Why values differ:
Parent and child have separate memory after fork(),
so 'counter' is copied, not shared. Each process changes its own copy.
*/
