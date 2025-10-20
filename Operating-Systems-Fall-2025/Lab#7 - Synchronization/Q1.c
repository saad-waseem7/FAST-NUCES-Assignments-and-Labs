#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <semaphore.h>
#include <unistd.h>

#define buffer_size 5 // size of the buffer

int buffer[buffer_size];
int in = 0;  // index for next produced item
int out = 0; // index for next consumed item

// Semaphores
sem_t empty;           // counts empty slots
sem_t full;            // counts full slots
pthread_mutex_t mutex; // protects buffer access  

void *producer(void *arg)
{
    int item;
    for (int i = 0; i < 10; i++)
    {                        // each producer makes 10 items
        item = rand() % 100; // produce a random number

        sem_wait(&empty);           // wait if buffer is full
        pthread_mutex_lock(&mutex); // lock the buffer

        buffer[in] = item;
        printf("Producer produced: %d\n", item);
        in = (in + 1) % buffer_size;

        pthread_mutex_unlock(&mutex); // unlock buffer
        sem_post(&full);              // signal that buffer has more data

        sleep(1); // simulate time to produce
    }
    return NULL;
}

void *consumer(void *arg)
{
    int item;
    for (int i = 0; i < 10; i++)
    {                               // each consumer consumes 10 items
        sem_wait(&full);            // wait if buffer is empty
        pthread_mutex_lock(&mutex); // lock the buffer

        item = buffer[out];
        printf("Consumer consumed: %d\n", item);
        out = (out + 1) % buffer_size;

        pthread_mutex_unlock(&mutex); // unlock buffer
        sem_post(&empty);             // signal that buffer has empty space

        sleep(1); // simulate time to consume
    }
    return NULL;
}

int main()
{
    pthread_t prodThread, consThread;

    // initialize semaphores and mutex
    sem_init(&empty, 0, buffer_size);
    sem_init(&full, 0, 0);
    pthread_mutex_init(&mutex, NULL);

    // create threads
    pthread_create(&prodThread, NULL, producer, NULL);
    pthread_create(&consThread, NULL, consumer, NULL);

    // wait for threads to finish
    pthread_join(prodThread, NULL);
    pthread_join(consThread, NULL);

    // cleanup
    sem_destroy(&empty);
    sem_destroy(&full);
    pthread_mutex_destroy(&mutex);

    printf("All done.\n");
    return 0;
}
