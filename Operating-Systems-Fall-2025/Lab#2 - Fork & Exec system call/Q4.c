#include <stdio.h>
#include <unistd.h>
#include <sys/wait.h>

int main()
{
    pid_t pid = fork();

    if (pid == 0)
    {
        execlp("cat", "cat", "file.txt", NULL);
        perror("execlp failed");
    }
    else
    {
        wait(NULL);
        printf("Parent: Child finished running cat.\n");
    }
    return 0;
}
