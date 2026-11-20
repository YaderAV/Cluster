#!/usr/bin/env bash
# Instala la clave del clúster para ec1 => passwordless login entre todos los nodos.
# Uso: bash instalar_clave.sh <directorio-con-cluster_ed25519>
set -euo pipefail
SRC="${1:?Indica el directorio que contiene cluster_ed25519}"

install -d -m 700 ~/.ssh
install -m 600 "$SRC/cluster_ed25519"     ~/.ssh/id_ed25519
install -m 644 "$SRC/cluster_ed25519.pub" ~/.ssh/id_ed25519.pub

PUB="$(cat "$SRC/cluster_ed25519.pub")"
touch ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys
grep -qxF "$PUB" ~/.ssh/authorized_keys || echo "$PUB" >> ~/.ssh/authorized_keys

cat > ~/.ssh/config <<'EOF'
Host main worker1 worker2
  User ec1
  StrictHostKeyChecking accept-new
EOF
chmod 600 ~/.ssh/config

echo "[$(hostname)] instalar_clave.sh OK"
