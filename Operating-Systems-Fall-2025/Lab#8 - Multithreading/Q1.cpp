#include <iostream>
#include <fstream>
#include <unistd.h>
#include <sys/wait.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <vector>
using namespace std;

int *array = new int[10];
pthread_mutex_t mute;

void *ticket(void *arg)
{
    int id = *((int *)arg);
    pthread_mutex_lock(&mute);

    int i;
    for (i = 0; i < 10; i++)
    {
        if (::array[i] == 0)
        {
            ::array[i] = id;
            cout << "Customer " << id << " booked ticket number " << i + 1 << endl;
            break;
        }
    }

    if (i == 10)
    {
        cout << "Customer " << id << " could not book a ticket." << endl;
    }

    pthread_mutex_unlock(&mute);
    return nullptr;
}

int main()
{

    // Initialize mutex
    pthread_mutex_init(&mute, NULL);

    // Initialize all tickets to 0 (available)
    for (int i = 0; i < 10; ++i)
    {
        ::array[i] = 0;
    }

    pthread_t threads[15];
    int id[15];

    // make 15 threads (customers)
    for (int i = 0; i < 15; i++)
    {
        id[i] = i + 1;
        pthread_create(&threads[i], NULL, ticket, (void *)&id[i]);
    }

    for (int i = 0; i < 15; ++i)
    {
        pthread_join(threads[i], nullptr);
    }

    pthread_mutex_destroy(&mute);
    delete[] ::array;
    return 0;
}
