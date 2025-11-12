#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>
#include <pthread.h>
#include <ctype.h>

#define FILE_SIZE 100  // given in the question

void* replace_digits(void* arg) {
    char* region = (char*)arg;
    for (int i = 0; i < FILE_SIZE / 2; i++) {
        if (isdigit(region[i])) {
            region[i] = ' ';
        }
    }
    return NULL;
}

int main(int argc, char* argv[]) {
    if (argc != 2) {
        printf("Usage: %s <filename>\n", argv[0]);
        return 1;
    }

    const char* filename = argv[1];
    int fd = open(filename, O_RDWR);
    if (fd == -1) {
        perror("open");
        return 1;
    }

    // Map the file into memory
    char* map = mmap(NULL, FILE_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    if (map == MAP_FAILED) {
        perror("mmap");
        close(fd);
        return 1;
    }

    pthread_t t1, t2;

    // Thread 1: works on first half
    pthread_create(&t1, NULL, replace_digits, map);
    // Thread 2: works on second half (map + 50)
    pthread_create(&t2, NULL, replace_digits, map + FILE_SIZE / 2);

    pthread_join(t1, NULL);
    pthread_join(t2, NULL);

    printf("Updated content:\n%.*s\n", FILE_SIZE, map);

    munmap(map, FILE_SIZE);
    close(fd);

    return 0;
}
