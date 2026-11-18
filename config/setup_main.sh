#!/usr/bin/env bash
# Orquestador: se ejecuta en main como ec1 y configura todo el clúster.
set -euo pipefail
SETUP="$(cd "$(dirname "$0")" && pwd)"
COMPARTIDO=/home/ec1/compartido
WORKERS=(worker1 worker2)

paso() { echo; echo "=================== $* ==================="; }

paso "1/6 Usuario ec1, /etc/hosts y paquetes en main"
sudo bash "$SETUP/comun.sh"

paso "2/6 Clave SSH del clúster en main"
bash "$SETUP/instalar_clave.sh" "$SETUP"

paso "3/6 Servidor NFS en main"
sudo bash "$SETUP/nfs_main.sh"

for w in "${WORKERS[@]}"; do
  paso "4/6 Configurando $w"
  ssh "$w" "mkdir -p ~/setup"
  scp -q "$SETUP"/{comun.sh,instalar_clave.sh,nfs_worker.sh,cluster_ed25519,cluster_ed25519.pub} "$w":setup/
  ssh "$w" 'sudo bash ~/setup/comun.sh && bash ~/setup/instalar_clave.sh ~/setup && sudo bash ~/setup/nfs_worker.sh && rm -rf ~/setup'
done

paso "5/6 Proyecto en el folder compartido"
mkdir -p "$COMPARTIDO/config"
cp "$SETUP"/tarea.c "$SETUP"/ejecutar.sh "$SETUP"/analizar.py "$COMPARTIDO/"
cp "$SETUP"/*.sh "$COMPARTIDO/config/"      # scripts de configuración (sin claves privadas)
printf "worker1 slots=1\nworker2 slots=1\n" > "$COMPARTIDO/hostfile"
mpicc -O2 -Wall -o "$COMPARTIDO/tarea" "$COMPARTIDO/tarea.c"
chmod +x "$COMPARTIDO"/*.sh "$COMPARTIDO"/config/*.sh "$COMPARTIDO/tarea"
rm -f "$SETUP/cluster_ed25519"              # la privada ya quedó en ~/.ssh

paso "6/6 Verificación"
bash "$COMPARTIDO/config/verificar.sh"
