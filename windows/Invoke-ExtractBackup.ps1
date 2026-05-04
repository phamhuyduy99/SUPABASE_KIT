# Invoke-ExtractBackup.ps1 – Giai nen backup
# Import module - dam bao load dung cach bat ke chay tu thu muc nao
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$modulePath = Join-Path $scriptDir "SupabaseKit.psm1"
if (Test-Path $modulePath) {
    Import-Module $modulePath -Force
} else {
    Write-Host "LOI: Khong tim thay module SupabaseKit.psm1 tai: $modulePath" -ForegroundColor Red
    exit 1
}
Write-Title "GIAI NEN BACKUP SUPABASE"

$currentDir = Get-Location
$backupFile = Get-ChildItem -Path $currentDir -Filter "supabase-backup-*.tar.gz" | Sort-Object LastWriteTime -Descending | Select-Object -First 1

if (-not $backupFile) {
    Write-ErrorMsg "Khong tim thay file backup .tar.gz."
    exit 1
}

Write-Info "Dang giai nen: $($backupFile.Name)"

try {
    if (Get-Command "7z" -ErrorAction SilentlyContinue) {
        Write-Info "Su dung 7-Zip de giai nen..."
        7z x $backupFile.FullName -y | Out-Null
    }
    elseif (Get-Command "tar" -ErrorAction SilentlyContinue) {
        Write-Info "Su dung tar de giai nen..."
        tar -xzf $backupFile.FullName
    }
    else {
        Write-ErrorMsg "Can cai dat 7-Zip hoac Git for Windows de giai nen file .tar.gz"
        exit 1
    }
    
    Write-Success "Giai nen thanh cong!"
    Write-Info "Thu muc backup da duoc tao tai: $(Join-Path $currentDir ($backupFile.BaseName))"
}
catch {
    Write-ErrorMsg "Loi khi giai nen: $($_.Exception.Message)"
    exit 1
}