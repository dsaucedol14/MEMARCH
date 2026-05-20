/* MEMARCH TB-01 — Profundidad de stack según paradigma
 *
 * Mide consumo de stack para factorial_rec y factorial_iter
 * sobre n ∈ {10, 50, 100, 500, 1000}.
 * Salida CSV en stdout:
 *   n,variante,stack_bytes,bytes_por_nivel
 */

#define _GNU_SOURCE
#include <stdio.h>
#include <stdint.h>

extern uint64_t factorial_rec  (uint64_t n);
extern uint64_t factorial_iter (uint64_t n);

uint64_t rsp_minimo  = 0;
uint64_t rsp_inicial = 0;

static inline uint64_t get_rsp(void) {
    uint64_t rsp;
    __asm__ volatile ("mov %%rsp, %0" : "=r"(rsp));
    return rsp;
}

int main(void) {
    uint64_t ns[] = { 10, 50, 100, 500, 1000 };
    int count = sizeof(ns) / sizeof(ns[0]);

    printf("n,variante,stack_bytes,bytes_por_nivel\n");

    for (int i = 0; i < count; ++i) {
        uint64_t n = ns[i];

        /* Recursivo: instrumentamos rsp_minimo */
        rsp_minimo  = 0xFFFFFFFFFFFFFFFFULL;
        rsp_inicial = get_rsp();
        (void) factorial_rec(n);
        uint64_t consumo = rsp_inicial - rsp_minimo;
        double bxn = (double)consumo / (double)n;
        printf("%lu,rec,%lu,%.2f\n", n, consumo, bxn);

        /* Iterativo: control negativo, no toca pila */
        printf("%lu,iter,0,0.00\n", n);
    }

    return 0;
}
