#include <stdio.h>
#include <stdint.h>
#include <time.h>
#include <string.h>

/* Declaraciones externas de rutinas ASM */
extern uint64_t factorial_rec(uint64_t n);
extern uint64_t factorial_iter(uint64_t n);
extern uint64_t fib_memo(uint64_t n, int64_t *memo);

static uint64_t rsp_base = 0;

static inline uint64_t get_rsp(void) {
    uint64_t rsp;
    __asm__ volatile ("mov %%rsp, %0" : "=r"(rsp));
    return rsp;
}

/* variable global donde ASM escribirá el RSP mínimo alcanzado */
uint64_t rsp_minimo   = 0;
uint64_t rsp_inicial  = 0;

void medir_stack_factorial(uint64_t n) {
    rsp_minimo  = 0xFFFFFFFFFFFFFFFFULL; /* valor máximo para comparar */
    rsp_inicial = get_rsp();
    factorial_rec(n);
  uint64_t consumo = rsp_inicial - rsp_minimo;
    printf("  [STACK] factorial_rec(%2lu): %lu bytes de stack\n", n, consumo);
    printf("  [STACK] factorial_iter(%2lu): 0 bytes (solo registros)\n\n", n);
}


/* Medición de tiempo con resolución nanosegundos */
static inline uint64_t ns_now(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC_RAW, &ts);
    return (uint64_t)ts.tv_sec * 1000000000ULL + ts.tv_nsec;
}

typedef struct {
    const char *nombre;
    uint64_t    resultado;
    uint64_t    tiempo_ns;
    uint64_t    stack_base;
    uint64_t    stack_peak;   /* se instrumenta desde ASM */
} Medicion;

void benchmark_factorial(uint64_t n) {
    Medicion m;
    uint64_t t0, t1;

    /* Recursivo */
 t0 = ns_now();
    m.resultado = factorial_rec(n);
    t1 = ns_now();
    printf("[REC ] factorial(%2lu) = %20lu  | %6lu ns\n",
           n, m.resultado, t1 - t0);

    /* Iterativo */
    t0 = ns_now();
    m.resultado = factorial_iter(n);
    t1 = ns_now();
    printf("[ITER] factorial(%2lu) = %20lu  | %6lu ns\n\n",
           n, m.resultado, t1 - t0);
}

void benchmark_fib(uint64_t n) {
    int64_t memo[128];
    uint64_t t0, t1, res;

    memset(memo, 0, sizeof(memo));

    t0  = ns_now();
    res = fib_memo(n, memo);
    t1  = ns_now();
    printf("[MEMO] fib(%3lu) = %20lu  | %6lu ns\n\n",
           n, res, t1 - t0);
