# Invoke-Freeze.ps1 – Sao luu Supabase tren Windows (da nen tang)
# Import module - dam bao load dung cach bat ke chay tu thu muc nao
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$modulePath = Join-Path $scriptDir "SupabaseKit.psm1"
if (Test-Path $modulePath) {
    Import-Module $modulePath -Force
} else {
    Write-Host "LOI: Khong tim thay module SupabaseKit.psm1 tai: $modulePath" -ForegroundColor Red
    exit 1
}

Write-Title "DONG BANG HE THONG (BACKUP DA NEN TANG)"

# ---------- KIEM TRA MOI TRUONG ----------
Write-Step 0 8 "KIEM TRA MOI TRUONG"
if (!(Test-DockerAvailable)) { exit 1 }
if (!(Test-Network)) { exit 1 }
Write-Success "Moi truong Docker va mang on dinh."

# Xac dinh thu muc du an
$projectDir = Find-SupabaseDir (Get-Location).Path
if (-not $projectDir) {
    do { $projectDir = Read-Host "Nhap duong dan thu muc Supabase (chua .env va docker-compose.yml)" }
    until (Test-SupabaseDir $projectDir)
}

# ---------- KIEM TRA DATABASE ----------
Write-Step 1 8 "KIEM TRA CONTAINER DATABASE"
$dbContainer = Find-DatabaseContainer
if (-not $dbContainer) {
    Write-ErrorMsg "Khong tim thay container database dang chay. Hay khoi dong Supabase truoc."
    exit 1
}
Write-Info "Container database: $dbContainer"

# ---------- DONG BO (TUY CHON) ----------
Write-Step 2 8 "DONG BO (TUY CHON)"
$remote = Read-Host "Nhap user@IP cua VPS du phong (Enter neu khong dong bo)"

# ---------- GOOGLE DRIVE (TUY CHON) ----------
Write-Step 3 8 "GOOGLE DRIVE (TUY CHON)"
$uploadDrive = $false
if (Get-Command rclone -ErrorAction SilentlyContinue) {
    $remotes = rclone listremotes 2>$null
    if ($remotes -match "^gdrive:") {
        $uploadDrive = (Read-Host "Upload len Google Drive? (y/n)") -eq 'y'
    } else { Write-WarningMsg "Google Drive chua duoc cau hinh (rclone). Bo qua upload." }
} else { Write-WarningMsg "rclone chua cai. Bo qua upload." }

# ---------- CHUAN BI THU MUC ----------
Write-Step 4 8 "CHUAN BI THU MUC BACKUP"
$timestamp = Get-Date -Format "dd_MM_yyyy_HH_mm_ss"
$backupRoot = Join-Path $env:TEMP "supabase-freeze-$timestamp"
$packDir = Join-Path $backupRoot "supabase-backup-$timestamp"
$backupDataDir = Join-Path $packDir "backup_data"
$linuxDir = Join-Path $packDir "linux"
$windowsDir = Join-Path $packDir "windows"
New-Item -ItemType Directory -Path $backupDataDir, $linuxDir, $windowsDir -Force | Out-Null

# ---------- DONG GOI SCRIPT ----------
Write-Step 5 8 "DONG GOI SCRIPT KIT"
$kitRoot = Split-Path $PSScriptRoot -Parent  # thu muc chua linux/ va windows/
if (Test-Path "$kitRoot\linux") {
    Copy-Item "$kitRoot\linux\*.sh" $linuxDir
    Copy-Item "$kitRoot\README.md" $packDir -ErrorAction SilentlyContinue
}
Copy-Item "$PSScriptRoot\*.ps1" $windowsDir
Copy-Item "$PSScriptRoot\*.psm1" $windowsDir

# Tao restore-windows.ps1 tu dong
@'
# restore-windows.ps1 – Khoi phuc Supabase tu backup tren Windows (tu dong)
# Import module - dam bao load dung cach bat ke chay tu thu muc nao
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$modulePath = Join-Path $scriptDir "windows\SupabaseKit.psm1"
if (Test-Path $modulePath) {
    Import-Module $modulePath -Force
} else {
    Write-Host "LOI: Khong tim thay module SupabaseKit.psm1 tai: $modulePath" -ForegroundColor Red
    pause; exit 1
}

Write-Title "KHOI PHUC SUPABASE TU BACKUP"

$backupDataDir = Join-Path $PSScriptRoot "backup_data"
if (!(Test-Path $backupDataDir)) {
    Write-ErrorMsg "Khong tim thay thu muc backup_data. Hay dam bao ban da giai nen dung cach."
    pause; exit 1
}

$targetDir = Read-Host "Thu muc cai dat (mac dinh C:\supabase-restored)"
if ([string]::IsNullOrWhiteSpace($targetDir)) { $targetDir = "C:\supabase-restored" }
New-Item -ItemType Directory -Path $targetDir -Force | Out-Null

Copy-Item "$backupDataDir\config\.env" $targetDir
Copy-Item "$backupDataDir\config\docker-compose.yml" $targetDir
$volDir = Join-Path $backupDataDir "volumes"
if (Test-Path $volDir) { Copy-Item "$volDir\*" $targetDir -Recurse }

$composePath = Join-Path $targetDir "docker-compose.yml"
$content = Get-Content $composePath -Raw
if ($content -match "ip_unprivileged_port_start") {
    $content -replace '.*ip_unprivileged_port_start.*','' | Set-Content $composePath
    Write-WarningMsg "Da sua cau hinh sysctl de tuong thich."
}

Set-Location $targetDir
docker compose -f docker-compose.yml up -d 2>$null
if ($LASTEXITCODE -ne 0) { Start-Sleep 5; docker compose -f docker-compose.yml up -d }

$dbContainer = docker ps --format ".Names" | Select-String "supabase.*db|db" | Select-Object -First 1
if ($dbContainer) {
    for ($i=0; $i -lt 10; $i++) { if (docker exec $dbContainer pg_isready -U postgres 2>$null) { break }; Start-Sleep -Seconds 3 }
    $sqlGz = Join-Path $backupDataDir "database\full_backup.sql.gz"
    if (Test-Path $sqlGz) {
        $sqlOut = Join-Path $env:TEMP "restore.sql"
        $in = [System.IO.File]::OpenRead($sqlGz)
        $gzip = New-Object System.IO.Compression.GzipStream($in, [System.IO.Compression.CompressionMode]::Decompress)
        $out = [System.IO.File]::Create($sqlOut)
        $gzip.CopyTo($out)
        $gzip.Close(); $in.Close(); $out.Close()
        Get-Content $sqlOut | docker exec -i $dbContainer psql -U postgres
        Remove-Item $sqlOut
        Write-Host "[OK] Database da duoc phuc hoi." -ForegroundColor Green
    }
    $storageTar = Join-Path $backupDataDir "storage\storage.tar.gz"
    if (Test-Path $storageTar) {
        $storageVol = docker volume ls --format ".Name" | Select-String "_storage"
        if ($storageVol) {
            docker run --rm -v ${storageVol}:/mnt/storage -v "${backupDataDir}\storage:/backup:ro" alpine sh -c "cd /mnt/storage && tar xzf /backup/storage.tar.gz"
        } elseif (Test-Path "$targetDir\volumes\storage") {
            tar xzf $storageTar -C "$targetDir\volumes\storage"
        }
        Write-Host "[OK] Storage da duoc phuc hoi." -ForegroundColor Green
    }
}

$ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.InterfaceAlias -notmatch "Loopback"} | Select-Object -First 1).IPAddress
Write-Host "======================================" -ForegroundColor Green
Write-Host "  HOAN TAT KHOI PHUC!" -ForegroundColor Green
Write-Host "  Truy cap Studio: http://${ip}:8000" -ForegroundColor Yellow
$envContent = Get-Content "$targetDir\.env"
$adminEmail = ($envContent | Select-String '^ADMIN_EMAIL=') -replace 'ADMIN_EMAIL=', ''
$adminPass = ($envContent | Select-String '^ADMIN_PASSWORD=') -replace 'ADMIN_PASSWORD=', ''
Write-Host "  Email: $adminEmail" -ForegroundColor White
Write-Host "  Mat khau: $adminPass" -ForegroundColor White
Write-Host "======================================" -ForegroundColor Green
pause
'@ | Set-Content -Path (Join-Path $packDir "restore-windows.ps1")
Copy-Item (Join-Path $packDir "restore-windows.ps1") $windowsDir

Write-Success "Da dinh kem script cho ca Linux & Windows."

# ---------- SAO LUU CAU HINH ----------
Write-Step 6 8 "SAO LUU CAU HINH & VOLUMES"
Copy-Item "$projectDir\.env" $backupDataDir
Copy-Item "$projectDir\docker-compose.yml" $backupDataDir
$volDir = Join-Path $projectDir "volumes"
if (Test-Path $volDir) {
    $destVol = Join-Path $backupDataDir "volumes"
    New-Item -ItemType Directory -Path $destVol -Force | Out-Null
    Get-ChildItem $volDir -Directory | Where-Object { $_.Name -ne 'db' -and $_.Name -ne 'logs' } | ForEach-Object {
        Copy-Item $_.FullName "$destVol\" -Recurse
    }
    $dbInit = Join-Path $volDir "db\init"
    if (Test-Path $dbInit) {
        New-Item -ItemType Directory -Path "$destVol\db" -Force | Out-Null
        Copy-Item $dbInit "$destVol\db\" -Recurse
    }
}

# ---------- BACKUP DATABASE ----------
Write-Step 7 8 "BACKUP DATABASE"
$sqlFile = Join-Path $backupDataDir "full_backup.sql.gz"
$dump = & docker exec $dbContainer pg_dumpall -U postgres
if ($LASTEXITCODE -eq 0) {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($dump)
    $fs = [System.IO.File]::Create($sqlFile)
    $gzip = New-Object System.IO.Compression.GzipStream($fs, [System.IO.Compression.CompressionMode]::Compress)
    $gzip.Write($bytes, 0, $bytes.Length)
    $gzip.Close(); $fs.Close()
    Write-Success "Database da duoc backup."
} else { Write-ErrorMsg "Backup database that bai."; exit 1 }

# Backup storage
$storageVol = Find-StorageVolume
if ($storageVol) {
    $storageDir = Join-Path $backupDataDir "storage"
    New-Item -ItemType Directory -Path $storageDir -Force | Out-Null
    docker run --rm -v ${storageVol}:/mnt/storage:ro -v "${storageDir}:/backup" alpine sh -c "cd /mnt/storage && tar czf /backup/storage.tar.gz ."
} elseif (Test-Path "$projectDir\volumes\storage") {
    $storageDir = Join-Path $backupDataDir "storage"
    New-Item -ItemType Directory -Path $storageDir -Force | Out-Null
    tar czf "$storageDir\storage.tar.gz" -C "$projectDir\volumes\storage" . 2>$null
}

# ---------- DONG GOI FILE ----------
Write-Step 8 8 "DONG GOI FILE BACKUP"
$backupFile = Join-Path "$env:USERPROFILE\Desktop" "supabase-backup-$timestamp.tar.gz"
if (Get-Command "7z" -ErrorAction SilentlyContinue) {
    Set-Location $backupRoot; 7z a -ttar temp.tar (Split-Path -Leaf $packDir) | Out-Null; 7z a -tgzip $backupFile temp.tar | Out-Null; Remove-Item temp.tar; Set-Location $PSScriptRoot
} elseif (Get-Command "tar" -ErrorAction SilentlyContinue) {
    tar -czf $backupFile -C $backupRoot (Split-Path -Leaf $packDir)
} else {
    Write-WarningMsg "Can 7-Zip hoac Git for Windows de tao .tar.gz. Backup se duoc luu dang .zip."
    $backupFile = Join-Path "$env:USERPROFILE\Desktop" "supabase-backup-$timestamp.zip"
    Compress-Archive -Path $packDir -DestinationPath $backupFile
}
Write-Success "Backup thanh cong: $backupFile"
Get-FileChecksum $backupFile

# Dong bo SSH / Upload GDrive / Task Scheduler
if ($remote) { scp $backupFile "${remote}:supabase_self_host_backup/" }
if ($uploadDrive) { Invoke-GDriveUpload $backupFile }
$auto = Read-Host "Ban co muon tu dong backup hang ngay luc 2h sang? (y/n)"
if ($auto -eq 'y') {
    $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-File `"$PSScriptRoot\Invoke-Freeze.ps1`""
    $trigger = New-ScheduledTaskTrigger -Daily -At "02:00"
    Register-ScheduledTask -TaskName "SupabaseBackup" -Action $action -Trigger $trigger -User $env:USERNAME
    Write-Success "Da tao lich backup tu dong."
}

Remove-TempDir $backupRoot