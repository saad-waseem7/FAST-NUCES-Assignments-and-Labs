#include <stdio.h>
#include <pthread.h>

// Thread 1: Print numbers from 1 to 10
void *print_numbers(void *arg)
{
    for (int i = 1; i <= 10; i++)
    {
        printf("Number: %d\n", i);
    }
    return NULL;
}

// Thread 2: Print first 10 Fibonacci numbers
void *print_fibonacci(void *arg)
{
    int a = 0, b = 1;
    printf("Fibonacci: %d\n", a);
    printf("Fibonacci: %d\n", b);
    for (int i = 2; i < 10; i++)
    {
        int next = a + b;
        printf("Fibonacci: %d\n", next);
        a = b;
        b = next;
    }
    return NULL;
}

int is_prime(int n)
{
    if (n <= 1)
        return 0;
    for (int i = 2; i * i <= n; i++)
    {
        if (n % i == 0)
            return 0;
    }
    return 1;
}

// Thread 3: Print first 10 prime numbers
void *print_primes(void *arg)
{
    int count = 0, num = 2;
    while (count < 10)
    {
        if (is_prime(num))
        {
            printf("Prime: %d\n", num);
            count++;
        }
        num++;
    }
    return NULL;
}

int main()
{
    pthread_t thread1, thread2, thread3;

    // Create threads
    pthread_create(&thread1, NULL, print_numbers, NULL);
    pthread_create(&thread2, NULL, print_fibonacci, NULL);
    pthread_create(&thread3, NULL, print_primes, NULL);

    // Wait for threads to complete
    pthread_join(thread1, NULL);
    pthread_join(thread2, NULL);
    pthread_join(thread3, NULL);

    return 0;
}
