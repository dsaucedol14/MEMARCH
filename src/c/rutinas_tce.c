/* MEMARCH TB-09 — Variantes para análisis de TCE
 *
 * Tres versiones funcionalmente equivalentes:
 *  1. factorial_rec_c       — recursión no-tail (multiplicación después del CALL)
 *  2. factorial_rec_acc_c   — recursión tail-call con acumulador
 *  3. factorial_iter_c      — bucle iterativo explícito
 */

#include <stdint.h>

/* Versión 1: recursión NO-TAIL. La operación n*f(n-1) ocurre DESPUÉS del call,
 * por lo que el llamador debe regresar para multiplicar. */
uint64_t factorial_rec_c(uint64_t n) {
    if (n <= 1) return 1;
    return n * factorial_rec_c(n - 1);
}

/* Versión 2: recursión TAIL-CALL pura. La última operación es el call recursivo;
 * el llamador no necesita hacer nada con el resultado. Candidata ideal para TCE. */
uint64_t factorial_rec_acc_c(uint64_t n, uint64_t acc) {
    if (n <= 1) return acc;
    return factorial_rec_acc_c(n - 1, n * acc);
}

/* Wrapper para que la firma sea compatible con las otras dos */
uint64_t factorial_rec_acc_entry(uint64_t n) {
    return factorial_rec_acc_c(n, 1);
}

/* Versión 3: iterativa explícita */
uint64_t factorial_iter_c(uint64_t n) {
    uint64_t acc = 1;
    for (uint64_t i = 2; i <= n; ++i) acc *= i;
    return acc;
}
