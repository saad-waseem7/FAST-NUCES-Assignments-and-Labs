#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <unistd.h>

#define num_philosophers 5

pthread_mutex_t forks[num_philosophers];

void think(int id)
{
    printf("Philosopher %d is thinking.\n", id);
    sleep(rand() % 2 + 1); // think for 1-2 seconds
}

void eat(int id)
{
    printf("Philosopher %d is eating.\n", id);
    sleep(rand() % 2 + 1); // eat for 1-2 seconds
}

void *philosopher(void *num)
{
    int id = *(int *)num;
    int leftFork = id;
    int rightFork = (id + 1) % num_philosophers;

    // To avoid deadlock: always pick lower-numbered fork first
    int firstFork = leftFork < rightFork ? leftFork : rightFork;
    int secondFork = leftFork < rightFork ? rightFork : leftFork;

    for (int i = 0; i < 3; i++)
    { // each philosopher eats 3 times
        think(id);

        // Pick up forks
        pthread_mutex_lock(&forks[firstFork]);
        pthread_mutex_lock(&forks[secondFork]);

        eat(id);

        // Put down forks
        pthread_mutex_unlock(&forks[secondFork]);
        pthread_mutex_unlock(&forks[firstFork]);
    }

    printf("Philosopher %d is done eating.\n", id);
    return NULL;
}

int main()
{
    pthread_t philosophers[num_philosophers];
    int ids[num_philosophers];

    srand(time(NULL)); // seed random

    // Initialize mutexes (forks)
    for (int i = 0; i < num_philosophers; i++)
    {
        pthread_mutex_init(&forks[i], NULL);
    }

    // Create philosopher threads
    for (int i = 0; i < num_philosophers; i++)
    {
        ids[i] = i;
        pthread_create(&philosophers[i], NULL, philosopher, &ids[i]);
    }

    // Wait for all philosophers to finish
    for (int i = 0; i < num_philosophers; i++)
    {
        pthread_join(philosophers[i], NULL);
    }

    // Destroy mutexes
    for (int i = 0; i < num_philosophers; i++)
    {
        pthread_mutex_destroy(&forks[i]);
    }

    printf("All philosophers are done.\n");
    return 0;
}
