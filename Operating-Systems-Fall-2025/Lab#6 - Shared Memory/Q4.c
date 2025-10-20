#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <semaphore.h>
#include <string.h>
#include <unistd.h>

#define max_len 100

char shared_data[max_len]; // shared memory

sem_t writer_sem;       // controls when writer can write
sem_t readers_sem[100]; // controls the order of readers
int n;                  // number of readers

void *writer_thread(void *arg)
{
    while (1)
    {
        // Wait until it's writer's turn
        sem_wait(&writer_sem);

        printf("\nWriter: Enter data to write: ");
        fflush(stdout);
        fgets(shared_data, max_len, stdin);

        // remove newline
        shared_data[strcspn(shared_data, "\n")] = '\0';

        // Signal first reader to start reading
        sem_post(&readers_sem[0]);
    }
    return NULL;
}

void *reader_thread(void *arg)
{
    int id = *(int *)arg;

    while (1)
    {
        sem_wait(&readers_sem[id - 1]); // wait for my turn

        printf("Reader %d read: %s\n", id, shared_data);
        fflush(stdout);
        sleep(1); // simulate reading delay

        // If I'm not the last reader, signal next reader
        if (id < n)
            sem_post(&readers_sem[id]);
        else
            sem_post(&writer_sem); // last reader signals writer
    }
    return NULL;
}

int main()
{
    pthread_t writer;
    pthread_t readers[100];
    int ids[100];

    printf("Enter number of readers: ");
    scanf("%d", &n);
    getchar(); // consume newline from input

    // Initialize semaphores
    sem_init(&writer_sem, 0, 1); // writer starts first
    for (int i = 0; i < n; i++)
        sem_init(&readers_sem[i], 0, 0); // readers blocked initially

    // Create writer thread
    pthread_create(&writer, NULL, writer_thread, NULL);

    // Create reader threads
    for (int i = 0; i < n; i++)
    {
        ids[i] = i + 1;
        pthread_create(&readers[i], NULL, reader_thread, &ids[i]);
    }

    // Wait for threads (they run forever)
    pthread_join(writer, NULL);
    for (int i = 0; i < n; i++)
        pthread_join(readers[i], NULL);

    return 0;
}
