#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/wait.h>
#include <time.h>

int main()
{
    srand(time(0));

    int status;
    pid_t pid;

    printf("--- Dough Preparation ---\n");

    pid = fork();
    if (pid == 0)
    {
        printf("Kneading complete.\n");
        exit(0);
    }
    else
    {
        wait(&status);
    }

    pid = fork();
    if (pid == 0)
    {
        printf("Rolling complete.\n");
        exit(0);
    }
    else
    {
        wait(&status);
    }

    printf("--- Topping Placement ---\n");

    pid = fork();
    if (pid == 0)
    {
        printf("Sauce spread.\n");
        exit(0);
    }
    else
    {
        wait(&status);
    }

    pid = fork();
    if (pid == 0)
    {
        printf("Toppings added.\n");
        exit(0);
    }
    else
    {
        wait(&status);
    }

    printf("--- Baking Stage ---\n");
    int bakingSuccess = 0;

    for (int attempt = 1; attempt <= 2; attempt++)
    {
        pid = fork();
        if (pid == 0)
        {
            int result = rand() % 2;
            if (result == 0)
            {
                printf("Baking attempt %d: FAILED (burnt pizza)\n", attempt);
                exit(1);
            }
            else
            {
                printf("Baking attempt %d: SUCCESS\n", attempt);
                exit(0);
            }
        }
        else
        {
            wait(&status);
            if (status == 0)
            {
                bakingSuccess = 1;
                break;
            }
        }
    }

    if (!bakingSuccess)
    {
        printf("Kitchen shut down. Order cancelled. Customer left hungry.\n");
        return 0;
    }

    printf("Pizza is ready and delivered to the customer!\n");
    return 0;
}