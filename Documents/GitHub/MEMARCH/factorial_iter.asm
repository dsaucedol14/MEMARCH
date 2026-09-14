; ==============================================================================
; MEMARCH — Memory + Architecture
; Archivo:    factorial_iter.asm
; Descripción: Factorial iterativo en x86-64 (NASM). Sin uso de pila
;              adicional; sólo registros caller-saved.
;
;     n! = 1 * 2 * 3 * ... * n,   con 0! = 1
;
; Complejidad:  O(n) tiempo, O(1) espacio.
;
; Convención: System V AMD64 ABI.  RDI = n,  RAX = resultado.
;
; Copyright (C) 2026  Daniel Saucedo León y Manuel Hernández — GPL-3.0
; ==============================================================================

            global  factorial_iter

            section .text

; ------------------------------------------------------------------------------
; factorial_iter(uint64_t n) -> uint64_t
; ------------------------------------------------------------------------------
factorial_iter:
            ; --- Caso base: n <= 1 → devolver 1 ---
            mov     eax, 1                  ; acumulador = 1 (también el resultado)
            cmp     rdi, 1
            jbe     .done                   ; si n <= 1, listo

            ; --- Bucle: RAX *= i, para i = 2 .. n ---
            mov     rcx, 2                  ; i = 2

.loop:
            imul    rax, rcx                ; RAX <- RAX * i
            inc     rcx
            cmp     rcx, rdi
            jbe     .loop                   ; mientras i <= n

.done:
            ret

            section .note.GNU-stack noalloc noexec nowrite progbits
