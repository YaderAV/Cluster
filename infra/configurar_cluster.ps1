# Sube los scripts a main y ejecuta allí la configuración completa
# (usuario/hosts, SSH sin contraseña, NFS, OpenMPI, tarea y verificación).
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$Cfg  = Join-Path $Root "claves\ssh_config"
if (-not (Test-Path $Cfg)) { throw "No existe claves\ssh_config. Ejecuta primero .\infra\crear_cluster.ps1" }

$archivos  = @(Get-ChildItem (Join-Path $Root "config") -File | ForEach-Object { $_.FullName })
$archivos += @(Get-ChildItem (Join-Path $Root "tarea")  -File | ForEach-Object { $_.FullName })
$archivos += @((Join-Path $Root "claves\cluster_ed25519"), (Join-Path $Root "claves\cluster_ed25519.pub"))

ssh -F $Cfg main "mkdir -p ~/setup"
if ($LASTEXITCODE -ne 0) { throw "No se pudo conectar a main." }
scp -F $Cfg @archivos main:setup/
if ($LASTEXITCODE -ne 0) { throw "Falló la copia de archivos a main." }

ssh -t -F $Cfg main "bash ~/setup/setup_main.sh"
