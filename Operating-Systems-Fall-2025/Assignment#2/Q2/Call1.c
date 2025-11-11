#include <stdio.h>
#include <stdlib.h>

int main() {
    double avg;

    scanf("%lf", &avg);

    if (avg > 50)
        printf("Above Average\n");
    else
        printf("Below Average\n");

    return 0;
}
