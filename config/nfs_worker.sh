#!/usr/bin/env bash
# Cliente NFS en cada worker (con sudo): monta main:/home/ec1/compartido en la MISMA ruta.
set -euo pipefail
COMPARTIDO=/home/ec1/compartido

mkdir -p "$COMPARTIDO"
chown ec1:ec1 "$COMPARTIDO"

grep -qF "main:$COMPARTIDO" /etc/fstab || \
  echo "main:$COMPARTIDO $COMPARTIDO nfs defaults,_netdev,nofail 0 0" >> /etc/fstab
systemctl daemon-reload

mountpoint -q "$COMPARTIDO" || mount "$COMPARTIDO"
df -h "$COMPARTIDO"
echo "[$(hostname)] nfs_worker.sh OK"
