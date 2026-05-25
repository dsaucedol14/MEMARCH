/* MEMARCH TB-06 — Tres rutinas en C puro
 * Se compilan dos veces: con -O0 y con -O2, generando
 * librutinas_O0.so y librutinas_O2.so (o los .o sueltos).
 */

#include <stdint.h>
#include <string.h>

/* Versión recursiva canónica */
uint64_t factorial_rec_c(uint64_t n) {
    if (n <= 1) return 1;
    return n * factorial_rec_c(n - 1);
}

/* Versión iterativa */
uint64_t factorial_iter_c(uint64_t n) {
    uint64_t acc = 1;
    for (uint64_t i = 2; i <= n; ++i) acc *= i;
    return acc;
}

/* Versión memoizada de fibonacci */
uint64_t fib_memo_c(uint64_t n, int64_t *memo) {
    if (n < 2) return n;
    if (memo[n] != 0) return memo[n];
    int64_t r = (int64_t) (fib_memo_c(n - 1, memo) + fib_memo_c(n - 2, memo));
    memo[n] = r;
    return (uint64_t) r;
}
