; ==============================================================================
; MEMARCH — Memory + Architecture
; Archivo:    fibo_memo.asm
; Descripción: Fibonacci con memoización descendente (top-down DP) en
;              x86-64 (NASM). La tabla memo es proporcionada por el
;              llamador (C) como segundo argumento, permitiendo medir
;              accesos a caché reales.
;
;     fib(0) = 0
;     fib(1) = 1
;     fib(n) = memo[n] si está calculado, si no fib(n-1) + fib(n-2)
;
; Convención de la tabla:
;     memo[i] == 0  → no calculado todavía  (excepto memo[0], que
;                     genuinamente vale 0, pero el cero se devuelve
;                     correctamente por el caso base sin tocar la tabla).
;     memo[i] != 0  → valor cacheado, devuelto directamente.
;
;     El tipo de memo es int64_t* para permitir el centinela 0 sin
;     ambigüedad con uint64_t (asumimos n suficientemente pequeño para
;     que fib(n) quepa con signo: fib(92) cabe en int64_t).
;
; Complejidad:  O(n) tiempo, O(n) espacio (tabla + pila ≤ n).
;
; Convención: System V AMD64 ABI.
;     RDI = n        (uint64_t)
;     RSI = memo*    (int64_t*)
;     RAX = fib(n)
;
; Variable externa instrumentada:
;     rsp_minimo : uint64_t  (actualizada en cada entrada).
;
; Copyright (C) 2026  Daniel Saucedo León y Manuel Hernández — GPL-3.0
; ==============================================================================

            global  fib_memo
            extern  rsp_minimo

            section .text

; ------------------------------------------------------------------------------
; fib_memo(uint64_t n, int64_t *memo) -> uint64_t
; ------------------------------------------------------------------------------
fib_memo:
            ; --- Instrumentación: actualizar rsp_minimo ---
            mov     rax, [rel rsp_minimo]
            cmp     rsp, rax
            jae     .skip_update
            mov     [rel rsp_minimo], rsp

.skip_update:
            ; --- Caso base: n < 2 → devolver n directamente ---
            cmp     rdi, 2
            jae     .check_memo
            mov     rax, rdi
            ret

.check_memo:
            ; --- ¿Está memo[n] ya calculado? ---
            mov     rax, [rsi + rdi*8]      ; RAX <- memo[n]
            test    rax, rax
            jnz     .return_cached          ; si != 0, ya está cacheado

            ; --- Prólogo: preservar n, memo* y un slot para fib(n-1) ---
            push    rbx                     ; RBX = n (callee-saved)
            push    r12                     ; R12 = memo* (callee-saved)
            push    r13                     ; R13 = fib(n-1) entre llamadas
            sub     rsp, 8                  ; alineación a 16 antes de CALL

            mov     rbx, rdi                ; RBX <- n
            mov     r12, rsi                ; R12 <- memo*

            ; --- Primera llamada recursiva: fib_memo(n-1, memo) ---
            dec     rdi                     ; RDI <- n-1
            ; RSI ya contiene memo*
            call    fib_memo
            mov     r13, rax                ; R13 <- fib(n-1)

            ; --- Segunda llamada recursiva: fib_memo(n-2, memo) ---
            mov     rdi, rbx
            sub     rdi, 2                  ; RDI <- n-2
            mov     rsi, r12                ; RSI <- memo*
            call    fib_memo                ; RAX <- fib(n-2)

            ; --- Combinar y memoizar ---
            add     rax, r13                ; RAX <- fib(n-1) + fib(n-2)
            mov     [r12 + rbx*8], rax      ; memo[n] <- fib(n)

            ; --- Epílogo ---
            add     rsp, 8
            pop     r13
            pop     r12
            pop     rbx
            ret

.return_cached:
            ; RAX ya contiene memo[n]; sólo retornar.
            ret

            section .note.GNU-stack noalloc noexec nowrite progbits
