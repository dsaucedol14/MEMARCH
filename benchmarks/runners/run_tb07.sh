#!/usr/bin/env bash
# MEMARCH TB-07 — Barrido de cache misses sobre fib_memo
# Varía el conjunto de trabajo de fib_memo desde L1d hasta DRAM

set -e
mkdir -p data
CSV="data/tb07_$(hostname)_$(date +%Y%m%d).csv"
echo "K,working_set_KB,cache_refs,cache_misses,L1_loads,L1_misses,miss_rate_L1_pct,miss_rate_LLC_pct" > "$CSV"

# Valores de K que cubren toda la jerarquía
K_VALUES=(4 16 64 256 1024 4096 16384 32768 65536)
N_FIB=80

# Ajustamos repeticiones según K para que cada corrida tarde similar
function reps_for() {
    case $1 in
        4|16|64)        echo 2000000 ;;
        256|1024)       echo 500000  ;;
        4096|16384)     echo 100000  ;;
        32768|65536)    echo 30000   ;;
    esac
}

for K in "${K_VALUES[@]}"; do
    reps=$(reps_for "$K")
    ws_kb=$((K))
    echo "--- K=$K  working set=${ws_kb} KB  reps=$reps ---"

    salida=$(perf stat -x, \
        -e cache-references,cache-misses,L1-dcache-loads,L1-dcache-load-misses \
        ./tb07_driver "$K" "$N_FIB" "$reps" 2>&1 1>/dev/null)

    cache_refs=$(echo "$salida" | awk -F, '/cache-references/ {print $1}' | head -1)
    cache_miss=$(echo "$salida" | awk -F, '/cache-misses/ {print $1}' | head -1)
    L1_loads=$(  echo "$salida" | awk -F, '/L1-dcache-loads/ {print $1}' | head -1)
    L1_miss=$(   echo "$salida" | awk -F, '/L1-dcache-load-misses/ {print $1}' | head -1)

    if [ -z "$cache_refs" ] || [ -z "$L1_loads" ]; then
        echo "  ERROR. perf salida cruda:"
        echo "$salida"
        continue
    fi

    miss_rate_L1=$(echo "scale=4; $L1_miss * 100 / $L1_loads" | bc)
    miss_rate_LLC=$(echo "scale=4; $cache_miss * 100 / $cache_refs" | bc)

    echo "  L1 miss rate: ${miss_rate_L1}%   LLC miss rate: ${miss_rate_LLC}%"
    echo "$K,$ws_kb,$cache_refs,$cache_miss,$L1_loads,$L1_miss,$miss_rate_L1,$miss_rate_LLC" >> "$CSV"
done

echo ""
echo "Resultados consolidados en: $CSV"
echo ""
cat "$CSV"
