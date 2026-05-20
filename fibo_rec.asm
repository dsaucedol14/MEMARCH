; ==============================================================================
; MEMARCH — Memory + Architecture
; Archivo:    fibo_rec.asm
; Descripción: Implementación recursiva pura de la sucesión de Fibonacci
;              en x86-64 (NASM). Sirve como caso de estudio para medir el
;              crecimiento de la pila, el comportamiento del pipeline y los
;              fallos de predicción de saltos en algoritmos con ramificación
;              binaria y profundidad exponencial.
;
; Definición matemática:
;     fib(0) = 0
;     fib(1) = 1
;     fib(n) = fib(n-1) + fib(n-2),  para n >= 2
;
; Complejidad:
;     Tiempo:  O(phi^n)  (exponencial)
;     Espacio: O(n)      (profundidad de la pila)
;
; Convención de llamadas: System V AMD64 ABI
;     - Primer argumento (n) en RDI.
;     - Valor de retorno en RAX.
;     - RBX, RBP, R12-R15 son callee-saved.
;     - RAX, RCX, RDX, RSI, RDI, R8-R11 son caller-saved.
;
; Ensamblado y enlazado:
;     nasm -f elf64 -g -F dwarf fibo_rec.asm -o fibo_rec.o
;     gcc  -no-pie -g fibo_rec.o -o fibo_rec
;
; Ejecución:
;     ./fibo_rec 30      ; calcula fib(30) e imprime el resultado
;
; Medición con perf:
;     perf stat -e cycles,instructions,branches,branch-misses,\
;                  cache-references,cache-misses ./fibo_rec 30
;
; ------------------------------------------------------------------------------
; Copyright (C) 2026  Daniel Saucedo León y Manuel Hernández
; Instituto Tecnológico Superior de Huauchinango (TecNM)
;
; Este programa es software libre: puede redistribuirlo y/o modificarlo
; bajo los términos de la GNU General Public License versión 3, publicada
; por la Free Software Foundation. Distribuido SIN GARANTÍA ALGUNA.
; Consulte el archivo LICENSE para más detalles.
; ==============================================================================

            global  fib_rec
            global  main
            extern  printf
            extern  atoi
            extern  strtol

; ------------------------------------------------------------------------------
; Sección de datos de sólo lectura
; ------------------------------------------------------------------------------
            section .rodata

fmt_result: db      "fib(%ld) = %ld", 10, 0
fmt_usage:  db      "Uso: %s <n>", 10, 0
fmt_error:  db      "Error: n debe ser un entero no negativo.", 10, 0

; ==============================================================================
; fib_rec — Calcula el n-ésimo número de Fibonacci de forma recursiva.
;
; Entrada:  RDI = n  (entero sin signo, 64 bits)
; Salida:   RAX = fib(n)
;
; Registros preservados:
;     RBX se usa como almacén temporal para fib(n-1) entre las dos llamadas
;     recursivas; al ser callee-saved, se respalda en la pila.
;
; Pila por marco: 16 bytes (1 push + alineación a 16 exigida por la ABI antes
; de cada CALL). La profundidad máxima de la pila es ~16 * n bytes.
; ==============================================================================
            section .text

fib_rec:
            ; --- Caso base: n < 2 → devolver n directamente ---
            cmp     rdi, 2
            jae     .recurse                ; si n >= 2, recurrir
            mov     rax, rdi                ; fib(0)=0, fib(1)=1
            ret

.recurse:
            ; --- Prólogo: respaldar RBX y mantener pila alineada a 16 ---
            push    rbx                     ; RBX es callee-saved
            sub     rsp, 8                  ; alineación a 16 antes de CALL

            ; --- Primera llamada recursiva: fib(n-1) ---
            mov     rbx, rdi                ; RBX <- n  (guardamos n original)
            dec     rdi                     ; RDI <- n-1
            call    fib_rec                 ; RAX <- fib(n-1)

            ; Guardamos fib(n-1) en una posición de la pila para sobrevivir
            ; a la segunda llamada (RAX es caller-saved).
            mov     [rsp], rax              ; [rsp] <- fib(n-1)

            ; --- Segunda llamada recursiva: fib(n-2) ---
            mov     rdi, rbx                ; recuperamos n
            sub     rdi, 2                  ; RDI <- n-2
            call    fib_rec                 ; RAX <- fib(n-2)

            ; --- Combinar resultados: fib(n) = fib(n-1) + fib(n-2) ---
            add     rax, [rsp]              ; RAX <- fib(n-2) + fib(n-1)

            ; --- Epílogo: liberar espacio y restaurar RBX ---
            add     rsp, 8
            pop     rbx
            ret

; ==============================================================================
; main — Punto de entrada. Lee n desde argv[1], invoca fib_rec e imprime.
;
; Convención de salida:
;     0  — éxito.
;     1  — número incorrecto de argumentos.
;     2  — n inválido (negativo o no numérico).
; ==============================================================================
main:
            ; Prólogo estándar
            push    rbp
            mov     rbp, rsp
            sub     rsp, 16                 ; reserva + alineación
            push    rbx                     ; RBX = n parseado (callee-saved)
            sub     rsp, 8                  ; mantener alineación a 16

            ; Comprobar argc >= 2
            cmp     rdi, 2
            jl      .usage

            ; argv[1] -> entero (long) vía strtol(argv[1], NULL, 10)
            mov     rdi, [rsi + 8]          ; RDI <- argv[1]
            xor     rsi, rsi                ; endptr = NULL
            mov     rdx, 10                 ; base 10
            call    strtol
            mov     rbx, rax                ; RBX <- n

            ; Validar n >= 0
            test    rbx, rbx
            js      .bad_input

            ; Calcular fib_rec(n)
            mov     rdi, rbx
            call    fib_rec
            mov     rdx, rax                ; RDX <- fib(n)

            ; printf("fib(%ld) = %ld\n", n, fib_n)
            lea     rdi, [rel fmt_result]
            mov     rsi, rbx
            xor     rax, rax                ; sin floats en variádicos
            call    printf

            xor     eax, eax                ; código de salida 0
            jmp     .epilogue

.usage:
            mov     rdi, [rsi]              ; RDI <- argv[0]
            lea     rsi, [rel fmt_usage]
            xchg    rdi, rsi                ; orden: fmt, argv[0]
            xor     rax, rax
            call    printf
            mov     eax, 1
            jmp     .epilogue

.bad_input:
            lea     rdi, [rel fmt_error]
            xor     rax, rax
            call    printf
            mov     eax, 2

.epilogue:
            add     rsp, 8
            pop     rbx
            leave
            ret

; ==============================================================================
; Notas de medición (MEMARCH)
; ------------------------------------------------------------------------------
; - El número de llamadas recursivas T(n) sigue la recurrencia
;       T(n) = T(n-1) + T(n-2) + 1,  T(0)=T(1)=1
;   por lo que T(n) ≈ 2*fib(n+1) - 1. Para n=30, ~2.7 millones de llamadas.
;
; - Se espera observar:
;     * Alta tasa de branch-misses por el patrón irregular cmp/jae.
;     * IPC moderado debido a dependencias de datos en ADD final.
;     * Presión sobre el RSB (Return Stack Buffer) cuando la profundidad
;       supera 16 niveles; degradación notable de la predicción de RET.
;
; - Para contraste, comparar con:
;     * fibo_iter.asm   — versión iterativa O(n) tiempo, O(1) espacio.
;     * fibo_memo.asm   — versión con memoización O(n) tiempo, O(n) espacio.
; ==============================================================================

; Marca de pila no ejecutable (buenas prácticas de seguridad en ELF).
            section .note.GNU-stack noalloc noexec nowrite progbits
