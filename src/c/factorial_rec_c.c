/* MEMARCH TB-02 — factorial_rec en C puro
 * Implementación idéntica a la rutina NASM a mano,
 * para comparar el código generado por GCC bajo -O0 y -O2.
 */

#include <stdint.h>

uint64_t factorial_rec_c(uint64_t n) {
    if (n <= 1) return 1;
    return n * factorial_rec_c(n - 1);
}
