#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/wait.h>

int main(int argc, char *argv[])
{
    if (argc != 2)
    {
        printf("Usage: %s <number>\n", argv[0]);
        return 1;
    }

    int N = atoi(argv[1]); 
    int fd1[2], fd2[2]; 
    pipe(fd1);
    pipe(fd2);

    pid_t pid1 = fork(); 

    if (pid1 == 0)a
    {
        close(fd1[0]);
        int sum = 0;
        for (int i = 1; i <= N / 4; i++)
        {
            if (N % i == 0)
            {
                sum += i;
            }
        }
        write(fd1[1], &sum, sizeof(sum));
        close(fd1[1]);
        exit(0);
    }

    pid_t pid2 = fork(); 

    if (pid2 == 0)
    {
        close(fd2[0]);
        int sum = 0;
        for (int i = (N / 4) + 1; i <= N / 2; i++)
        {
            if (N % i == 0)
            {
                sum += i;
            }
        }
        write(fd2[1], &sum, sizeof(sum));
        close(fd2[1]);
        exit(0);
    }

    close(fd1[1]);
    close(fd2[1]);

    int sum1, sum2;
    read(fd1[0], &sum1, sizeof(sum1));
    read(fd2[0], &sum2, sizeof(sum2));

    close(fd1[0]);
    close(fd2[0]);

    wait(NULL);
    wait(NULL);

    int total_sum = sum1 + sum2;

    if (total_sum == N)
    {
        printf("true\n"); 
    }
    else
    {
        printf("false\n"); 
    }

    return 0;
}
