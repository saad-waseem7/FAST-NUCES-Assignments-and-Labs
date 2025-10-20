#include <stdio.h>
#include <pthread.h>
#include <unistd.h>

int balance = 1000;   // shared variable
pthread_mutex_t lock; // mutex lock

void *withdraw(void *arg)
{
    int amount = *(int *)arg;

    printf("Trying to withdraw %d...\n", amount);

    pthread_mutex_lock(&lock); // lock the balance

    if (balance >= amount)
    {
        printf("Balance before withdrawal: %d\n", balance);
        sleep(1); // simulate delay
        balance = balance - amount;
        printf("Withdrawal of %d done. Balance left: %d\n", amount, balance);
    }
    else
    {
        printf("Not enough balance for %d\n", amount);
    }

    pthread_mutex_unlock(&lock); // unlock the balance

    return NULL;
}

int main()
{
    pthread_t t1, t2;
    int amt1 = 700, amt2 = 700;

    pthread_mutex_init(&lock, NULL); // initialize mutex

    pthread_create(&t1, NULL, withdraw, &amt1);
    pthread_create(&t2, NULL, withdraw, &amt2);

    pthread_join(t1, NULL);
    pthread_join(t2, NULL);

    pthread_mutex_destroy(&lock);
    printf("Final balance: %d\n", balance);
    return 0;
}
