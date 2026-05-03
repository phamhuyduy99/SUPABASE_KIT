# Invoke-Freeze.ps1 – Sao lưu Supabase trên Windows (đa nền tảng)
# Yêu cầu: Docker Desktop đang chạy, thư mục dự án Supabase hợp lệ
# Đầu ra: file .tar.gz chứa linux/ và windows/ với cấu trúc đầy đủ

Import-Module .\SupabaseKit.psm1 -Force

Write-Title "ĐÓNG BĂNG HỆ THỐNG (BACKUP ĐA NỀN TẢNG)"

# ---------- KIỂM TRA MÔI TRƯỜNG ----------
Write-Step 0 8 "KIỂM TRA MÔI TRƯỜNG"
if (!(Test-DockerAvailable)) { exit 1 }
if (!(Test-Network)) { exit 1 }
Write-Success "Môi trường Docker và mạng ổn định."

# ---------- XÁC ĐỊNH THƯ MỤC DỰ ÁN ----------
$projectDir = Find-SupabaseDir (Get-Location).Path
if (-not $projectDir) {
    do {
        $projectDir = Read-Host "Nhập đường dẫn thư mục dự án Supabase (chứa .env và docker-compose.yml)"
    } until (Test-SupabaseDir $projectDir)
}
Write-Info "Thư mục dự án: $projectDir"

# ---------- KIỂM TRA CONTAINER DATABASE ----------
Write-Step 1 8 "KIỂM TRA CONTAINER DATABASE"
$dbContainer = Find-DatabaseContainer
if (-not $dbContainer) {
    Write-ErrorMsg "Không tìm thấy container database đang chạy. Hãy khởi động Supabase trước."
    exit 1
}
Write-Info "Container database: $dbContainer"

# ---------- NHẬP THÔNG TIN ĐỒNG BỘ (SSH) ----------
Write-Step 2 8 "ĐỒNG BỘ TỪ XA (TÙY CHỌN)"
$remote = Read-Host "Nhập user@IP của VPS dự phòng (Enter nếu không đồng bộ)"
$syncSsh = $false
if ($remote) {
    Write-WarningMsg "Đồng bộ sẽ sử dụng scp. Đảm bảo SSH key đã được cấu hình."
    $syncSsh = $true
}

# ---------- HỎI UPLOAD GOOGLE DRIVE ----------
Write-Step 3 8 "UPLOAD GOOGLE DRIVE (TÙY CHỌN)"
$uploadGDrive = $false
if (Get-Command rclone -ErrorAction SilentlyContinue) {
    $remotes = rclone listremotes 2>$null
    if ($remotes -match "^gdrive:") {
        $uploadGDrive = (Read-Host "Upload lên Google Drive? (y/n)") -eq 'y'
    } else {
        Write-WarningMsg "Google Drive chưa được cấu hình (rclone). Bỏ qua upload."
    }
} else {
    Write-WarningMsg "rclone chưa cài. Bỏ qua upload."
}

# ---------- CHUẨN BỊ THƯ MỤC BACKUP ----------
Write-Step 4 8 "CHUẨN BỊ THƯ MỤC BACKUP"
$timestamp = Get-Date -Format "dd_MM_yyyy_HH_mm_ss"
$backupRoot = Join-Path $env:TEMP "supabase-freeze-$timestamp"
$packDir = Join-Path $backupRoot "supabase-backup-$timestamp"
$backupDataDir = Join-Path $packDir "backup_data"
$linuxDir = Join-Path $packDir "linux"
$windowsDir = Join-Path $packDir "windows"

# Tạo cấu trúc thư mục
New-Item -ItemType Directory -Path $backupDataDir, $linuxDir, $windowsDir -Force | Out-Null

# ---------- COPY SCRIPT LINUX ----------
Write-Step 5 8 "ĐÓNG GÓI SCRIPT LINUX"
$kitRoot = Split-Path $PSScriptRoot -Parent  # thư mục chứa linux/ và windows/
if (Test-Path "$kitRoot\linux") {
    Copy-Item -Path "$kitRoot\linux\*.sh" -Destination $linuxDir
    Copy-Item -Path "$kitRoot\linux\common.sh" -Destination $linuxDir -ErrorAction SilentlyContinue
    Copy-Item -Path "$kitRoot\README.txt" -Destination $packDir -ErrorAction SilentlyContinue
    Write-Success "Đã sao chép script Linux."
} else {
    Write-WarningMsg "Không tìm thấy thư mục linux/. Chỉ backup Windows."
}

# ---------- COPY SCRIPT WINDOWS ----------
Write-Step 6 8 "ĐÓNG GÓI SCRIPT WINDOWS"
Copy-Item -Path "$PSScriptRoot\*.ps1" -Destination $windowsDir
Copy-Item -Path "$PSScriptRoot\*.psm1" -Destination $windowsDir
Write-Success "Đã sao chép script Windows."

# Tạo script restore độc lập cho Windows (đặt ở cả gốc và windows/)
$restoreScript = Join-Path $packDir "restore-windows.ps1"
@'
# restore-windows.ps1 – Khôi phục Supabase từ backup trên Windows
# Yêu cầu: Docker Desktop, giải nén file backup trước khi chạy script này.

Write-Host "KHÔI PHỤC SUPABASE TRÊN WINDOWS" -ForegroundColor Cyan
$backupDataDir = Join-Path $PSScriptRoot "backup_data"
if (!(Test-Path $backupDataDir)) {
    Write-Host "Không tìm thấy backup_data. Đảm bảo bạn đã giải nén đúng cách." -ForegroundColor Red
    pause; exit 1
}
$targetDir = Read-Host "Thư mục cài đặt (mặc định C:\supabase-restored)"
if ([string]::IsNullOrWhiteSpace($targetDir)) { $targetDir = "C:\supabase-restored" }
New-Item -ItemType Directory -Path $targetDir -Force | Out-Null

# Copy cấu hình
Copy-Item "$backupDataDir\config\.env" $targetDir
Copy-Item "$backupDataDir\config\docker-compose.yml" $targetDir

# Phục hồi volumes
$volDir = Join-Path $backupDataDir "volumes"
if (Test-Path $volDir) { Copy-Item "$volDir\*" $targetDir -Recurse }

# Khởi động Supabase
Set-Location $targetDir
docker compose -f docker-compose.yml up -d 2>$null
if ($LASTEXITCODE -ne 0) {
    # Xử lý sysctl
    (Get-Content docker-compose.yml -Raw) -replace '.*ip_unprivileged_port_start.*','' | Set-Content docker-compose.yml
    docker compose -f docker-compose.yml up -d
}

# Import database và storage nếu có
$dbContainer = docker ps --format ".Names" | Select-String "supabase.*db|db" | Select-Object -First 1
if ($dbContainer) {
    # Chờ DB sẵn sàng
    for ($i=0; $i -lt 10; $i++) { if (docker exec $dbContainer pg_isready -U postgres 2>$null) { break }; Start-Sleep -Seconds 3 }
    $sqlGz = Join-Path $backupDataDir "database\full_backup.sql.gz"
    if (Test-Path $sqlGz) {
        Write-Host "Import database..." -ForegroundColor Cyan
        $sqlOut = Join-Path $env:TEMP "restore.sql"
        $input = [System.IO.File]::OpenRead($sqlGz)
        $gzip = New-Object System.IO.Compression.GzipStream($input, [System.IO.Compression.CompressionMode]::Decompress)
        $output = [System.IO.File]::Create($sqlOut)
        $gzip.CopyTo($output); $gzip.Close(); $input.Close(); $output.Close()
        Get-Content $sqlOut | docker exec -i $dbContainer psql -U postgres
        Remove-Item $sqlOut
    }
    $storageTar = Join-Path $backupDataDir "storage\storage.tar.gz"
    if (Test-Path $storageTar) {
        $storageVol = docker volume ls --format ".Name" | Select-String "_storage"
        if ($storageVol) { docker run --rm -v ${storageVol}:/mnt/storage -v "${backupDataDir}\storage:/backup:ro" alpine sh -c "cd /mnt/storage && tar xzf /backup/storage.tar.gz" }
    }
}

$ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.InterfaceAlias -notmatch "Loopback"} | Select-Object -First 1).IPAddress
Write-Host "======================================" -ForegroundColor Green
Write-Host "  HOÀN TẤT KHÔI PHỤC!" -ForegroundColor Green
Write-Host "  Truy cập: http://${ip}:8000" -ForegroundColor Yellow
Write-Host "======================================" -ForegroundColor Green
pause
'@ | Set-Content -Path $restoreScript
Copy-Item $restoreScript -Destination $windowsDir  # Đặt thêm vào windows/
Write-Success "Đã tạo restore-windows.ps1."

# ---------- SAO LƯU CẤU HÌNH ----------
Write-Step 7 8 "SAO LƯU CẤU HÌNH & DATABASE"
Copy-Item -Path "$projectDir\.env" -Destination $backupDataDir
Copy-Item -Path "$projectDir\docker-compose.yml" -Destination $backupDataDir
Write-Success "Đã sao lưu .env và docker-compose.yml"

# Backup volumes
$volumesDir = Join-Path $projectDir "volumes"
if (Test-Path $volumesDir) {
    $volBackupDir = Join-Path $backupDataDir "volumes"
    New-Item -ItemType Directory -Path $volBackupDir -Force | Out-Null
    Get-ChildItem -Path $volumesDir -Directory | Where-Object { $_.Name -ne 'db' -and $_.Name -ne 'logs' } | ForEach-Object {
        Copy-Item -Path $_.FullName -Destination $volBackupDir -Recurse
    }
    $dbInit = Join-Path $volumesDir "db\init"
    if (Test-Path $dbInit) {
        New-Item -ItemType Directory -Path (Join-Path $volBackupDir "db") -Force | Out-Null
        Copy-Item -Path $dbInit -Destination (Join-Path $volBackupDir "db") -Recurse
    }
    Write-Success "Đã sao lưu volumes."
}

# Backup database
$sqlFile = Join-Path $backupDataDir "database\full_backup.sql.gz"
# Tạo thư mục cha nếu chưa tồn tại
New-Item -ItemType Directory -Path (Split-Path $sqlFile -Parent) -Force | Out-Null

Write-Info "Đang dump database... (có thể mất vài phút)"
$dumpResult = docker exec $dbContainer pg_dumpall -U postgres
if ($LASTEXITCODE -eq 0) {
    # Compress the SQL dump using .NET compression
    $sqlDumpPath = Join-Path $env:TEMP "temp_dump.sql"
    $dumpResult | Out-File -FilePath $sqlDumpPath -Encoding UTF8
    $compression = New-Object System.IO.Compression.GzipStream("$sqlFile", [System.IO.Compression.CompressionMode]::Compress)
    $fileContent = [System.IO.File]::ReadAllText($sqlDumpPath)
    $fileBytes = [System.Text.Encoding]::UTF8.GetBytes($fileContent)
    $compression.Write($fileBytes, 0, $fileBytes.Length)
    $compression.Close()
    Remove-Item $sqlDumpPath
    Write-Success "Database đã được backup."
} else {
    Write-ErrorMsg "Backup database thất bại."
    exit 1
}

# Backup storage (bind mount hoặc volume)
$storageVol = Find-StorageVolume
if ($storageVol) {
    $storageDir = Join-Path $backupDataDir "storage"
    New-Item -ItemType Directory -Path $storageDir -Force | Out-Null
    docker run --rm -v ${storageVol}:/mnt/storage:ro -v "${storageDir}:/backup" alpine sh -c "cd /mnt/storage && tar czf /backup/storage.tar.gz ."
    Write-Success "Storage đã được backup."
} else {
    $storageSrc = Join-Path $projectDir "volumes\storage"
    if (Test-Path $storageSrc) {
        $storageDir = Join-Path $backupDataDir "storage"
        New-Item -ItemType Directory -Path $storageDir -Force | Out-Null
        # Compress using PowerShell
        Compress-Archive -Path $storageSrc -DestinationPath "$storageDir\storage.tar.gz" -Force
        Write-Success "Storage (bind mount) đã được backup."
    } else { 
        Write-WarningMsg "Không tìm thấy storage." 
    }
}

# ---------- ĐÓNG GÓI FILE .TAR.GZ ----------
Write-Step 8 8 "ĐÓNG GÓI FILE BACKUP"
$backupFile = Join-Path "$env:USERPROFILE\Desktop" "supabase-backup-$timestamp.tar.gz"
# Sử dụng 7-Zip nếu có, nếu không sẽ dùng ZIP và cảnh báo
if (Get-Command "7z" -ErrorAction SilentlyContinue) {
    Set-Location $backupRoot
    7z a -ttar "temp.tar" (Split-Path -Leaf $packDir) | Out-Null
    7z a -tgzip $backupFile "temp.tar" | Out-Null
    Remove-Item "temp.tar"
    Set-Location $PSScriptRoot
    Write-Success "Backup thành công: $backupFile"
} else {
    # Fallback: nén zip
    $zipFile = Join-Path "$env:USERPROFILE\Desktop" "supabase-backup-$timestamp.zip"
    Compress-Archive -Path $packDir -DestinationPath $zipFile
    Write-WarningMsg "7-Zip chưa cài đặt, backup được lưu dưới dạng .zip (thay vì .tar.gz)."
    Write-Success "Backup thành công: $zipFile"
    $backupFile = $zipFile
}

# Tạo checksum
$hash = Get-FileHash -Path $backupFile -Algorithm SHA256
"$($hash.Hash)  $(Split-Path $backupFile -Leaf)" | Out-File -FilePath "$backupFile.sha256" -Encoding ASCII
Write-Success "Checksum đã được tạo: $backupFile.sha256"

# ---------- ĐỒNG BỘ SSH ----------
if ($syncSsh) {
    Write-Info "Gửi file backup sang $remote..."
    # Assuming scp is available (either from WSL, Git Bash, or OpenSSH)
    $process = Start-Process -FilePath "scp" -ArgumentList @($backupFile, "${remote}:supabase_self_host_backup/") -Wait -PassThru
    if ($process.ExitCode -eq 0) { Write-Success "Đồng bộ thành công." }
    else { Write-ErrorMsg "Đồng bộ thất bại." }
}

# ---------- UPLOAD GOOGLE DRIVE ----------
if ($uploadGDrive) { Invoke-GDriveUpload $backupFile }

# ---------- THIẾT LẬP TASK SCHEDULER (TỰ ĐỘNG BACKUP) ----------
$cronChoice = Read-Host "Bạn có muốn tự động backup hàng ngày lúc 2h sáng? (y/n)"
if ($cronChoice -eq 'y') {
    $taskName = "SupabaseBackupDaily"
    $scriptPath = Join-Path $PSScriptRoot "Invoke-Freeze.ps1"
    $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -WindowStyle Hidden -File `"$scriptPath`""
    $trigger = New-ScheduledTaskTrigger -Daily -At "02:00"
    Register-ScheduledTask -Action $action -Trigger $trigger -TaskName $taskName -Description "Supabase backup hàng ngày" -User $env:USERNAME
    Write-Success "Task scheduler đã được thêm."
}

# Dọn dẹp
Remove-TempDir $backupRoot
Write-Title "HOÀN TẤT BACKUP"