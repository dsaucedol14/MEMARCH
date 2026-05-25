#include <stdio.h>
#include <stdint.h>
extern uint64_t factorial_iter(uint64_t n);
int main(void) {
    uint64_t resultados[] = { 1000, 1000000, 1000000000ULL };
    for (int i = 0; i < 3; i++) {
        uint64_t r = factorial_iter(resultados[i]);
        printf("factorial_iter(%lu) sobrevivió. Resultado (overflow esperado): %lu\n",
               resultados[i], r);
    }
    return 0;
}
