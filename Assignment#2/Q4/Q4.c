#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <time.h>

#define fifo_name "votes_fifo"
char candidates[] = {'A', 'B', 'C'};

void *voter(void *arg)
{
    srand(time(NULL) + (int)pthread_self());
    char vote = candidates[rand() % 3];

    int fd = open(fifo_name, O_WRONLY);
    if (fd != -1)
    {
        write(fd, &vote, 1);
        close(fd);
    }
    pthread_exit(NULL);
}

int main()
{
    int num_voters = 5;

    unlink(fifo_name);
    mkfifo(fifo_name, 0666);

    int fd = open(fifo_name, O_RDONLY | O_NONBLOCK);
    if (fd == -1)
    {
        perror("Failed to open FIFO");
        return 1;
    }

    pthread_t threads[num_voters];

    for (int i = 0; i < num_voters; i++)
        pthread_create(&threads[i], NULL, voter, NULL);

    sleep(1);

    int votesA = 0, votesB = 0, votesC = 0;
    char vote;
    printf("Receiving votes...\n");

    for (int i = 0; i < num_voters; i++)
    {
        if (read(fd, &vote, 1) > 0)
        {
            printf("Vote received for %c\n", vote);
            if (vote == 'A')
                votesA++;
            else if (vote == 'B')
                votesB++;
            else if (vote == 'C')
                votesC++;
        }
    }

    close(fd);
    unlink(fifo_name);

    printf("\n--- Results ---\n");
    printf("A: %d votes\n", votesA);
    printf("B: %d votes\n", votesB);
    printf("C: %d votes\n", votesC);

    if (votesA >= votesB && votesA >= votesC)
        printf("Winner: A\n");
    else if (votesB >= votesA && votesB >= votesC)
        printf("Winner: B\n");
    else
        printf("Winner: C\n");

    for (int i = 0; i < num_voters; i++)
        pthread_join(threads[i], NULL);

    return 0;
}
