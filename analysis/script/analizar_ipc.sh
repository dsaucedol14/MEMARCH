#!/usr/bin/env bash
# Calcula mediana, Q1 y Q3 del IPC por (rutina, nivel, n)
CSV="${1:-data/tb06_*.csv}"
OUT="data/tb06_resumen.csv"

echo "rutina,nivel,n,ipc_q1,ipc_mediana,ipc_q3,ipc_iqr" > "$OUT"

for rutina in iter rec memo; do
    for nivel in asm O0 O2; do
        for n in 16 32 64 128 256 512; do
            # Extrae IPC ordenado
            vals=$(awk -F, -v r=$rutina -v lv=$nivel -v nn=$n \
                   '$1==r && $2==lv && $3==nn {print $7}' $CSV | sort -n)
            count=$(echo "$vals" | wc -l)
            if [ "$count" -lt 3 ]; then continue; fi

            q1_idx=$(( (count + 1) / 4 ))
            med_idx=$(( (count + 1) / 2 ))
            q3_idx=$(( 3 * (count + 1) / 4 ))

            q1=$(echo "$vals" | sed -n "${q1_idx}p")
            med=$(echo "$vals" | sed -n "${med_idx}p")
            q3=$(echo "$vals" | sed -n "${q3_idx}p")
            iqr=$(echo "scale=4; $q3 - $q1" | bc)
            echo "$rutina,$nivel,$n,$q1,$med,$q3,$iqr" >> "$OUT"
        done
    done
done

echo "Resumen en: $OUT"
echo ""
echo "Mediana de IPC por rutina y nivel (promedio sobre todos los n):"
awk -F, 'NR>1 {
    key = $1 "_" $2
    sum[key] += $5
    cnt[key] += 1
}
END {
    printf "%-6s %-6s %-10s\n", "rut", "nivel", "ipc_promedio"
    for (k in sum) printf "%-15s %.3f\n", k, sum[k]/cnt[k]
}' "$OUT" | sort
