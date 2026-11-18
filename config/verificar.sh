#!/usr/bin/env bash
# Comprueba los requisitos del examen: SSH sin contraseña, NFS compartido y MPI.
set -uo pipefail
NODOS=(main worker1 worker2)
C=/home/ec1/compartido
fallos=0

echo "--- SSH sin contraseña (todos contra todos)"
for a in "${NODOS[@]}"; do
  for b in "${NODOS[@]}"; do
    [ "$a" = "$b" ] && continue
    if r=$(ssh -o BatchMode=yes "$a" "ssh -o BatchMode=yes $b hostname" 2>&1); then
      echo "  $a -> $b : OK ($r)"
    else
      echo "  $a -> $b : FALLO ($r)"; fallos=$((fallos+1))
    fi
  done
done

echo "--- Folder compartido (leer / escribir / ejecutar desde cada nodo)"
for n in "${NODOS[@]}"; do
  if ssh -o BatchMode=yes "$n" "echo 'echo ejecutado en \$(hostname)' > $C/.prueba_$n.sh && chmod +x $C/.prueba_$n.sh && $C/.prueba_$n.sh" ; then :; else
    echo "  $n : FALLO"; fallos=$((fallos+1)); fi
done
ls -l "$C"/.prueba_*.sh && rm -f "$C"/.prueba_*.sh

echo "--- MPI en los workers"
mpirun --hostfile "$C/hostfile" -np 2 --map-by node \
  --mca btl_tcp_if_include 10.0.1.0/24 --mca oob_tcp_if_include 10.0.1.0/24 hostname \
  || fallos=$((fallos+1))

echo
[ "$fallos" -eq 0 ] && echo "CLUSTER OK" || echo "HAY $fallos FALLOS"
