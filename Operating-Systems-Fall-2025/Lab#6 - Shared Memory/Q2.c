#include <stdio.h>
#include <pthread.h>
#include <semaphore.h>
#include <unistd.h>

#define N 5 // number of threads

sem_t inSem[N];  // semaphores for "I am in"
sem_t outSem[N]; // semaphores for "I am out"

void *threadFunc(void *p)
{
    int n = *(int *)p;

    while (1)
    {
        // Wait for my turn to say "I am in"
        sem_wait(&inSem[n - 1]);
        printf("I am in %d\n", n);
        fflush(stdout);

        // Signal the next thread to print "I am in"
        if (n < N)
            sem_post(&inSem[n]); // let next thread print "I am in"
        else
            sem_post(&outSem[0]); // after 5th "in", start "out" sequence

        // Wait for my turn to say "I am out"
        sem_wait(&outSem[n - 1]);
        printf("I am out %d\n", n);
        fflush(stdout);

        // Signal the next thread to print "I am out"
        if (n < N)
            sem_post(&outSem[n]); // let next thread print "I am out"
        else
            sem_post(&inSem[0]); // after 5th "out", start next "in" cycle
    }

    return NULL;
}

int main()
{
    pthread_t threads[N];
    int ids[N];

    // Initialize semaphores
    for (int i = 0; i < N; i++)
    {
        sem_init(&inSem[i], 0, 0);
        sem_init(&outSem[i], 0, 0);
    }

    // Start first "I am in" cycle with thread 1
    sem_post(&inSem[0]);

    // Create 5 threads
    for (int i = 0; i < N; i++)
    {
        ids[i] = i + 1;
        pthread_create(&threads[i], NULL, threadFunc, &ids[i]);
    }

    // Join threads (though they'll run forever)
    for (int i = 0; i < N; i++)
    {
        pthread_join(threads[i], NULL);
    }

    return 0;
}
