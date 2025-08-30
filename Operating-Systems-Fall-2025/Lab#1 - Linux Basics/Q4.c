
#include <stdio.h>
#include"HelpQ4.h"

int main() {
    int x, y;

    printf("Enter two integers: ");
    scanf("%d %d", &x, &y);

    printf("Addition: %d + %d = %d\n", x, y, add(x, y));
    printf("Subtraction: %d - %d = %d\n", x, y, sub(x, y));
    printf("Multiplication: %d * %d = %d\n", x, y, mul(x, y));

    return 0;
}
