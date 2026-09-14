/* =============================================================================
 * MEMARCH — Memory + Architecture
 * Archivo:    final.c
 * Descripción: Driver de benchmarks que mide tiempo y consumo de pila para
 *              implementaciones recursivas e iterativas en NASM x86-64 de:
 *                - factorial(n)
 *                - fibonacci(n)
 *
 *              Mide:
 *                - Tiempo de ejecución (nanosegundos, CLOCK_MONOTONIC_RAW).
 *                - Pico de pila consumido (vía instrumentación en ASM de
 *                  la variable global rsp_minimo).
 *
 * Compilación: ver Makefile.
 *
 * Copyright (C) 2026  Daniel Saucedo León y Manuel Hernández — GPL-3.0
 * ============================================================================= */

#include <stdio.h>
#include <stdint.h>
#include <time.h>
#include <string.h>

/* ---- Declaraciones externas de rutinas ASM ---- */
extern uint64_t factorial_rec  (uint64_t n);
extern uint64_t factorial_iter (uint64_t n);
extern uint64_t fib_rec        (uint64_t n);
extern uint64_t fib_iter       (uint64_t n);
extern uint64_t fib_memo       (uint64_t n, int64_t *memo);

/* ---- Variables globales instrumentadas desde ASM ---- *
 *
 * Las rutinas recursivas (factorial_rec, fib_rec, fib_memo) escriben en
 * rsp_minimo el menor valor de RSP visto durante la recursión. El
 * driver calcula el consumo de pila como: rsp_inicial - rsp_minimo.
 */
uint64_t rsp_minimo  = 0;
uint64_t rsp_inicial = 0;

/* Lee el RSP actual del hilo en ejecución. */
static inline uint64_t get_rsp(void) {
    uint64_t rsp;
    __asm__ volatile ("mov %%rsp, %0" : "=r"(rsp));
    return rsp;
}

/* Reloj de alta resolución, inmune a ajustes NTP. */
static inline uint64_t ns_now(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC_RAW, &ts);
    return (uint64_t)ts.tv_sec * 1000000000ULL + ts.tv_nsec;
}

/* =============================================================================
 *                              FACTORIAL
 * ============================================================================= */

static void medir_stack_factorial(uint64_t n) {
    rsp_minimo  = 0xFFFFFFFFFFFFFFFFULL;     /* valor máximo, será reducido */
    rsp_inicial = get_rsp();
    (void) factorial_rec(n);
    uint64_t consumo = rsp_inicial - rsp_minimo;
    printf("  [STACK] factorial_rec (%2lu): %5lu bytes\n", n, consumo);
    printf("  [STACK] factorial_iter(%2lu): %5d bytes (sólo registros)\n\n",
           n, 0);
}

static void benchmark_factorial(uint64_t n) {
    uint64_t t0, t1, res;

    /* Recursivo */
    t0  = ns_now();
    res = factorial_rec(n);
    t1  = ns_now();
    printf("  [REC ] factorial(%2lu) = %20lu  | %8lu ns\n",
           n, res, t1 - t0);

    /* Iterativo */
    t0  = ns_now();
    res = factorial_iter(n);
    t1  = ns_now();
    printf("  [ITER] factorial(%2lu) = %20lu  | %8lu ns\n",
           n, res, t1 - t0);
}

/* =============================================================================
 *                              FIBONACCI
 * ============================================================================= */

static void medir_stack_fib(uint64_t n) {
    int64_t memo[128];
    memset(memo, 0, sizeof(memo));

    /* fib_rec */
    rsp_minimo  = 0xFFFFFFFFFFFFFFFFULL;
    rsp_inicial = get_rsp();
    (void) fib_rec(n);
    uint64_t consumo_rec = rsp_inicial - rsp_minimo;

    /* fib_memo */
    rsp_minimo  = 0xFFFFFFFFFFFFFFFFULL;
    rsp_inicial = get_rsp();
    memset(memo, 0, sizeof(memo));
    (void) fib_memo(n, memo);
    uint64_t consumo_memo = rsp_inicial - rsp_minimo;

    printf("  [STACK] fib_rec (%3lu): %6lu bytes\n", n, consumo_rec);
    printf("  [STACK] fib_memo(%3lu): %6lu bytes\n", n, consumo_memo);
    printf("  [STACK] fib_iter(%3lu): %6d bytes (sólo registros)\n\n",
           n, 0);
}

static void benchmark_fib(uint64_t n) {
    int64_t memo[128];
    uint64_t t0, t1, res;

    /* Recursivo puro: cuidado, n grande explota exponencialmente */
    t0  = ns_now();
    res = fib_rec(n);
    t1  = ns_now();
    printf("  [REC ] fib(%3lu) = %20lu  | %10lu ns\n", n, res, t1 - t0);

    /* Iterativo */
    t0  = ns_now();
    res = fib_iter(n);
    t1  = ns_now();
    printf("  [ITER] fib(%3lu) = %20lu  | %10lu ns\n", n, res, t1 - t0);

    /* Memoización */
    memset(memo, 0, sizeof(memo));
    t0  = ns_now();
    res = fib_memo(n, memo);
    t1  = ns_now();
    printf("  [MEMO] fib(%3lu) = %20lu  | %10lu ns\n", n, res, t1 - t0);
}

/* =============================================================================
 *                                MAIN
 * ============================================================================= */

int main(void) {
    printf("================================================================\n");
    printf("  MEMARCH — Benchmark de algoritmos recursivos vs iterativos\n");
    printf("  Arquitectura x86-64 (System V AMD64 ABI) — NASM + C\n");
    printf("================================================================\n\n");

    /* -------- Factorial -------- */
    printf("---------- FACTORIAL ----------\n\n");
    uint64_t valores_fact[] = { 5, 10, 15, 20 };
    for (size_t i = 0; i < sizeof(valores_fact)/sizeof(valores_fact[0]); ++i) {
        uint64_t n = valores_fact[i];
        benchmark_factorial(n);
        medir_stack_factorial(n);
    }

    /* -------- Fibonacci -------- */
    printf("---------- FIBONACCI ----------\n\n");

    /* Para valores grandes evitamos fib_rec (es exponencial).
     * Se usan dos tandas: una con n moderado para incluir fib_rec,
     * otra mayor sólo para iter y memo. */
    printf("[Tanda 1: n moderado, incluye fib_rec]\n");
    uint64_t valores_fib_mod[] = { 10, 20, 30 };
    for (size_t i = 0; i < sizeof(valores_fib_mod)/sizeof(valores_fib_mod[0]); ++i) {
        uint64_t n = valores_fib_mod[i];
        benchmark_fib(n);
        medir_stack_fib(n);
    }

    printf("[Tanda 2: n grande, sólo iter y memo]\n");
    uint64_t valores_fib_grandes[] = { 50, 70, 90 };
    for (size_t i = 0;
         i < sizeof(valores_fib_grandes)/sizeof(valores_fib_grandes[0]);
         ++i) {
        uint64_t n = valores_fib_grandes[i];

        uint64_t t0, t1, res;
        int64_t memo[128];

        t0  = ns_now();
        res = fib_iter(n);
        t1  = ns_now();
        printf("  [ITER] fib(%3lu) = %20lu  | %10lu ns\n", n, res, t1 - t0);

        memset(memo, 0, sizeof(memo));
        t0  = ns_now();
        res = fib_memo(n, memo);
        t1  = ns_now();
        printf("  [MEMO] fib(%3lu) = %20lu  | %10lu ns\n\n", n, res, t1 - t0);
    }

    printf("================================================================\n");
    printf("  Fin del benchmark.\n");
    printf("================================================================\n");
    return 0;
}
