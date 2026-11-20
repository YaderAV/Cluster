# Encender, apagar, ver estado, respaldar, borrar o recrear el clúster.
# Uso: .\infra\gestionar.ps1 <accion>
#   estado    : estado e IPs de las 3 VMs
#   iniciar   : enciende las VMs (la IP de main no cambia)
#   detener   : apaga las VMs sin cobrar CPU (discos e IP siguen cobrando ~$0.35/día)
#   respaldar : copia ~/compartido de main a respaldos\compartido_<fecha> (main debe estar encendido)
#   eliminar  : respalda y borra TODO (VMs, discos, IP, red): costo $0 mientras no exista.
#               Si main está apagado no puede respaldar: enciéndelo antes, o usa -Forzar.
#   recrear   : vuelve a crear y configurar el clúster (15-20 min) y restaura resultados.txt
param(
    [Parameter(Mandatory)]
    [ValidateSet("estado", "iniciar", "detener", "respaldar", "eliminar", "recrear")]
    [string]$Accion,
    [string]$ResourceGroup = "rg-cluster-ec1",
    [switch]$Forzar   # eliminar sin respaldo
)
$Root      = Split-Path -Parent $PSScriptRoot
$Cfg       = Join-Path $Root "claves\ssh_config"
$Respaldos = Join-Path $Root "respaldos"

# Ejecuta az sin que el stderr detenga el script (PowerShell 5.1) y devuelve su salida.
function Get-Az {
    $prev = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try { $out = & az @args 2>$null } finally { $ErrorActionPreference = $prev }
    if ($LASTEXITCODE -ne 0) { return $null }
    return $out
}

function Get-EstadoMain {
    $s = Get-Az vm get-instance-view -g $ResourceGroup -n main `
        --query "instanceView.statuses[?starts_with(code,'PowerState/')].displayStatus | [0]" -o tsv
    if (-not $s) { return "no existe" }
    return "$s".Trim()
}

function Invoke-Respaldo {
    if (-not (Test-Path $Cfg)) { Write-Host "No existe claves\ssh_config." -ForegroundColor Red; return $false }
    $estado = Get-EstadoMain
    if ($estado -ne "VM running") {
        Write-Host "main está '$estado': no se puede respaldar. Enciéndelo con: .\infra\gestionar.ps1 iniciar" -ForegroundColor Yellow
        return $false
    }
    New-Item -ItemType Directory -Force $Respaldos | Out-Null
    $destino = Join-Path $Respaldos ("compartido_" + (Get-Date -Format "yyyyMMdd_HHmmss"))
    Write-Host "Copiando main:~/compartido a $destino ..." -ForegroundColor Cyan
    scp -F $Cfg -r -q main:compartido $destino
    if ($LASTEXITCODE -ne 0) { Write-Host "Falló la copia." -ForegroundColor Red; return $false }
    $n = @(Get-ChildItem $destino -Recurse -File).Count
    Write-Host "Respaldo listo: $n archivos en $destino" -ForegroundColor Green
    return $true
}

function Get-IdsVm { return @(Get-Az vm list -g $ResourceGroup --query "[].id" -o tsv) }

switch ($Accion) {
    "estado" {
        az vm list -d -g $ResourceGroup --query "[].{VM:name, Estado:powerState, IP_privada:privateIps, IP_publica:publicIps}" -o table
    }
    "iniciar" { az vm start --ids (Get-IdsVm) }
    "detener" { az vm deallocate --ids (Get-IdsVm) }   # deallocate: deja de cobrar la CPU
    "respaldar" { if (-not (Invoke-Respaldo)) { exit 1 } }

    "eliminar" {
        if (-not (Invoke-Respaldo)) {
            if (-not $Forzar) {
                Write-Host "No se borró nada. Enciende main y vuelve a intentarlo, o usa -Forzar para borrar sin respaldo." -ForegroundColor Yellow
                exit 1
            }
            Write-Host "Borrando SIN respaldo (-Forzar)." -ForegroundColor Yellow
        }
        az group delete -n $ResourceGroup --yes --no-wait
        Write-Host "Borrando $ResourceGroup en segundo plano (1-3 min). Para volver: .\infra\gestionar.ps1 recrear" -ForegroundColor Green
    }

    "recrear" {
        # Si el grupo todavía se está borrando, esperar a que termine
        if ((Get-Az group exists -n $ResourceGroup) -eq "true") {
            if ((Get-Az group show -n $ResourceGroup --query properties.provisioningState -o tsv) -eq "Deleting") {
                Write-Host "Esperando a que termine de borrarse $ResourceGroup..." -ForegroundColor Cyan
                az group wait -n $ResourceGroup --deleted
            }
        }
        # Las VMs nuevas tienen otras huellas SSH
        Remove-Item (Join-Path $Root "claves\known_hosts") -ErrorAction SilentlyContinue
        try {
            & (Join-Path $PSScriptRoot "crear_cluster.ps1") -ResourceGroup $ResourceGroup
            & (Join-Path $PSScriptRoot "configurar_cluster.ps1")
        } catch {
            Write-Host "Falló la recreación: $_" -ForegroundColor Red
            exit 1
        }
        # Restaurar resultados.txt del respaldo más reciente
        $ultimo = Get-ChildItem $Respaldos -Directory -Filter "compartido_*" -ErrorAction SilentlyContinue |
                  Sort-Object Name | Select-Object -Last 1
        if ($ultimo -and (Test-Path (Join-Path $ultimo.FullName "resultados.txt"))) {
            scp -F $Cfg -q (Join-Path $ultimo.FullName "resultados.txt") main:compartido/resultados.txt
            if ($LASTEXITCODE -eq 0) { Write-Host "resultados.txt restaurado desde $($ultimo.Name)" -ForegroundColor Green }
        }
        Write-Host "Si tus compañeros entran a main, pásales el nuevo claves\ssh_config (la IP cambió)." -ForegroundColor Yellow
    }
}
