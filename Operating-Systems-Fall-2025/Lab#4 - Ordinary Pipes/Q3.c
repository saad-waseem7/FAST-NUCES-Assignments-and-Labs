#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/wait.h>

int main()
{
    int fd[2];
    pipe(fd);


    if (fork() == 0)
    {
        dup2(fd[1], STDOUT_FILENO); 
        close(fd[0]);
        close(fd[1]);
        execlp("ls", "ls", "-l", NULL);
        perror("execlp ls failed");
        exit(1);
    }

    if (fork() == 0)
    {
        int out = open("c_files.txt", O_WRONLY | O_CREAT | O_TRUNC, 0644);
        if (out < 0)
        {
            perror("open c_files.txt failed");
            exit(1);
        }
        dup2(fd[0], STDIN_FILENO); 
        dup2(out, STDOUT_FILENO);  
        close(fd[0]);
        close(fd[1]);
        close(out);
        execlp("grep", "grep", ".c", NULL);
        perror("execlp grep failed");
        exit(1);
    }

    close(fd[0]);
    close(fd[1]);
    wait(NULL);
    wait(NULL);

    return 0;
}
