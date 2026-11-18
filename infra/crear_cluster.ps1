# Crea el clúster en Azure: main + worker1 + worker2 en una red privada.
# Uso:  .\infra\crear_cluster.ps1                 (valores por defecto)
#       .\infra\crear_cluster.ps1 -Location centralus -Size Standard_B2ats_v2
param(
    [string]$ResourceGroup = "rg-cluster-ec1",
    [string]$Location      = "eastus2",
    [string]$Size          = "Standard_B1s",
    [string]$AdminUser     = "ec1",
    [string]$ApagadoUTC    = "0400"   # 04:00 UTC = 11:00 p.m. hora Colombia
)
$ErrorActionPreference = "Stop"

function Invoke-Az {
    & az @args
    if ($LASTEXITCODE -ne 0) { throw "Falló: az $($args -join ' ')" }
}

$Root     = Split-Path -Parent $PSScriptRoot
$Image    = "Canonical:ubuntu-24_04-lts:server:latest"
$Vnet     = "vnet-cluster"
$Subnet   = "snet-cluster"
$Nodos    = [ordered]@{ main = "10.0.1.4"; worker1 = "10.0.1.5"; worker2 = "10.0.1.6" }

# --- 0. Sesión de Azure ---------------------------------------------------
& az account show --output none 2>$null
if ($LASTEXITCODE -ne 0) { throw "No hay sesión de Azure. Ejecuta primero: az login" }
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
Invoke-Az group create -n $ResourceGroup -l $Location --output none
Invoke-Az network vnet create -g $ResourceGroup -n $Vnet `
    --address-prefix 10.0.0.0/16 --subnet-name $Subnet --subnet-prefix 10.0.1.0/24 --output none
Invoke-Az network nsg create -g $ResourceGroup -n nsg-main --output none
Invoke-Az network nsg rule create -g $ResourceGroup --nsg-name nsg-main -n AllowSSH `
    --priority 1000 --access Allow --protocol Tcp --direction Inbound `
    --destination-port-ranges 22 --output none

# --- 3. Máquinas virtuales ------------------------------------------------
foreach ($nombre in $Nodos.Keys) {
    & az vm show -g $ResourceGroup -n $nombre --output none 2>$null
    if ($LASTEXITCODE -eq 0) { Write-Host "$nombre ya existe, se omite." -ForegroundColor Yellow; continue }

    Write-Host "Creando $nombre ($($Nodos[$nombre]))..." -ForegroundColor Cyan
    $vmArgs = @("vm", "create", "-g", $ResourceGroup, "-n", $nombre,
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
    Invoke-Az vm auto-shutdown -g $ResourceGroup -n $nombre --time $ApagadoUTC --output none
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
