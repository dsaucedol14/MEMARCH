; ==============================================================================
; MEMARCH — Memory + Architecture
; Archivo:    fibo_iter.asm
; Descripción: Implementación iterativa de la sucesión de Fibonacci en
;              x86-64 (NASM). Sirve como contraparte de fibo_rec.asm y
;              fibo_memo.asm para contrastar el costo microarquitectónico
;              de eliminar la recursión: ausencia de crecimiento de pila,
;              un único bucle con predicción de saltos casi perfecta y
;              dependencias de datos lineales.
;
; Definición matemática:
;     fib(0) = 0
;     fib(1) = 1
;     fib(n) = fib(n-1) + fib(n-2),  para n >= 2
;
; Complejidad:
;     Tiempo:  O(n)
;     Espacio: O(1)   (sin uso de pila adicional ni heap)
;
; Convención de llamadas: System V AMD64 ABI
;     - Primer argumento (n) en RDI.
;     - Valor de retorno en RAX.
;     - RBX, RBP, R12-R15 son callee-saved.
;     - RAX, RCX, RDX, RSI, RDI, R8-R11 son caller-saved.
;
; Ensamblado y enlazado:
;     nasm -f elf64 -g -F dwarf fibo_iter.asm -o fibo_iter.o
;     gcc  -no-pie -g fibo_iter.o -o fibo_iter
;
; Ejecución:
;     ./fibo_iter 30      ; calcula fib(30) e imprime el resultado
;
; Medición con perf:
;     perf stat -e cycles,instructions,branches,branch-misses,\
;                  cache-references,cache-misses ./fibo_iter 30
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

            global  fib_iter
            global  main
            extern  printf
            extern  strtol

; ------------------------------------------------------------------------------
; Sección de datos de sólo lectura
; ------------------------------------------------------------------------------
            section .rodata

fmt_result: db      "fib(%ld) = %ld", 10, 0
fmt_usage:  db      "Uso: %s <n>", 10, 0
fmt_error:  db      "Error: n debe ser un entero no negativo.", 10, 0

; ==============================================================================
; fib_iter — Calcula el n-ésimo número de Fibonacci de forma iterativa.
;
; Entrada:  RDI = n  (entero no negativo, 64 bits)
; Salida:   RAX = fib(n)
;
; Estrategia:
;     Mantenemos dos acumuladores (a, b) que representan los dos términos
;     consecutivos más recientes de la sucesión:
;
;         a = fib(i-1)
;         b = fib(i)
;
;     En cada iteración: (a, b) <- (b, a+b). Después de n iteraciones,
;     a contiene fib(n).
;
;     Se usa LEA para fusionar la suma y la asignación temporal en una
;     única microoperación, evitando un registro temporal explícito.
;
; Registros utilizados (todos caller-saved, no requieren respaldo):
;     RAX = a = fib(i-1)   (también es el valor de retorno final)
;     RDX = b = fib(i)
;     RCX = contador de bucle
;     RSI = temporal (a+b)
;
; Pila usada: 0 bytes adicionales. No hay CALL internos.
; ==============================================================================
            section .text

fib_iter:
            ; --- Caso base: n < 2 → devolver n directamente ---
            cmp     rdi, 2
            jae     .loop_init              ; si n >= 2, ir al bucle
            mov     rax, rdi                ; fib(0)=0, fib(1)=1
            ret

.loop_init:
            ; Inicialización de invariantes:
            ;   a = fib(0) = 0
            ;   b = fib(1) = 1
            ;   contador = n - 1   (haremos n-1 actualizaciones)
            xor     eax, eax                ; RAX = a = 0 (xor zera 64 bits)
            mov     edx, 1                  ; RDX = b = 1
            mov     rcx, rdi                ; RCX = n
            dec     rcx                     ; RCX = n - 1

.loop:
            ; Núcleo del bucle: (a, b) <- (b, a+b)
            ;   LEA rsi, [rax+rdx]   ; rsi  <- a + b
            ;   mov rax, rdx         ; a    <- b (antiguo)
            ;   mov rdx, rsi         ; b    <- a + b (nuevo)
            lea     rsi, [rax + rdx]        ; rsi <- a + b
            mov     rax, rdx                ; a   <- b
            mov     rdx, rsi                ; b   <- a + b
            dec     rcx
            jnz     .loop                   ; predecible: tomado n-2 veces, no tomado 1 vez

            ; Al salir del bucle, b (RDX) contiene fib(n).
            mov     rax, rdx
            ret

; ==============================================================================
; main — Punto de entrada. Lee n desde argv[1], invoca fib_iter e imprime.
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

            ; Calcular fib_iter(n)
            mov     rdi, rbx
            call    fib_iter
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
; - Número de instrucciones ejecutadas en el bucle: ~5 por iteración, lo que
;   da aproximadamente 5n + constante para todo el cálculo.
;
; - Se espera observar:
;     * Branch-misses casi nulos: el salto JNZ del bucle es tomado n-2 veces
;       consecutivas; la predicción dinámica converge en pocas iteraciones.
;     * IPC alto (cercano al máximo del front-end), ya que las dependencias
;       son cortas y la microarquitectura puede ejecutar varias iteraciones
;       en vuelo gracias al renombrado de registros.
;     * Tasa de cache-misses despreciable: el conjunto de trabajo cabe en
;       registros; no hay accesos a memoria salvo el código mismo.
;     * Profundidad de pila constante (sólo el frame de fib_iter).
;
; - Para contraste, comparar con:
;     * fibo_rec.asm    — versión recursiva pura O(phi^n) tiempo, O(n) espacio.
;     * fibo_memo.asm   — versión con memoización O(n) tiempo, O(n) espacio.
;
; - Comparativa esperada en n=30:
;     fib_iter:  ~30 iteraciones,    ~150 instrucciones.
;     fib_memo:  ~30 llamadas únicas, ~varios cientos de instrucciones.
;     fib_rec:   ~2.7 millones de llamadas, decenas de millones de instrucciones.
; ==============================================================================

; Marca de pila no ejecutable (buenas prácticas de seguridad en ELF).
            section .note.GNU-stack noalloc noexec nowrite progbits
