#!/usr/bin/env bash
# MEMARCH TB-03 — Barrido de tamaños de stack
# Ejecuta ./tb03_driver bajo distintos ulimit -s y consolida los resultados.

mkdir -p data
CSV="data/tb03_$(hostname)_$(date +%Y%m%d).csv"

echo "stack_kb,n_max,bytes_por_nivel,bytes_usados" > "$CSV"

for kb in 1024 4096 8192 16384; do
    echo "--- Probando con stack = ${kb} KB ---"
    # ulimit y el binario en subshell para no afectar al shell padre
    salida=$(bash -c "ulimit -s ${kb} && ./tb03_driver" | tail -1)
    echo "  → $salida"
    echo "$salida" >> "$CSV"
done

echo ""
echo "Resultados consolidados en: $CSV"
echo ""
cat "$CSV"
