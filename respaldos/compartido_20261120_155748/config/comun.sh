#!/usr/bin/env bash
# Paso común para TODOS los nodos (se ejecuta con sudo).
# - Verifica que el usuario ec1 sea administrador
# - Registra los nombres del clúster en /etc/hosts
# - Ajusta la zona horaria e instala OpenMPI y el cliente NFS
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# Esperar a que cloud-init termine (evita choques con apt en VMs recién creadas)
cloud-init status --wait >/dev/null 2>&1 || true

# Usuario ec1 con privilegios de administrador (Azure lo crea como admin; lo garantizamos)
id ec1 >/dev/null 2>&1 || useradd -m -s /bin/bash ec1
usermod -aG sudo ec1
echo "ec1 ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-ec1
chmod 440 /etc/sudoers.d/90-ec1

# Nombres del clúster
sed -i '/# cluster-ec1$/d' /etc/hosts
cat >> /etc/hosts <<'EOF'
10.0.1.4 main # cluster-ec1
10.0.1.5 worker1 # cluster-ec1
10.0.1.6 worker2 # cluster-ec1
EOF

timedatectl set-timezone America/Bogota

APT="apt-get -q -y -o DPkg::Lock::Timeout=300"
$APT update
$APT install openmpi-bin libopenmpi-dev build-essential nfs-common python3

echo "[$(hostname)] comun.sh OK"
