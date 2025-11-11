#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <unistd.h>
#include <sys/wait.h>
#include <time.h>

double average = 0.0;

void *write_nums(void *arg)
{
    FILE *f = fopen("numbers.txt", "w");
    srand(time(NULL));

    for (int i = 0; i < 10; i++)
    {
        int num = rand() % 101;
        fprintf(f, "%d\n", num);
    }

    fclose(f);
    printf("Thread 1: Numbers written to file.\n");
    return NULL;
}

void *read_and_calc(void *arg)
{
    FILE *f = fopen("numbers.txt", "r");
    int num, sum = 0, count = 0;

    while (fscanf(f, "%d", &num) == 1)
    {
        sum += num;
        count++;
    }

    fclose(f);
    if (count > 0)
        average = (double)sum / count;

    printf("Thread 2: Sum = %d, Average = %.2f\n", sum, average);
    return NULL;
}

int main()
{
    pthread_t t1, t2;

    pthread_create(&t1, NULL, write_nums, NULL);
    pthread_join(t1, NULL);
    pthread_create(&t2, NULL, read_and_calc, NULL);
    pthread_join(t2, NULL);

    int fd[2];
    pipe(fd);

    pid_t pid = fork();

    if (pid == 0)
    {
        close(fd[1]);
        dup2(fd[0], STDIN_FILENO);
        close(fd[0]);
        execlp("./c1", "c1", NULL);
        perror("execlp failed");
        exit(1);
    }
    else
    {
        close(fd[0]);
        dprintf(fd[1], "%.2f\n", average);
        close(fd[1]);
        wait(NULL);
    }

    return 0;
}
