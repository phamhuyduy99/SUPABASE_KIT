# Invoke-DownloadBackup.ps1 – Tai backup tu VPS ve may
# Import module - dam bao load dung cach bat ke chay tu thu muc nao
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$modulePath = Join-Path $scriptDir "SupabaseKit.psm1"
if (Test-Path $modulePath) {
    Import-Module $modulePath -Force
} else {
    Write-Host "LOI: Khong tim thay module SupabaseKit.psm1 tai: $modulePath" -ForegroundColor Red
    exit 1
}
Write-Title "TAI FILE BACKUP TU VPS VE MAY"

$remote = Read-Host "Nhap dia chi VPS (user@ip)"
if ([string]::IsNullOrWhiteSpace($remote)) {
    Write-ErrorMsg "Ban phai nhap dia chi VPS."
    exit
}

$remoteDir = Read-Host "Duong dan thu muc backup tren VPS (vi du: /opt/supabase/backup)"
if ([string]::IsNullOrWhiteSpace($remoteDir)) { $remoteDir = "/opt/supabase/backup" }

$localDir = Read-Host "Thu muc luu tren may (mac dinh: $env:USERPROFILE\Downloads)"
if ([string]::IsNullOrWhiteSpace($localDir)) { $localDir = "$env:USERPROFILE\Downloads" }

Write-Info "Kiem tra ket noi SSH toi $remote..."
$test = ssh -o ConnectTimeout=10 -o BatchMode=yes $remote 'echo OK' 2>$null
if ($LASTEXITCODE -ne 0) { 
    Write-ErrorMsg "Khong the ket noi SSH den $remote."
    exit 
}
Write-Success "Ket noi SSH thanh cong."

Write-Info "Dang tim file backup moi nhat..."
$latestBackup = ssh $remote "ls -t $remoteDir/supabase-backup-*.tar.gz 2>/dev/null | head -1"
if ([string]::IsNullOrWhiteSpace($latestBackup)) { 
    Write-ErrorMsg "Khong tim thay file backup."
    exit 
}

$backupName = Split-Path $latestBackup -Leaf
Write-Info "File backup moi nhat: $backupName"

Write-Info "Dang tai $backupName ve $localDir..."
scp "$remote`:${latestBackup}" $localDir\
if ($LASTEXITCODE -eq 0) {
    Write-Success "Da tai thanh cong: $localDir\$backupName"
    
    if (Test-Path "$localDir\$backupName.sha256") {
        Write-Info "Dang kiem tra checksum..."
        $expected = Get-Content "$localDir\$backupName.sha256" | Select-Object -First 1
        $actual = (Get-FileHash -Path "$localDir\$backupName" -Algorithm SHA256).Hash
        
        # Handle formats like "hash  filename" or just "hash"
        $expectedHash = $expected.Split()[0]
        
        if ($actual -eq $expectedHash) { 
            Write-Success "Checksum hop le." 
        }
        else { 
            Write-WarningMsg "Checksum khong khop!" 
        }
    }
} else { 
    Write-ErrorMsg "Tai that bai." 
}