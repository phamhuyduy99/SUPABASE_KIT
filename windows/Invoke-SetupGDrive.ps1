# Invoke-SetupGDrive.ps1 – Cau hinh Google Drive cho rclone
# Import module - dam bao load dung cach bat ke chay tu thu muc nao
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$modulePath = Join-Path $scriptDir "SupabaseKit.psm1"
if (Test-Path $modulePath) {
    Import-Module $modulePath -Force
} else {
    Write-Host "LOI: Khong tim thay module SupabaseKit.psm1 tai: $modulePath" -ForegroundColor Red
    exit 1
}

Write-Title "CAU HINH GOOGLE DRIVE"
if (!(Get-Command rclone -ErrorAction SilentlyContinue)) {
    Write-ErrorMsg "rclone chua duoc cai dat."
    Write-Info "Tai rclone tu https://rclone.org/downloads/ va cai dat, sau do chay lai script nay."
    exit
}

Write-Info "Mo terminal tren may ca nhan va chay: rclone authorize `"drive`""
$token = Read-Host "Dan token JSON vao day"
if ($token) {
    $configPath = "$env:USERPROFILE\.config\rclone\rclone.conf"
    if (!(Test-Path $configPath)) { New-Item -Path $configPath -Force | Out-Null }
    
    # Remove existing gdrive config if present to avoid duplicates
    if (Test-Path $configPath) {
        $content = Get-Content $configPath -Raw
        if ($content -match '(?s)\[gdrive\].*?(?=\n\[|\z)') {
            $content = $content -replace '(?s)\[gdrive\].*?(?=\n\[|\z)', ''
            Set-Content -Path $configPath -Value $content -NoNewline
        }
    }

    @"
[gdrive]
type = drive
scope = drive
token = $token
"@ | Add-Content $configPath
    Write-Success "Da cau hinh Google Drive."
} else { 
    Write-ErrorMsg "Token trong." 
}