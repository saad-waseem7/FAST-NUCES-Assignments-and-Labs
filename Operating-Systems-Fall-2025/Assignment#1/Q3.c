#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/wait.h>

int allowed(const char *cmd)
{
    return (!strcmp(cmd, "ls") || !strcmp(cmd, "cat") ||
            !strcmp(cmd, "date") || !strcmp(cmd, "uptime"));
}

int main()
{
    char *line = NULL;
    size_t len = 0;

    printf("Secure IoT Shell (type 'exit' to quit)\n");

    while (1)
    {
        printf("Enter Command: ");
        fflush(stdout);

        if (getline(&line, &len, stdin) == -1)
            break;

        line[strcspn(line, "\n")] = 0;
        if (strlen(line) == 0)
            continue;

        char cmd_copy[60];
        strcpy(cmd_copy, line);
        for (int i = 0; cmd_copy[i] != '\0'; i++)
        {
            if (cmd_copy[i] >= 'A' && cmd_copy[i] <= 'Z')
            {
                cmd_copy[i] = cmd_copy[i] + 32;
            }
        }

        if (strcmp(cmd_copy, "exit") == 0)
        {
            printf("Goodbye. Secure shell terminated.\n");
            break;
        }

        char *argv[30];
        int argc = 0;
        char *token = strtok(line, " \t");
        while (token && argc < 31)
        {
            argv[argc++] = token;
            token = strtok(NULL, " \t");
        }
        argv[argc] = NULL;

        if (!argv[0])
            continue;
        for (int i = 0; argv[0][i] != '\0'; i++)
        {
            if (argv[0][i] >= 'A' && argv[0][i] <= 'Z')
            {
                argv[0][i] = argv[0][i] + 32;
            }
        }

        if (!allowed(argv[0]))
        {
            printf("Command not permitted.\n");
            continue;
        }

        printf("Executing: %s\n", argv[0]);

        pid_t pid = fork();
        if (pid == 0)
        {
            execvp(argv[0], argv);
            perror("Execution failed");
            _exit(1);
        }
        else if (pid > 0)
        {
            int status;
            waitpid(pid, &status, 0);
        }
        else
        {
            perror("fork");
        }
    }

    free(line);
    return 0;
}
