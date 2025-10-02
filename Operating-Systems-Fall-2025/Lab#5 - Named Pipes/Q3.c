#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/shm.h>
#include <sys/wait.h>
#include <time.h>

int main()
{
    int N = 100;
    int M = 4;

    size_t size = (N + M + 1) * sizeof(int);

    // Create shared memory segment
    int shmid = shmget(IPC_PRIVATE, size, IPC_CREAT | 0666);
    if (shmid < 0)
    {
        perror("shmget");
        exit(1);
    }

    // Attach shared memory
    int *shm = (int *)shmat(shmid, NULL, 0);
    if (shm == (int *)-1)
    {
        perror("shmat");
        shmctl(shmid, IPC_RMID, NULL);
        exit(1);
    }

    int *array = shm;
    int *partial_sums = shm + N;
    int *final_sum = shm + N + M;

    // Initialize array with random values
    srand(time(NULL));
    for (int i = 0; i < N; i++)
    {
        array[i] = rand() % 100;
    }

    for (int i = 0; i < M; i++)
    {
        partial_sums[i] = 0;
    }
    *final_sum = 0;

    // Fork M child processes for partial sum computation
    int chunk = N / M;
    for (int i = 0; i < M; i++)
    {
        pid_t pid = fork();
        if (pid < 0)
        {
            perror("fork");
            shmdt(shm);
            shmctl(shmid, IPC_RMID, NULL);
            exit(1);
        }
        if (pid == 0)
        {
            // Child process: compute partial sum
            int start = i * chunk;
            int end = (i == M - 1) ? N : (start + chunk);
            int sum = 0;
            for (int j = start; j < end; j++)
            {
                sum += array[j];
            }
            partial_sums[i] = sum;

            // Detach and exit
            shmdt(shm);
            exit(0);
        }
    }

    for (int i = 0; i < M; i++)
    {
        wait(NULL);
    }

    // Parent aggregates partial sums
    int total_sum = 0;
    for (int i = 0; i < M; i++)
    {
        total_sum += partial_sums[i];
    }
    *final_sum = total_sum;

    printf("Final sum: %d\n", *final_sum);

    shmdt(shm);
    shmctl(shmid, IPC_RMID, NULL);

    return 0;
}
