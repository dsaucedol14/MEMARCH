; ==============================================================================
; MEMARCH — Memory + Architecture
; Archivo:    fibo_rec_lib.asm
; Descripción: Variante "biblioteca" de fibo_rec.asm — sin main, con
;              instrumentación de rsp_minimo para integración con el
;              driver de benchmarks final.c.
;
;     fib(n) = fib(n-1) + fib(n-2),   fib(0)=0, fib(1)=1
;
; Complejidad:  O(phi^n) tiempo, O(n) espacio.
;
; Convención: System V AMD64 ABI.  RDI = n,  RAX = fib(n).
; Variable externa: rsp_minimo (uint64_t).
;
; Copyright (C) 2026  Daniel Saucedo León y Manuel Hernández — GPL-3.0
; ==============================================================================

            global  fib_rec
            extern  rsp_minimo

            section .text

fib_rec:
            ; --- Instrumentación de RSP mínimo ---
            mov     rax, [rel rsp_minimo]
            cmp     rsp, rax
            jae     .skip_update
            mov     [rel rsp_minimo], rsp

.skip_update:
            ; --- Caso base ---
            cmp     rdi, 2
            jae     .recurse
            mov     rax, rdi
            ret

.recurse:
            push    rbx
            sub     rsp, 8

            mov     rbx, rdi                ; RBX <- n
            dec     rdi                     ; n-1
            call    fib_rec
            mov     [rsp], rax              ; guardar fib(n-1)

            mov     rdi, rbx
            sub     rdi, 2                  ; n-2
            call    fib_rec
            add     rax, [rsp]              ; fib(n-2) + fib(n-1)

            add     rsp, 8
            pop     rbx
            ret

            section .note.GNU-stack noalloc noexec nowrite progbits
