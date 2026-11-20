#!/usr/bin/env bash
# Desde main: ejecuta la tarea N veces en los workers.
# Uso: ./ejecutar.sh [N=10]        (PAUSA=0.5 ./ejecutar.sh 20 para cambiar la pausa)
set -euo pipefail
C=/home/ec1/compartido
N="${1:-10}"
PAUSA="${PAUSA:-1}"
SESION="$(date +%H%M%S)"

for i in $(seq 1 "$N"); do
  mpirun --hostfile "$C/hostfile" -np 2 --map-by node \
    --mca btl_tcp_if_include 10.0.1.0/24 --mca oob_tcp_if_include 10.0.1.0/24 \
    "$C/tarea" "S${SESION}-$i" "$C/resultados.txt"
  sleep "$PAUSA"
done

echo
echo "Listo: $N corridas agregadas a $C/resultados.txt"
echo "Analizar: python3 $C/analizar.py"
