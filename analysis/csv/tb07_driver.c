/* MEMARCH TB-07 — Cache misses sobre fib_memo
 *
 * Estrategia:
 *   Ejecuta K instancias consecutivas de fib_memo, cada una con su
 *   propia tabla memo[] de N bytes. El conjunto de trabajo agregado
 *   es K*N bytes. Variando K barremos los niveles de cache:
 *     - K*N < L1d (48 KB)  → casi todo cache hit
 *     - K*N en L2 (2 MB)   → misses en L1d, hits en L2
 *     - K*N en L3 (30 MB)  → misses en L2, hits en L3
 *     - K*N > L3           → misses hasta DRAM
 *
 * Salida: el binario no imprime nada. Se invoca bajo perf stat.
 *
 * Uso:
 *   ./tb07_driver <K> <N_fib> <repeticiones>
 *
 * Donde:
 *   K          = número de tablas memo distintas (controla conjunto de trabajo)
 *   N_fib      = valor de fibonacci a calcular (típicamente 80-90)
 *   reps       = veces que se repite el barrido completo de K tablas
 */

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>

extern uint64_t fib_memo(uint64_t n, int64_t *memo);

/* Requeridas por la instrumentación de fib_memo */
uint64_t rsp_minimo  = 0;
uint64_t rsp_inicial = 0;

#define MEMO_SIZE   128   /* slots por tabla, 128*8 = 1024 B por instancia */

int main(int argc, char **argv) {
    if (argc != 4) {
        fprintf(stderr, "Uso: %s <K> <N_fib> <reps>\n", argv[0]);
        fprintf(stderr, "  K     = número de tablas memo (conjunto trabajo = K*1024 B)\n");
        fprintf(stderr, "  N_fib = valor de fibonacci (recomendado 80-90)\n");
        fprintf(stderr, "  reps  = repeticiones del barrido completo\n");
        return 1;
    }

    uint64_t K       = strtoull(argv[1], NULL, 10);
    uint64_t n_fib   = strtoull(argv[2], NULL, 10);
    uint64_t reps    = strtoull(argv[3], NULL, 10);

    /* Reserva una gran región contigua: K tablas × MEMO_SIZE slots × 8 bytes
     * Alineada a 64 bytes (línea de cache) para mediciones limpias. */
    size_t total_bytes = K * MEMO_SIZE * sizeof(int64_t);
    int64_t *region = NULL;
    if (posix_memalign((void**)&region, 64, total_bytes) != 0) {
        perror("posix_memalign");
        return 2;
    }

    /* Cero toda la región (importante: fib_memo usa 0 como "no calculado") */
    memset(region, 0, total_bytes);

    volatile uint64_t acc = 0;

    for (uint64_t r = 0; r < reps; ++r) {
        for (uint64_t i = 0; i < K; ++i) {
            /* Cada iteración usa la tabla i-ésima */
            int64_t *memo = &region[i * MEMO_SIZE];
            /* Limpia esta tabla individual (rápido, una línea de cache si está caliente) */
            memset(memo, 0, MEMO_SIZE * sizeof(int64_t));
            acc += fib_memo(n_fib, memo);
        }
    }

    /* Sobrevivir al optimizador */
    if (acc == 0xDEADBEEFCAFEBABEULL) {
        fprintf(stderr, "imposible\n");
    }

    free(region);
    return 0;
}
