#include <stdio.h>
#include <stdint.h>
#include <time.h>

extern uint64_t factorial_rec_c     (uint64_t n);
extern uint64_t factorial_rec_acc_c (uint64_t n, uint64_t acc);
extern uint64_t factorial_rec_acc_entry(uint64_t n);
extern uint64_t factorial_iter_c    (uint64_t n);

static inline uint64_t ns_now(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC_RAW, &ts);
    return (uint64_t)ts.tv_sec * 1000000000ULL + ts.tv_nsec;
}

int main(void) {
    uint64_t reps = 10000000;
    uint64_t t0, t1;
    volatile uint64_t acc = 0;

    /* Warmup */
    for (uint64_t i = 0; i < reps/10; ++i) acc += factorial_rec_c(20);

    t0 = ns_now();
    for (uint64_t i = 0; i < reps; ++i) acc += factorial_rec_c(20);
    t1 = ns_now();
    printf("factorial_rec_c(20)         : %lu ns/op\n", (t1-t0)/reps);

    t0 = ns_now();
    for (uint64_t i = 0; i < reps; ++i) acc += factorial_rec_acc_entry(20);
    t1 = ns_now();
    printf("factorial_rec_acc_c(20)     : %lu ns/op\n", (t1-t0)/reps);

    t0 = ns_now();
    for (uint64_t i = 0; i < reps; ++i) acc += factorial_iter_c(20);
    t1 = ns_now();
    printf("factorial_iter_c(20)        : %lu ns/op\n", (t1-t0)/reps);

    if (acc == 0xDEADBEEFCAFEBABEULL) fprintf(stderr, "nope\n");
    return 0;
}
