/* MEMARCH TB-03 — Profundidad máxima de recursión por agotamiento de pila
 *
 * Estrategia:
 *  1. Pila auxiliar (sigaltstack) para que el handler de SIGSEGV no muera
 *     también por desbordamiento.
 *  2. sigaction sobre SIGSEGV con SA_ONSTACK que hace siglongjmp a main.
 *  3. Búsqueda binaria para encontrar n_max con pocos intentos.
 *
 * Salida CSV en stdout:
 *   stack_kb,n_max,bytes_por_nivel_efectivo,bytes_usados
 *
 * NOTA: el límite de stack del proceso lo fija el shell padre con ulimit -s
 * ANTES de invocar este binario. El programa solo lo lee con getrlimit.
 */

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <signal.h>
#include <setjmp.h>
#include <sys/resource.h>

extern uint64_t factorial_rec(uint64_t n);

/* Variables globales requeridas por la instrumentación de factorial_rec */
uint64_t rsp_minimo  = 0;
uint64_t rsp_inicial = 0;

/* Stack alternativo para el handler de SIGSEGV */
#define ALT_STACK_SIZE  (64 * 1024)
static uint8_t alt_stack[ALT_STACK_SIZE];

/* Punto de retorno tras capturar SIGSEGV */
static sigjmp_buf jump_buffer;

/* Handler: solo salta de vuelta a main */
static void segv_handler(int sig, siginfo_t *info, void *ctx) {
    (void) sig; (void) info; (void) ctx;
    siglongjmp(jump_buffer, 1);
}

/* Devuelve 1 si factorial_rec(n) sobrevive, 0 si dispara SIGSEGV */
static int prueba_sobrevive(uint64_t n) {
    if (sigsetjmp(jump_buffer, 1) == 0) {
        rsp_minimo  = 0xFFFFFFFFFFFFFFFFULL;
        rsp_inicial = ((uint64_t)__builtin_frame_address(0));
        (void) factorial_rec(n);
        return 1;
    } else {
        return 0;  /* aterrizó por siglongjmp tras SIGSEGV */
    }
}

int main(void) {
    /* 1. Instalar pila alternativa para el handler */
    stack_t ss = { .ss_sp = alt_stack, .ss_flags = 0, .ss_size = ALT_STACK_SIZE };
    if (sigaltstack(&ss, NULL) != 0) { perror("sigaltstack"); return 1; }

    /* 2. Instalar handler de SIGSEGV */
    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_sigaction = segv_handler;
    sa.sa_flags     = SA_SIGINFO | SA_ONSTACK | SA_NODEFER | SA_RESETHAND;
    sigemptyset(&sa.sa_mask);
    if (sigaction(SIGSEGV, &sa, NULL) != 0) { perror("sigaction"); return 1; }

    /* 3. Leer el límite de stack actual */
    struct rlimit rl;
    if (getrlimit(RLIMIT_STACK, &rl) != 0) { perror("getrlimit"); return 1; }
    uint64_t stack_bytes = (uint64_t) rl.rlim_cur;
    uint64_t stack_kb    = stack_bytes / 1024;

    /* 4. Búsqueda binaria del n_max
     *    Cota superior inicial: stack_bytes / 16  (más optimista que 24
     *    para no dejar fuera valores válidos en hardware con frame menor).
     */
    uint64_t lo = 1;
    uint64_t hi = stack_bytes / 16;
    uint64_t n_max = 0;

    while (lo <= hi) {
        uint64_t mid = lo + (hi - lo) / 2;
        if (prueba_sobrevive(mid)) {
            n_max = mid;
            lo = mid + 1;
        } else {
            hi = mid - 1;
        }
        /* Re-instalar el handler porque SA_RESETHAND lo limpia tras cada uso.
         * Es necesario después de cada SIGSEGV capturado. */
        if (sigaction(SIGSEGV, &sa, NULL) != 0) { perror("re-sigaction"); return 1; }
    }

    /* 5. Reportar: una sola línea para este tamaño de stack */
    uint64_t bytes_usados = (n_max > 0) ? (rsp_inicial - rsp_minimo) : 0;
    double bytes_por_nivel = (n_max > 0) ? ((double) bytes_usados / n_max) : 0.0;

    printf("stack_kb,n_max,bytes_por_nivel,bytes_usados\n");
    printf("%lu,%lu,%.2f,%lu\n",
           stack_kb, n_max, bytes_por_nivel, bytes_usados);

    return 0;
}
