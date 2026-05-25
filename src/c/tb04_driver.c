/* MEMARCH TB-04 — Comparación de tiempos con resolución nanosegundo
 *
 * Para cada n ∈ {20, 100, 1000, 10000, 100000}:
 *  1. Repite 30 veces una batería de 1000 invocaciones consecutivas.
 *  2. Mide tiempo total con clock_gettime(CLOCK_MONOTONIC_RAW).
 *  3. Reporta mediana y rango intercuartílico (Q1, Q3).
 *
 * Salida CSV en stdout:
 *   n,variante,mediana_ns,q1_ns,q3_ns,iqr_ns
 *
 * Nota: se mide tiempo total de 1000 llamadas y luego se divide,
 * para amortizar la resolución del reloj y minimizar el ruido de
 * la propia llamada a clock_gettime.
 */

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <time.h>

extern uint64_t factorial_rec  (uint64_t n);
extern uint64_t factorial_iter (uint64_t n);

/* Requeridas por la instrumentación de factorial_rec */
uint64_t rsp_minimo  = 0;
uint64_t rsp_inicial = 0;

#define INVOCACIONES   1000
#define REPETICIONES   30

static inline uint64_t ns_now(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC_RAW, &ts);
    return (uint64_t)ts.tv_sec * 1000000000ULL + ts.tv_nsec;
}

static int cmp_u64(const void *a, const void *b) {
    uint64_t x = *(const uint64_t *)a;
    uint64_t y = *(const uint64_t *)b;
    return (x > y) - (x < y);
}

/* Calcula percentil P sobre arreglo ya ordenado. */
static uint64_t percentil(uint64_t *arr, int n, double p) {
    double idx = p * (n - 1);
    int lo = (int) idx;
    int hi = lo + 1;
    if (hi >= n) return arr[n - 1];
    double frac = idx - lo;
    return (uint64_t) (arr[lo] * (1.0 - frac) + arr[hi] * frac);
}

/* Mide una rutina para un n dado. Devuelve mediana, Q1, Q3 por llamada. */
static void medir(const char *nombre, uint64_t n,
                  uint64_t (*fn)(uint64_t),
                  uint64_t *out_med, uint64_t *out_q1, uint64_t *out_q3) {
    uint64_t muestras[REPETICIONES];
    uint64_t acumulador = 0;  /* evita que el optimizador elimine la llamada */

    /* Calentamiento: una batería completa que descartamos */
    for (int i = 0; i < INVOCACIONES; ++i) acumulador += fn(n);

    /* Mediciones reales */
    for (int rep = 0; rep < REPETICIONES; ++rep) {
        uint64_t t0 = ns_now();
        for (int i = 0; i < INVOCACIONES; ++i) {
            acumulador += fn(n);
        }
        uint64_t t1 = ns_now();
        muestras[rep] = (t1 - t0) / INVOCACIONES;
    }

    /* Evita warning unused-but-set-variable */
    __asm__ volatile ("" :: "r"(acumulador) : "memory");

    qsort(muestras, REPETICIONES, sizeof(uint64_t), cmp_u64);
    *out_med = percentil(muestras, REPETICIONES, 0.50);
    *out_q1  = percentil(muestras, REPETICIONES, 0.25);
    *out_q3  = percentil(muestras, REPETICIONES, 0.75);

    (void) nombre;
}

int main(void) {
    uint64_t ns_arr[] = { 20, 100, 1000, 10000, 100000 };
    int n_count = sizeof(ns_arr) / sizeof(ns_arr[0]);

    printf("n,variante,mediana_ns,q1_ns,q3_ns,iqr_ns\n");

    for (int i = 0; i < n_count; ++i) {
        uint64_t n = ns_arr[i];
        uint64_t med, q1, q3;

        medir("rec", n, factorial_rec, &med, &q1, &q3);
        printf("%lu,rec,%lu,%lu,%lu,%lu\n", n, med, q1, q3, q3 - q1);
        fflush(stdout);

        medir("iter", n, factorial_iter, &med, &q1, &q3);
        printf("%lu,iter,%lu,%lu,%lu,%lu\n", n, med, q1, q3, q3 - q1);
        fflush(stdout);
    }

    return 0;
}
