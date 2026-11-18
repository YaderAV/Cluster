# Encender, apagar (sin cobrar CPU), ver estado o borrar el clúster.
# Uso: .\infra\gestionar.ps1 estado | iniciar | detener | eliminar
param(
    [Parameter(Mandatory)][ValidateSet("estado", "iniciar", "detener", "eliminar")][string]$Accion,
    [string]$ResourceGroup = "rg-cluster-ec1"
)
$ids = az vm list -g $ResourceGroup --query "[].id" -o tsv
switch ($Accion) {
    "estado"   { az vm list -d -g $ResourceGroup --query "[].{VM:name, Estado:powerState, IP_privada:privateIps, IP_publica:publicIps}" -o table }
    "iniciar"  { az vm start --ids $ids }
    "detener"  { az vm deallocate --ids $ids }   # deallocate: deja de cobrar la CPU
    "eliminar" { az group delete -n $ResourceGroup --yes --no-wait; Write-Host "Borrando $ResourceGroup en segundo plano." }
}
