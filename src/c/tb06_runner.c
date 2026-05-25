/* MEMARCH TB-06 — Driver de carga para IPC
 *
 * Uso:
 *   ./tb06_runner <rutina> <nivel> <n> <repeticiones>
 *
 * Rutinas: rec | iter | memo
 * Niveles: asm | O0 | O2
 */

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

/* Las versiones NASM (símbolos sin sufijo) */
extern uint64_t factorial_rec  (uint64_t n);
extern uint64_t factorial_iter (uint64_t n);
extern uint64_t fib_memo       (uint64_t n, int64_t *memo);

/* Las versiones C (símbolos con sufijo _c) */
extern uint64_t factorial_rec_c  (uint64_t n);
extern uint64_t factorial_iter_c (uint64_t n);
extern uint64_t fib_memo_c       (uint64_t n, int64_t *memo);

/* Requeridas por la instrumentación de factorial_rec NASM */
uint64_t rsp_minimo  = 0;
uint64_t rsp_inicial = 0;

int main(int argc, char **argv) {
    if (argc != 5) {
        fprintf(stderr, "Uso: %s {rec|iter|memo} {asm|O0|O2} <n> <reps>\n", argv[0]);
        return 1;
    }
    const char *rutina = argv[1];
    const char *nivel  = argv[2];
    uint64_t    n      = strtoull(argv[3], NULL, 10);
    uint64_t    reps   = strtoull(argv[4], NULL, 10);

    volatile uint64_t acc = 0;
    int64_t memo[1024];

    int is_asm = (strcmp(nivel, "asm") == 0);
    /* O0 y O2 se distinguen al enlazar, no en runtime. El binario
     * llamado debe haberse enlazado contra el .o correspondiente. */

    if (strcmp(rutina, "rec") == 0) {
        if (is_asm) for (uint64_t i = 0; i < reps; ++i) acc += factorial_rec(n);
        else        for (uint64_t i = 0; i < reps; ++i) acc += factorial_rec_c(n);
    } else if (strcmp(rutina, "iter") == 0) {
        if (is_asm) for (uint64_t i = 0; i < reps; ++i) acc += factorial_iter(n);
        else        for (uint64_t i = 0; i < reps; ++i) acc += factorial_iter_c(n);
    } else if (strcmp(rutina, "memo") == 0) {
        if (is_asm) {
            for (uint64_t i = 0; i < reps; ++i) {
                memset(memo, 0, sizeof(memo));
                acc += fib_memo(n, memo);
            }
        } else {
            for (uint64_t i = 0; i < reps; ++i) {
                memset(memo, 0, sizeof(memo));
                acc += fib_memo_c(n, memo);
            }
        }
    } else {
        fprintf(stderr, "Rutina desconocida\n");
        return 2;
    }

    if (acc == 0xDEADBEEFCAFEBABEULL) fprintf(stderr, "no\n");
    return 0;
}
