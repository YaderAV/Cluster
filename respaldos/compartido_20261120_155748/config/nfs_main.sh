#!/usr/bin/env bash
# Servidor NFS en main (con sudo): comparte /home/ec1/compartido con la subred del clúster.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
COMPARTIDO=/home/ec1/compartido

apt-get -q -y -o DPkg::Lock::Timeout=300 install nfs-kernel-server

mkdir -p "$COMPARTIDO"
chown ec1:ec1 "$COMPARTIDO"
chmod 775 "$COMPARTIDO"

LINEA="$COMPARTIDO 10.0.1.0/24(rw,sync,no_subtree_check)"
grep -qF "$COMPARTIDO " /etc/exports || echo "$LINEA" >> /etc/exports

systemctl enable --now nfs-kernel-server
exportfs -ra
exportfs -v
echo "[$(hostname)] nfs_main.sh OK"
