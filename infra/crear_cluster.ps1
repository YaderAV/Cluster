# Crea el clúster en Azure: main + worker1 + worker2 en una red privada.
# Uso:  .\infra\crear_cluster.ps1                 (valores por defecto)
#       .\infra\crear_cluster.ps1 -Location chilecentral -Size Standard_B2als_v2
# Regiones permitidas en la suscripción: az policy assignment list -o json
#   (francecentral, belgiumcentral, chilecentral, northcentralus, canadacentral)
param(
    [string]$ResourceGroup = "rg-cluster-ec1",
    [string]$Location      = "northcentralus",
    [string]$Size          = "Standard_B2ats_v2",   # B1s no existe en northcentralus
    [string]$AdminUser     = "ec1",
    [string]$ApagadoUTC    = "0400"   # 04:00 UTC = 11:00 p.m. hora Colombia
)
$ErrorActionPreference = "Stop"

function Invoke-Az {
    & az @args
    if ($LASTEXITCODE -ne 0) { throw "Falló: az $($args -join ' ')" }
}

# Devuelve $true si el comando az funciona (p. ej. si un recurso existe), sin
# detener el script: en PowerShell 5.1 el stderr de az con "Stop" es un error fatal.
function Test-Az {
    $prev = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try { & az @args --output none 2>&1 | Out-Null } finally { $ErrorActionPreference = $prev }
    return ($LASTEXITCODE -eq 0)
}

$Root     = Split-Path -Parent $PSScriptRoot
$Image    = "Canonical:ubuntu-24_04-lts:server:latest"
$Vnet     = "vnet-cluster"
$Subnet   = "snet-cluster"
$Nodos    = [ordered]@{ main = "10.0.1.4"; worker1 = "10.0.1.5"; worker2 = "10.0.1.6" }

# --- 0. Sesión de Azure ---------------------------------------------------
if (-not (Test-Az account show)) { throw "No hay sesión de Azure. Ejecuta primero: az login" }
Write-Host "Suscripción: $(az account show --query name -o tsv)" -ForegroundColor Cyan

# --- 1. Claves SSH --------------------------------------------------------
$Claves = Join-Path $Root "claves"
New-Item -ItemType Directory -Force $Claves | Out-Null

# Clave personal (laptop -> main)
$UserKey = Join-Path $env:USERPROFILE ".ssh\id_ed25519"
if (-not (Test-Path $UserKey)) {
    New-Item -ItemType Directory -Force (Split-Path $UserKey) | Out-Null
    ssh-keygen -t ed25519 -N '""' -f $UserKey -C "$env:USERNAME@laptop"
}
# Clave del clúster (passwordless login entre main, worker1 y worker2)
$ClusterKey = Join-Path $Claves "cluster_ed25519"
if (-not (Test-Path $ClusterKey)) {
    ssh-keygen -t ed25519 -N '""' -f $ClusterKey -C "ec1@cluster"
}
# Claves públicas de los demás integrantes del grupo (claves_grupo\*.pub)
$PubKeys = @("$UserKey.pub", "$ClusterKey.pub")
$PubKeys += Get-ChildItem (Join-Path $Root "claves_grupo") -Filter *.pub -ErrorAction SilentlyContinue |
            ForEach-Object { $_.FullName }
Write-Host "Claves autorizadas: $($PubKeys.Count)" -ForegroundColor Cyan

# --- 2. Grupo de recursos, red y firewall ---------------------------------
# Si el grupo ya existe (aunque sea en otra región) se reutiliza: cada recurso lleva -l $Location
if (-not (Test-Az group show -n $ResourceGroup)) { Invoke-Az group create -n $ResourceGroup -l $Location --output none }
Write-Host "Región de los recursos: $Location" -ForegroundColor Cyan
Invoke-Az network vnet create -g $ResourceGroup -n $Vnet -l $Location `
    --address-prefix 10.0.0.0/16 --subnet-name $Subnet --subnet-prefix 10.0.1.0/24 --output none
# Salida a Internet para los workers (no tienen IP pública y necesitan apt).
# Azure ya no la habilita por defecto en redes nuevas; se activa antes de crear las VMs.
Invoke-Az network vnet subnet update -g $ResourceGroup --vnet-name $Vnet -n $Subnet `
    --default-outbound-access true --output none
Invoke-Az network nsg create -g $ResourceGroup -n nsg-main -l $Location --output none
Invoke-Az network nsg rule create -g $ResourceGroup --nsg-name nsg-main -n AllowSSH `
    --priority 1000 --access Allow --protocol Tcp --direction Inbound `
    --destination-port-ranges 22 --output none

# --- 3. Máquinas virtuales ------------------------------------------------
foreach ($nombre in $Nodos.Keys) {
    if (Test-Az vm show -g $ResourceGroup -n $nombre) {
        Write-Host "$nombre ya existe, no se vuelve a crear." -ForegroundColor Yellow
    } else {
        Write-Host "Creando $nombre ($($Nodos[$nombre]))..." -ForegroundColor Cyan
        $vmArgs = @("vm", "create", "-g", $ResourceGroup, "-n", $nombre, "-l", $Location,
            "--image", $Image, "--size", $Size,
            "--admin-username", $AdminUser, "--ssh-key-values") + $PubKeys + @(
            "--vnet-name", $Vnet, "--subnet", $Subnet,
            "--private-ip-address", $Nodos[$nombre],
            "--storage-sku", "StandardSSD_LRS", "--output", "none")
        if ($nombre -eq "main") {
            $vmArgs += @("--public-ip-sku", "Standard", "--nsg", "nsg-main")
        } else {
            $vmArgs += @("--public-ip-address", '""', "--nsg", '""')   # sin IP pública
        }
        Invoke-Az @vmArgs
    }
    # Apagado automático (siempre, para que quede aunque la VM ya existiera).
    # -l es obligatorio: sin él usa la región del grupo, que puede estar prohibida.
    Invoke-Az vm auto-shutdown -g $ResourceGroup -n $nombre -l $Location --time $ApagadoUTC --output none
}

# --- 4. ssh_config local para entrar fácil --------------------------------
$IpMain = (az vm show -d -g $ResourceGroup -n main --query publicIps -o tsv).Trim()
$SshExe = ((Get-Command ssh).Source) -replace '\\', '/'
$Cfg    = Join-Path $Claves "ssh_config"
$CfgF   = $Cfg -replace '\\', '/'
$KeyF   = $UserKey -replace '\\', '/'
$Known  = (Join-Path $Claves "known_hosts") -replace '\\', '/'

$comun = @"
  User $AdminUser
  IdentityFile "$KeyF"
  IdentitiesOnly yes
  StrictHostKeyChecking accept-new
  UserKnownHostsFile "$Known"
"@
$texto = "Host main`n  HostName $IpMain`n$comun`n"
foreach ($w in @("worker1", "worker2")) {
    $texto += "Host $w`n  HostName $($Nodos[$w])`n$comun`n  ProxyCommand `"$SshExe`" -F `"$CfgF`" -W %h:%p main`n`n"
}
[IO.File]::WriteAllText($Cfg, ($texto -replace "`r`n", "`n"), (New-Object Text.UTF8Encoding $false))

Write-Host ""
Write-Host "Clúster creado. IP pública de main: $IpMain" -ForegroundColor Green
Write-Host "Entrar:      ssh -F claves\ssh_config main"
Write-Host "Configurar:  .\infra\configurar_cluster.ps1"
