#!/usr/bin/env bash
# MEMARCH TB-09 — Métricas cuantitativas de las tres variantes
set -e

function analizar() {
    local nombre=$1 archivo=$2 simbolo=$3
    body=$(awk "/<$simbolo>:/,/^$/" "$archivo")
    instr=$(echo "$body" | grep -cE "^[[:space:]]+[0-9a-f]+:")
    first=$(echo "$body" | grep -E "^[[:space:]]+[0-9a-f]+:" | head -1 | awk '{print $1}' | tr -d ':')
    last=$( echo "$body" | grep -E "^[[:space:]]+[0-9a-f]+:" | tail -1 | awk '{print $1}' | tr -d ':')
    size=$((0x$last - 0x$first + 4))
    if echo "$body" | grep -qE "call.*$simbolo"; then recursivo="SÍ"; else recursivo="NO"; fi
    printf "%-30s %-6s %-6s %-6s\n" "$nombre" "$instr" "$size" "$recursivo"
}

echo "MEMARCH TB-09 — Comparativa de variantes para TCE"
echo ""
printf "%-30s %-6s %-6s %-6s\n" "variante" "instr" "size" "call?"
echo "----------------------------------------------------"
for opt in O0 O2 O3; do
    analizar "factorial_rec_c/$opt"      dis_$opt.txt  factorial_rec_c
    analizar "factorial_rec_acc_c/$opt"  dis_$opt.txt  factorial_rec_acc_c
    analizar "factorial_iter_c/$opt"     dis_$opt.txt  factorial_iter_c
    echo ""
done
