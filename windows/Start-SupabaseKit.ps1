# Start-SupabaseKit.ps1 – Menu chinh cho Windows
# Import module - dam bao load dung cach bat ke chay tu thu muc nao
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$modulePath = Join-Path $scriptDir "SupabaseKit.psm1"
if (Test-Path $modulePath) {
    Import-Module $modulePath -Force
} else {
    Write-Host "LOI: Khong tim thay module SupabaseKit.psm1 tai: $modulePath" -ForegroundColor Red
    exit 1
}

Write-Title "SUPABASE KIT CHO WINDOWS"

if ((Get-ExecutionPolicy -Scope CurrentUser) -ne "RemoteSigned") {
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
}

function Setup-AutoBackup {
    $scriptPath = Join-Path $PSScriptRoot "Invoke-Freeze.ps1"
    $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -File `"$scriptPath`""
    $trigger = New-ScheduledTaskTrigger -Daily -At "02:00"
    Register-ScheduledTask -TaskName "SupabaseDailyBackup" -Action $action -Trigger $trigger -Description "Supabase backup" -User $env:USERNAME
    Write-Success "Da thiet lap backup hang ngay luc 2h sang."
}

function Setup-HttpsDomain {
    Write-WarningMsg "Chuc nang cai HTTPS tren Windows dang phat trien."
}

function Setup-GoogleDrive {
    & ".\Invoke-SetupGDrive.ps1"
}

while ($true) {
    Clear-Host
    Write-Host "======================================" -ForegroundColor Magenta
    Write-Host "   SUPABASE KIT CHO WINDOWS" -ForegroundColor White
    Write-Host "======================================" -ForegroundColor Magenta
    Write-Host "1. Dong bang he thong (Backup)" -ForegroundColor White
    Write-Host "2. Khoi phuc he thong (Restore)" -ForegroundColor White
    Write-Host "3. Cai HTTPS & domain" -ForegroundColor White
    Write-Host "4. Kiem tra trang thai" -ForegroundColor White
    Write-Host "5. Thiet lap tu dong backup" -ForegroundColor White
    Write-Host "6. Cau hinh Google Drive" -ForegroundColor White
    Write-Host "7. Kiem tra tuong thich VPS" -ForegroundColor White
    Write-Host "8. Tai backup tu VPS ve may" -ForegroundColor White
    Write-Host "0. Thoat" -ForegroundColor White
    Write-Host "======================================" -ForegroundColor Magenta
    $choice = Read-Host "Nhap lua chon"

    switch ($choice) {
        '1' { & ".\Invoke-Freeze.ps1" }
        '2' { & ".\Invoke-Restore.ps1" }
        '3' { Setup-HttpsDomain }
        '4' { & ".\Invoke-Status.ps1" }
        '5' { Setup-AutoBackup }
        '6' { Setup-GoogleDrive }
        '7' { & ".\Invoke-CheckEnv.ps1" }
        '8' { & ".\Invoke-DownloadBackup.ps1" }
        '0' { Write-Success "Tam biet!"; exit }
        default { Write-ErrorMsg "Lua chon khong hop le."; Start-Sleep -Seconds 2 }
    }
    Read-Host "Nhan Enter de tiep tuc"
}