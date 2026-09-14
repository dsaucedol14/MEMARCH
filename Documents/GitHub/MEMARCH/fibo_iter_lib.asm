; ==============================================================================
; MEMARCH — Memory + Architecture
; Archivo:    fibo_iter_lib.asm
; Descripción: Variante "biblioteca" de fibo_iter.asm — sin main, lista
;              para enlazar con el driver final.c.
;
;     fib(n) = fib(n-1) + fib(n-2),   fib(0)=0, fib(1)=1
;
; Complejidad:  O(n) tiempo, O(1) espacio.
;
; Convención: System V AMD64 ABI.  RDI = n,  RAX = fib(n).
;
; Copyright (C) 2026  Daniel Saucedo León y Manuel Hernández — GPL-3.0
; ==============================================================================

            global  fib_iter

            section .text

fib_iter:
            cmp     rdi, 2
            jae     .loop_init
            mov     rax, rdi
            ret

.loop_init:
            xor     eax, eax                ; a = 0
            mov     edx, 1                  ; b = 1
            mov     rcx, rdi
            dec     rcx                     ; contador = n-1

.loop:
            lea     rsi, [rax + rdx]        ; rsi <- a+b
            mov     rax, rdx                ; a <- b
            mov     rdx, rsi                ; b <- a+b
            dec     rcx
            jnz     .loop

            mov     rax, rdx
            ret

            section .note.GNU-stack noalloc noexec nowrite progbits
