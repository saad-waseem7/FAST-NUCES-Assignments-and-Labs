#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/ipc.h>
#include <sys/shm.h>
#include <sys/sem.h>

#define SHM_KEY 0x1234
#define SEM_KEY 0x5678
#define TEMP_THRESHOLD 35.0 // alert limit

struct shared_data
{
    float temperature;
};

// Semaphore operations
void sem_lock(int semid)
{
    struct sembuf sb = {0, -1, 0}; // P operation
    semop(semid, &sb, 1);
}

void sem_unlock(int semid)
{
    struct sembuf sb = {0, 1, 0}; // V operation
    semop(semid, &sb, 1);
}

int main()
{
    int shmid, semid;
    struct shared_data *data;

    // Get shared memory
    shmid = shmget(SHM_KEY, sizeof(struct shared_data), 0666);
    if (shmid == -1)
    {
        perror("shmget");
        exit(1);
    }

    // Attach shared memory
    data = (struct shared_data *)shmat(shmid, NULL, 0);
    if (data == (void *)-1)
    {
        perror("shmat");
        exit(1);
    }

    // Get semaphore
    semid = semget(SEM_KEY, 1, 0666);
    if (semid == -1)
    {
        perror("semget");
        exit(1);
    }

    printf("Display started. Reading temperatures...\n");

    while (1)
    {
        sem_lock(semid); // lock before reading
        float temp = data->temperature;
        sem_unlock(semid);

        printf("Display: Current temperature = %.2f°C\n", temp);

        if (temp > TEMP_THRESHOLD)
            printf("⚠️ ALERT! Temperature %.2f°C exceeds threshold %.2f°C\n", temp, TEMP_THRESHOLD);

        sleep(1);
    }

    shmdt(data);
    return 0;
}
