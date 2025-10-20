#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/ipc.h>
#include <sys/shm.h>
#include <sys/sem.h>
#include <time.h>

#define SHM_KEY 0x1234
#define SEM_KEY 0x5678

struct shared_data {
    float temperature;
};

// Semaphore operations
void sem_lock(int semid) {
    struct sembuf sb = {0, -1, 0};  // P operation
    semop(semid, &sb, 1);
}

void sem_unlock(int semid) {
    struct sembuf sb = {0, 1, 0};   // V operation
    semop(semid, &sb, 1);
}

int main() {
    int shmid, semid;
    struct shared_data *data;

    // Create shared memory
    shmid = shmget(SHM_KEY, sizeof(struct shared_data), 0666 | IPC_CREAT);
    if (shmid == -1) {
        perror("shmget");
        exit(1);
    }

    // Attach shared memory
    data = (struct shared_data*) shmat(shmid, NULL, 0);
    if (data == (void*) -1) {
        perror("shmat");
        exit(1);
    }

    // Create semaphore
    semid = semget(SEM_KEY, 1, 0666 | IPC_CREAT);
    if (semid == -1) {
        perror("semget");
        exit(1);
    }

    // Initialize semaphore to 1 (unlocked)
    semctl(semid, 0, SETVAL, 1);

    srand(time(NULL));

    printf("Sensor started. Writing temperatures...\n");

    while (1) {
        float temp = (rand() % 4000) / 100.0;  // random temp between 0.00–40.00

        sem_lock(semid);       // lock before writing
        data->temperature = temp;
        sem_unlock(semid);     // unlock after writing

        printf("Sensor: Wrote temperature %.2f°C\n", temp);
        sleep(1);
    }

    // Detach and clean up (not reached in infinite loop)
    shmdt(data);
    shmctl(shmid, IPC_RMID, NULL);
    semctl(semid, 0, IPC_RMID);
    return 0;
}
