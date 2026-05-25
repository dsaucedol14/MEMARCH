#!/usr/bin/env bash
# MEMARCH TB-06 — Captura de cycles e instructions para cálculo de IPC
# 3 rutinas × 3 niveles × 6 n × 30 repeticiones

set -e
mkdir -p data
CSV="data/tb06_$(hostname)_$(date +%Y%m%d).csv"
echo "rutina,nivel,n,rep,cycles,instructions,ipc" > "$CSV"

VALORES_N=(16 32 64 128 256 512)
RUTINAS=(iter rec memo)
NIVELES=(asm O0 O2)
N_REPS=30

# Repeticiones de la rutina por dentro del binario (no la rep externa)
function inner_reps() {
    case $1 in
        iter) echo $((20000000 / ($2 + 1))) ;;
        rec)  echo $((5000000  / ($2 + 1))) ;;
        memo) echo $((2000000  / ($2 + 1))) ;;
    esac
}

# Binario a usar según el nivel
function binario_para() {
    case $1 in
        asm) echo "./tb06_runner_O0" ;;   # asm va en ambos; usamos O0 indistintamente
        O0)  echo "./tb06_runner_O0" ;;
        O2)  echo "./tb06_runner_O2" ;;
    esac
}

total=$(( ${#RUTINAS[@]} * ${#NIVELES[@]} * ${#VALORES_N[@]} * N_REPS ))
hecho=0

for rutina in "${RUTINAS[@]}"; do
    for nivel in "${NIVELES[@]}"; do
        for n in "${VALORES_N[@]}"; do
            reps=$(inner_reps "$rutina" "$n")
            bin=$(binario_para "$nivel")
            echo "--- $rutina/$nivel  n=$n  inner_reps=$reps ---"

            for rep in $(seq 1 $N_REPS); do
                salida=$(perf stat -x, -e cycles,instructions \
                    "$bin" "$rutina" "$nivel" "$n" "$reps" 2>&1 1>/dev/null)

                cycles=$(echo "$salida" | awk -F, '/cycles/ {print $1}' | head -1)
                instr=$( echo "$salida" | awk -F, '/instructions/ {print $1}' | head -1)

                if [ -z "$cycles" ] || [ -z "$instr" ] || [ "$cycles" = "0" ]; then
                    echo "  rep=$rep ERROR. perf:"
                    echo "$salida"
                    continue
                fi
                ipc=$(echo "scale=4; $instr / $cycles" | bc)
                echo "$rutina,$nivel,$n,$rep,$cycles,$instr,$ipc" >> "$CSV"
                hecho=$((hecho + 1))
            done
            printf "  [%d/%d] hecho\n" "$hecho" "$total"
        done
    done
done

echo ""
echo "Resultados consolidados en: $CSV"
echo "Líneas:" $(wc -l < "$CSV")
