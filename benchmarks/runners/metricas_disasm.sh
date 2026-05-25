#!/usr/bin/env bash
# MEMARCH TB-08 — Métricas cuantitativas de disassembly
#
# Para cada combinación rutina × nivel, extrae:
#  - Número de instrucciones (líneas que empiezan con offset hex)
#  - Tamaño total en bytes (último offset + tamaño aproximado de instr)
#  - Presencia de "call" recursivo
#  - Registros callee-saved push'eados (rbx, rbp, r12-r15)
#  - Patrones de optimización detectados

set -e

echo "===== MEMARCH TB-08 — Métricas de disassembly ====="
echo ""
printf "%-22s %-8s %-8s %-8s %-12s\n" \
    "rutina/nivel" "instr" "size" "call?" "callee-saved"
echo "------------------------------------------------------------------"

# Función auxiliar: analiza un bloque de función
function analizar() {
    local nombre=$1
    local archivo=$2
    local simbolo=$3

    # Extraer el cuerpo de la función
    body=$(awk "/<$simbolo>:/,/^$/" "$archivo")

    # Contar instrucciones (líneas con offset hex al inicio)
    instr=$(echo "$body" | grep -cE "^[[:space:]]+[0-9a-f]+:")

    # Tamaño = último offset - primer offset + ~5 bytes (heurística)
    first=$(echo "$body" | grep -E "^[[:space:]]+[0-9a-f]+:" | head -1 | \
            awk '{print $1}' | tr -d ':')
    last=$( echo "$body" | grep -E "^[[:space:]]+[0-9a-f]+:" | tail -1 | \
            awk '{print $1}' | tr -d ':')
    size=$((0x$last - 0x$first + 4))

    # ¿Llamada recursiva?
    if echo "$body" | grep -qE "call.*$simbolo"; then
        recursivo="SÍ"
    else
        recursivo="NO"
    fi

    # Registros callee-saved pushados
    saved=""
    for reg in rbx rbp r12 r13 r14 r15; do
        if echo "$body" | grep -qE "push[[:space:]]+$reg"; then
            saved="${saved}${reg} "
        fi
    done
    [ -z "$saved" ] && saved="ninguno"

    printf "%-22s %-8s %-8s %-8s %-12s\n" \
        "$nombre" "$instr" "$size" "$recursivo" "$saved"
}

echo ""
echo "FACTORIAL_REC:"
analizar "rec/NASM"  dis_rec_asm.txt factorial_rec
analizar "rec/C-O0"  dis_O0.txt      factorial_rec_c
analizar "rec/C-O2"  dis_O2.txt      factorial_rec_c
analizar "rec/C-O3"  dis_O3.txt      factorial_rec_c

echo ""
echo "FACTORIAL_ITER:"
analizar "iter/NASM" dis_iter_asm.txt factorial_iter
analizar "iter/C-O0" dis_O0.txt       factorial_iter_c
analizar "iter/C-O2" dis_O2.txt       factorial_iter_c
analizar "iter/C-O3" dis_O3.txt       factorial_iter_c

echo ""
echo "===== Patrones de optimización detectados ====="
for archivo in dis_O2.txt dis_O3.txt; do
    echo ""
    echo "--- $archivo ---"

    # Loop unrolling (instrucciones repetidas consecutivas)
    if grep -qE "imul.*rdi" "$archivo" && \
       [ $(grep -cE "imul.*rdi" "$archivo") -gt 2 ]; then
        echo "  ⚡ Posible loop unrolling (múltiples imul consecutivas)"
    fi

    # Strength reduction: lea en vez de mul/add
    if grep -qE "lea.*\[.*\+.*\]" "$archivo"; then
        echo "  ⚡ Strength reduction (uso de lea para aritmética)"
    fi

    # Tail-call elimination: bucle en vez de recursión
    if grep -qE "<factorial_rec_c>:" "$archivo" && \
       ! awk '/<factorial_rec_c>:/,/^$/' "$archivo" | grep -qE "call.*factorial_rec_c"; then
        echo "  ⚡ Recursión eliminada en factorial_rec_c (TCE / loop transformation)"
    fi

    # Vectorización (SIMD)
    if grep -qE "xmm|ymm|zmm" "$archivo"; then
        echo "  ⚡ Vectorización SIMD detectada (uso de xmm/ymm/zmm)"
    fi

    # Predicación con CMOV
    if grep -qE "cmov" "$archivo"; then
        echo "  ⚡ Predicación (cmov) — saltos condicionales eliminados"
    fi
done
