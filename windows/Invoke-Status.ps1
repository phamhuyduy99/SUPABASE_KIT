# Invoke-Status.ps1 – Kiem tra container Supabase
# Import module - dam bao load dung cach bat ke chay tu thu muc nao
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$modulePath = Join-Path $scriptDir "SupabaseKit.psm1"
if (Test-Path $modulePath) {
    Import-Module $modulePath -Force
} else {
    Write-Host "LOI: Khong tim thay module SupabaseKit.psm1 tai: $modulePath" -ForegroundColor Red
    exit 1
}
Write-Title "TRANG THAI CONTAINER"
if (!(Get-Command docker -ErrorAction SilentlyContinue)) { Write-ErrorMsg "Docker chua cai."; exit }
$containers = docker ps --format "table .Names`t.Status`t.Ports" 2>$null
if ($containers) {
    $containers | ForEach-Object {
        if ($_ -match "Up") { Write-Host $_ -ForegroundColor Green }
        elseif ($_ -match "Exited|Dead") { Write-Host $_ -ForegroundColor Yellow }
        else { Write-Host $_ }
    }
} else { Write-WarningMsg "Khong co container nao dang chay." }

# Additional status check for Supabase services
Write-Info "Kiem tra cac dich vu Supabase..."
$composeFile = Join-Path (Get-Location) "docker-compose.yml"
if (Test-Path $composeFile) {
    $composeCmd = Get-DockerComposeCommand
    $services = & $composeCmd -f $composeFile config --services 2>$null
    if ($services) {
        Write-Info "Dich vu Supabase:"
        foreach ($service in $services) {
            if ($service) {
                $status = & $composeCmd -f $composeFile ps $service --format "table {{.Service}}`t{{.Status}}`t{{.Publishers}}"
                Write-Host $status
            }
        }
    }
} else {
    Write-WarningMsg "Khong tim thay docker-compose.yml trong thu muc hien tai."
}