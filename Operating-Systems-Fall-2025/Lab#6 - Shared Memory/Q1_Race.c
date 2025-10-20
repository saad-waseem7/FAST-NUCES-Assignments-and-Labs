// Without Synchronization (Race Condition)

#include <stdio.h>
#include <pthread.h>
#include <unistd.h>

int balance = 1000; // shared variable

void *withdraw(void *arg)
{
    int amount = *(int *)arg;

    printf("Trying to withdraw %d...\n", amount);

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

    return NULL;
}

int main()
{
    pthread_t t1, t2;
    int amt1 = 700, amt2 = 700;

    pthread_create(&t1, NULL, withdraw, &amt1);
    pthread_create(&t2, NULL, withdraw, &amt2);
    
    pthread_join(t1, NULL);
    pthread_join(t2, NULL);

    printf("Final balance: %d\n", balance);
    return 0;
}
