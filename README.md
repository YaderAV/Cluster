# Clúster MPI en Azure: Estructura del Computador I, Examen Final

Clúster de 3 servidores Ubuntu 24.04 en Azure: **main** (administración) y **worker1** y **worker2** (tareas). Comparten un folder por NFS y ejecutan tareas con OpenMPI.

```
                 Internet (solo SSH, puerto 22)
                          │
             ┌────────────▼────────────┐
             │  main     10.0.1.4      │  IP pública · servidor NFS · lanza mpirun
             │  /home/ec1/compartido   │
             └──────┬───────────┬──────┘
          red privada 10.0.1.0/24 (vnet-cluster)
             ┌──────▼─────┐ ┌───▼────────┐
             │ worker1    │ │ worker2    │   sin IP pública
             │ 10.0.1.5   │ │ 10.0.1.6   │   montan el compartido por NFS
             └────────────┘ └────────────┘
```

## Estructura del repositorio

| Ruta | Qué hace |
|---|---|
| `infra/crear_cluster.ps1` | Crea el grupo de recursos, la red, el firewall y las 3 VMs, con usuario `ec1` y apagado automático a las 11 p.m. |
| `infra/configurar_cluster.ps1` | Sube los scripts a main y configura todo el clúster |
| `infra/gestionar.ps1` | `estado`, `iniciar`, `detener`, `respaldar`, `eliminar` (respalda antes) o `recrear` el clúster |
| `config/comun.sh` | Configura el usuario ec1 con sudo, `/etc/hosts`, la zona horaria, OpenMPI y el cliente NFS (en todos los nodos) |
| `config/instalar_clave.sh` | Instala la clave del clúster para el login sin contraseña entre todos los nodos |
| `config/nfs_main.sh` / `nfs_worker.sh` | Exportan el folder compartido desde main y lo montan en los workers |
| `config/setup_main.sh` | Orquesta todos los pasos anteriores desde main |
| `config/verificar.sh` | Prueba SSH entre todos los nodos, lectura/escritura/ejecución en NFS y MPI |
| `tarea/tarea.c` | Tarea MPI: hostname, IP, fecha y hora con microsegundos, que se agregan a `resultados.txt` |
| `tarea/ejecutar.sh` | Ejecuta la tarea N veces en los workers |
| `tarea/analizar.py` | Calcula el desfase entre workers, el tiempo entre corridas y quién llega primero |

## Puesta en marcha (una sola persona crea el clúster)

1. **Activar Azure for Students** en https://azure.microsoft.com/free/students con el correo institucional. Da $100 de crédito y no pide tarjeta.
2. **Instalar Azure CLI** y abrir una terminal nueva:
   ```powershell
   winget install -e --id Microsoft.AzureCLI
   az login
   ```
3. Si PowerShell bloquea los scripts, ejecutar una vez:
   `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`
4. **Crear el clúster** (5 a 10 minutos):
   ```powershell
   .\infra\crear_cluster.ps1
   ```
5. **Configurarlo** (5 a 10 minutos). Al final debe aparecer `CLUSTER OK`:
   ```powershell
   .\infra\configurar_cluster.ps1
   ```
6. **Usarlo**:
   ```powershell
   ssh -F claves\ssh_config main
   ```
   Y ya dentro de main:
   ```bash
   cd ~/compartido
   ./ejecutar.sh 20          # 20 corridas en worker1 y worker2
   cat resultados.txt
   python3 analizar.py
   ```

## Costos (cuidar el crédito de $100)

- 3 VMs `Standard_B2ats_v2` (2 vCPU, 1 GB) en `northcentralus` cuestan unos **$0.03 por hora encendidas**. Los discos y la IP pública suman unos $10 al mes aunque las VMs estén apagadas.
- Las VMs se **apagan solas a las 11 p.m.** (hora Colombia). Igual conviene apagarlas al terminar cada sesión:
  `.\infra\gestionar.ps1 detener`. Para volver a encenderlas: `.\infra\gestionar.ps1 iniciar`. La IP de main no cambia.
- **Para no pagar nada entre sesiones largas** (con main encendido):
  - `.\infra\gestionar.ps1 eliminar` copia `~/compartido` a `respaldos\compartido_<fecha>` y luego borra todo. Si main está apagado no borra nada; `-Forzar` borra sin respaldo.
  - `.\infra\gestionar.ps1 recrear` vuelve a crear y configurar el clúster (15-20 min) y restaura `resultados.txt` del último respaldo. La IP de main cambia: hay que pasar el nuevo `claves\ssh_config` al grupo.
  - `.\infra\gestionar.ps1 respaldar` solo hace la copia, sin borrar.
- **Después del examen**, borrar todo con `.\infra\gestionar.ps1 eliminar`.

## Trabajo en grupo

- **El repositorio va en GitHub.** La carpeta `claves/` está en `.gitignore` porque tiene claves privadas: **nunca la suban**.
- **Para que alguien más entre a main**, esa persona deja su clave pública en `claves_grupo/` (ver `claves_grupo/LEEME.md`).
  - Quien creó el clúster le pasa por privado su `claves/ssh_config`.
  - Ese archivo trae rutas de Windows: cada integrante cambia `IdentityFile`, `UserKnownHostsFile` y `ProxyCommand` por las rutas de su propio equipo.

## Problemas comunes

| Error | Solución |
|---|---|
| `RequestDisallowedByAzure` / `RequestDisallowedByPolicy` | Azure for Students solo permite algunas regiones. Ver cuáles con `az policy assignment list -o json` (`listOfAllowedLocations`) y repetir con `-Location <region>` (p. ej. `northcentralus`, `canadacentral`, `chilecentral`). |
| `SkuNotAvailable` | Ese tamaño de VM no está disponible en la región. Ver los disponibles con `az vm list-skus -l <region> --size Standard_B -o table`. En `northcentralus` hay `Standard_B2ats_v2` y `Standard_B2als_v2`; en `chilecentral`, los mismos. Evitar los `...pts_v2` (son ARM). |
| `QuotaExceeded` | Azure for Students tiene un límite de vCPU por región. Las 3 B2ats_v2 usan 6 vCPU; si no caben, crear el clúster en otra región permitida o pedir aumento de cuota. |
| `mpirun` se queda colgado | Revisar que `/etc/hosts` esté igual en los 3 nodos y correr `config/verificar.sh`. |
