#include <stdio.h>
#include <unistd.h>
#include <sys/wait.h>

int main()
{
    pid_t pid = fork();

    if (pid == 0)
    {
        printf("Child (PID: %d) exiting.\n", getpid());
        return 0; // Child exits immediately
    }
    else
    {
        printf("Parent (PID: %d) sleeping, child becomes zombie.\n", getpid());
        sleep(20);  // Child is zombie here (use ps command)
        wait(NULL); // Fix zombie
        printf("Parent collected child. Zombie gone.\n");
    }
    return 0;
}
