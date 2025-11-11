#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/wait.h>

int main(int argc, char *argv[])
{
    if (argc < 2)
    {
        fprintf(stderr, "Usage: %s \"cmd1 args\" \"cmd2 args\" ...\n", argv[0]);
        return 1;
    }

    int i;
    int in_fd = 0;
    for (i = 1; i < argc; i++)
    {
        int pipefd[2];
        if (i < argc - 1)
        {
            if (pipe(pipefd) == -1)
            {
                perror("pipe");
                exit(1);
            }
        }

        pid_t pid = fork();
        if (pid < 0)
        {
            perror("fork");
            exit(1);
        }

        if (pid == 0)
        {
            if (in_fd != 0)
            {
                dup2(in_fd, STDIN_FILENO);
                close(in_fd);
            }

            if (i < argc - 1)
            {
                dup2(pipefd[1], STDOUT_FILENO);
                close(pipefd[0]);
                close(pipefd[1]);
            }

            char *cmd = argv[i];
            char *args[50];
            int k = 0;
            char *token = strtok(cmd, " ");
            while (token != NULL && k < 49)
            {
                args[k++] = token;
                token = strtok(NULL, " ");
            }
            args[k] = NULL;

            execvp(args[0], args);
            perror("execvp");
            exit(1);
        }
        else
        {
            wait(NULL);
            if (in_fd != 0)
                close(in_fd);

            if (i < argc - 1)
            {
                close(pipefd[1]);
                in_fd = pipefd[0];
            }
        }
    }
    return 0;
}