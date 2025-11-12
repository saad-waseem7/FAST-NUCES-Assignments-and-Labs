#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>
#include <string.h>

int main()
{
    int fd;
    struct stat sb;
    char *mapped;

    fd = open("data1.txt", O_RDWR);
    if (fd == -1)
    {
        perror("open");
        return 1;
    }

    fstat(fd, &sb);

    // Map the file into memory
    mapped = mmap(NULL, sb.st_size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    if (mapped == MAP_FAILED)
    {
        perror("mmap");
        close(fd);
        return 1;
    }

    printf("Original: %s\n", mapped);
    strcat(mapped, " - Updated!");
    printf("Updated: %s\n", mapped);
    munmap(mapped, sb.st_size);
    close(fd);

    return 0;
}
