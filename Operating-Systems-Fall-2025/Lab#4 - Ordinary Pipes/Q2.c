#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <ctype.h>

int main()
{
    int in = open("input.txt", O_RDONLY);
    int out = open("output.txt", O_WRONLY | O_CREAT | O_TRUNC, 0644);

    if (in < 0 || out < 0)
    {
        perror("File error");
        return 1;
    }

    dup2(in, 0);
    dup2(out, 1); 
    close(in);
    close(out);

    int sum = 0, c;
    while ((c = getchar()) != EOF)
    {
        if (isdigit(c))
            sum += c - '0';
    }

    printf("%d\n", sum);
    return 0;
}
