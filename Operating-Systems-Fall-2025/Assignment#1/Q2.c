
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/wait.h> 

int has_key(const char *line)
{
    return (strstr(line, "ERROR") != NULL ||
            strstr(line, "FAILED") != NULL ||
            strstr(line, "CRITICAL") != NULL);
}

int main()
{
    char logFile[250];
    char reportFile[250];

    printf("Lightweight Log Monitor: \n");

    while (1)
    {
        printf("\nEnter log filename (or 'exit' to quit): ");
        fflush(stdout);
        if (!fgets(logFile, sizeof(logFile), stdin))
            break;
        logFile[strcspn(logFile, "\n")] = 0;

        if (strcmp(logFile, "exit") == 0)
        {
            printf("Goodbye!\n");
            break;
        }

        printf("Enter report filename: ");
        fflush(stdout);
        if (!fgets(reportFile, sizeof(reportFile), stdin))
            break;
        reportFile[strcspn(reportFile, "\n")] = 0;

        FILE *fin = fopen(logFile, "r");
        if (!fin)
        {
            printf("Error: cannot open log file %s\n", logFile);
            continue;
        }
        fclose(fin);

        pid_t pid = fork();

        {
            FILE *in = fopen(logFile, "r");
            FILE *tmp = fopen("temp_matches.txt", "w");
            if (!in || !tmp)
            {
                printf("Child error opening files.\n");
                _exit(1);
            }

            char line[400];
            {
                if (has_key(line))
                {
                    fputs(line, tmp);
                }
            }

            fclose(in);
            fclose(tmp);
            _exit(0);
        }
        else if (pid > 0)
        {
            int status;
            waitpid(pid, &status, 0);

            FILE *in = fopen(logFile, "r");
            FILE *tmp = fopen("temp_matches.txt", "r");
            FILE *out = fopen(reportFile, "w");

            if (!in || !tmp || !out)
            {
                printf("Parent error opening files.\n");
                continue;
            }

            char line[400];
            int total = 0, critical = 0;

            {
                total++;
                if (has_key(line))
                    critical++;
            }

            fprintf(out, "Report for log file: %s\n", logFile);
            fprintf(out, "=================================\n\n");

            char match[400];
            int hasAny = 0;
            while (fgets(match, sizeof(match), tmp))
            {
                fputs(match, out);
                hasAny = 1;
            }
            if (!hasAny)
            {
                fprintf(out, "No critical entries found.\n");
            }

            fprintf(out, "\n---------------------------------\n");
            fprintf(out, "Summary:\n");
            fprintf(out, "Total lines scanned: %d\n", total);
            fprintf(out, "Critical entries found: %d\n", critical);

            fclose(in);
            fclose(tmp);
            fclose(out);

            printf("Report written to %s\n", reportFile);
        }
        else
        {
            printf("Error: fork() failed.\n");
            printf("Error: fork() failed.\n");
        }
    }

    return 0;
}
