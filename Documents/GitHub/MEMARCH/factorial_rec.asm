; ==============================================================================
; MEMARCH — Memory + Architecture
; Archivo:    factorial_rec.asm
; Descripción: Factorial recursivo en x86-64 (NASM) con instrumentación
;              del RSP mínimo alcanzado durante la recursión.
;
;     n! = n * (n-1)!,   con 0! = 1
;
; Complejidad:  O(n) tiempo, O(n) espacio (pila).
;
; Variable externa instrumentada:
;     rsp_minimo : uint64_t  (definida en final.c)
;         En cada llamada, si el RSP actual es menor que rsp_minimo,
;         se actualiza. Esto permite calcular el "stack peak" como
;         rsp_inicial - rsp_minimo desde C.
;
; Convención: System V AMD64 ABI.  RDI = n,  RAX = resultado.
;
; Copyright (C) 2026  Daniel Saucedo León y Manuel Hernández — GPL-3.0
; ==============================================================================

            global  factorial_rec
            extern  rsp_minimo

            section .text

; ------------------------------------------------------------------------------
; factorial_rec(uint64_t n) -> uint64_t
; ------------------------------------------------------------------------------
factorial_rec:
            ; --- Instrumentación: actualizar rsp_minimo si RSP es más bajo ---
            ; rsp_minimo guarda el RSP más bajo (más profundo) visto hasta ahora.
            mov     rax, [rel rsp_minimo]
            cmp     rsp, rax
            jae     .skip_update            ; si RSP >= rsp_minimo, no actualizar
            mov     [rel rsp_minimo], rsp

.skip_update:
            ; --- Caso base: n <= 1 → devolver 1 ---
            cmp     rdi, 1
            ja      .recurse
            mov     eax, 1
            ret

.recurse:
            ; --- Prólogo: preservar n en la pila ---
            ; Necesitamos n después del CALL porque RDI/RAX son caller-saved.
            ; Usamos PUSH RDI + SUB RSP,8 para mantener alineación a 16.
            push    rdi                     ; guardar n
            sub     rsp, 8                  ; alinear a 16

            ; --- Llamada recursiva con n-1 ---
            dec     rdi
            call    factorial_rec           ; RAX <- (n-1)!

            ; --- Combinar: RAX <- n * (n-1)! ---
            add     rsp, 8
            pop     rdi                     ; recuperar n
            imul    rax, rdi                ; RAX <- n * (n-1)!
            ret

            section .note.GNU-stack noalloc noexec nowrite progbits
