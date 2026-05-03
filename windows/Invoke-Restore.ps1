# ==============================================
# INVOKE-RESTORE.PS1 – Khôi phục Supabase trên Windows
# -------------------------------------------------
# Hỗ trợ VPS trắng, phát hiện dữ liệu backup kèm sẵn.
# Cập nhật để bổ sung các tính năng còn thiếu
# ==============================================

# Import module
Import-Module .\SupabaseKit.psm1 -Force

Write-Title "KHÔI PHỤC HỆ THỐNG SUPABASE"

# Kiểm tra môi trường
Write-Info "Kiểm tra môi trường..."
if (!(Test-DockerAvailable)) { exit 1 }
if (!(Test-Network)) { exit 1 }

# Bước 1: Chọn file backup
Write-Step 1 7 "CHỌN NGUỒN BACKUP"
$backupFile = $null
while (-not $backupFile) {
    $src = Read-Host "Đường dẫn file backup (.tar.gz), URL hoặc gdrive:path"
    if ($src -match '^gdrive:') {
        if (!(Get-Command rclone -ErrorAction SilentlyContinue)) { 
            Write-ErrorMsg "rclone chưa cài."; 
            continue 
        }
        $local = Join-Path $env:TEMP "restore-backup-$([System.Diagnostics.Process]::GetCurrentProcess().Id).tar.gz"
        rclone copy $src $local --progress
        if ($LASTEXITCODE -eq 0) { 
            $backupFile = $local 
        } else { 
            Write-ErrorMsg "Tải thất bại." 
        }
    } elseif ($src -match '^https?://') {
        $local = Join-Path $env:TEMP "restore-backup-$([System.Diagnostics.Process]::GetCurrentProcess().Id).tar.gz"
        Invoke-WebRequest -Uri $src -OutFile $local
        $backupFile = $local
    } else {
        if (Test-Path $src) { 
            $backupFile = $src 
        } else { 
            Write-ErrorMsg "File không tồn tại." 
        }
    }
}

# Kiểm tra checksum nếu có
$checksumFile = "${backupFile}.sha256"
if (Test-Path $checksumFile) {
    Write-Info "Đang kiểm tra tính toàn vẹn file backup..."
    $backupHash = Get-FileHash -Path $backupFile -Algorithm SHA256
    $storedHash = Get-Content $checksumFile
    
    if ($backupHash.Hash -eq $storedHash.Trim()) {
        Write-Success "File backup hợp lệ."
    } else {
        Write-ErrorMsg "File backup bị hỏng hoặc không toàn vẹn!"
        exit 1
    }
} else {
    Write-WarningMsg "Không tìm thấy file checksum, bỏ qua kiểm tra tính toàn vẹn."
}

# Bước 2: Giải nén
Write-Step 2 7 "GIẢI NÉN BACKUP"
$tmpDir = Join-Path $env:TEMP "supabase-restore-$([System.Diagnostics.Process]::GetCurrentProcess().Id)"
Remove-Item -Recurse -Force $tmpDir -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $tmpDir | Out-Null

# Using 7-Zip if available, otherwise using a workaround
if (Get-Command "7z" -ErrorAction SilentlyContinue) {
    Set-Location $tmpDir
    7z x $backupFile | Out-Null
    Set-Location $PSScriptRoot
} else {
    # If 7-Zip is not available, we'll use PowerShell's built-in decompression
    # But first we need to rename .tar.gz to .zip as workaround
    $tempZip = $backupFile -replace '\.tar\.gz$', '.zip'
    if ($backupFile -ne $tempZip) {
        Copy-Item -Path $backupFile -Destination $tempZip
        Expand-Archive -Path $tempZip -DestinationPath $tmpDir
        Remove-Item $tempZip
    } else {
        Write-ErrorMsg "Không thể giải nén file backup. Vui lòng cài 7-Zip."
        exit 1
    }
}

if ($LASTEXITCODE -ne 0) { 
    Write-ErrorMsg "Giải nén thất bại."; 
    exit 1 
}

$firstDir = Get-ChildItem -Path $tmpDir -Directory | Select-Object -First 1
$backupDataDir = Join-Path $firstDir.FullName "backup_data"
if (!(Test-Path $backupDataDir)) { 
    Write-ErrorMsg "Backup không chứa backup_data."; 
    exit 1 
}

# Bước 3: Dọn dẹp container cũ
Write-Step 3 7 "DỌN DẸP CONTAINER CŨ"
Remove-OldContainers -ProjectDir $targetDir

# Bước 4: Chọn thư mục cài đặt
Write-Step 4 7 "CHỌN THƯ MỤC CÀI ĐẶT"
$targetDir = Read-Host "Thư mục cài đặt (mặc định C:\supabase-restored)"
if ([string]::IsNullOrWhiteSpace($targetDir)) { 
    $targetDir = "C:\supabase-restored" 
}
New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
Set-Location $targetDir

# Bước 5: Sao chép cấu hình
Write-Step 5 7 "SAO CHÉP CẤU HÌNH"
Copy-Item -Path "$backupDataDir\config\.env" -Destination $targetDir
Copy-Item -Path "$backupDataDir\config\docker-compose.yml" -Destination $targetDir
Write-Success "Đã sao chép .env và docker-compose.yml."

# Phục hồi volumes
$volDir = Join-Path $backupDataDir "volumes"
if (Test-Path $volDir) {
    Copy-Item -Path "$volDir\*" -Destination $targetDir -Recurse
    Write-Success "Đã phục hồi volumes."
}

# Bước 6: Khởi động Supabase và xử lý lỗi sysctl
Write-Step 6 7 "KHỞI ĐỘNG SUPABASE"
Write-Info "Đang khởi động các container..."

# Sửa lỗi sysctl nếu có
Repair-SysctlConfig -ComposeFilePath "$targetDir\docker-compose.yml"

$composeCmd = Get-DockerComposeCommand
$errLog = Join-Path $env:TEMP "docker_start_err_$([System.Diagnostics.Process]::GetCurrentProcess().Id).log"
& $composeCmd -f "$targetDir\docker-compose.yml" up -d 2>$errLog
$success = $LASTEXITCODE -eq 0
$err = Get-Content $errLog -Raw

if (-not $success -or $err -match "net.ipv4.ip_unprivileged_port_start") {
    Write-WarningMsg "Lỗi khởi động liên quan đến sysctl (có thể do LXC/OpenVZ). Đang thử các chiến lược..."
    # Lưu file gốc
    $originalCompose = Join-Path $targetDir "docker-compose.yml.original"
    Copy-Item "$targetDir\docker-compose.yml" $originalCompose

    # Hàm thử lại
    function Try-Start {
        & $composeCmd -f "$targetDir\docker-compose.yml" up -d 2>$errLog
        if ($LASTEXITCODE -eq 0) {
            $services = & $composeCmd -f "$targetDir\docker-compose.yml" config --services
            foreach ($svc in $services) {
                $status = & $composeCmd -f "$targetDir\docker-compose.yml" ps $svc 2>$null | Select-String "Up"
                if (-not $status) { return $false }
            }
            return $true
        }
        return $false
    }

    $strategies = @(
        { # 1: Xóa dòng sysctl
            $content = Get-Content "$targetDir\docker-compose.yml"
            $newContent = $content | Where-Object { $_ -notmatch '.*ip_unprivileged_port_start.*' }
            $newContent | Set-Content "$targetDir\docker-compose.yml"
            Try-Start
        },
        { # 2: Thêm privileged: true
            $content = Get-Content "$targetDir\docker-compose.yml"
            $newContent = @()
            foreach ($line in $content) {
                $newContent += $line
                if ($line -match '^\s+image:') { 
                    $newContent += '    privileged: true' 
                }
            }
            $newContent | Set-Content "$targetDir\docker-compose.yml"
            Try-Start
        }
        # Thêm các chiến lược khác nếu cần
    )

    $started = $false
    for ($i=0; $i -lt $strategies.Count; $i++) {
        Write-Info "Chiến lược $($i+1)/$($strategies.Count)..."
        if (& $strategies[$i]) {
            $started = $true
            break
        }
        # Khôi phục nếu file hỏng
        Copy-Item $originalCompose "$targetDir\docker-compose.yml" -Force
    }

    if (-not $started) {
        Write-ErrorMsg "Đã thử tất cả chiến lược nhưng không khởi động được. Nguyên nhân: môi trường ảo hóa không hỗ trợ."
        Write-Info "Hãy chuyển sang VPS KVM hoặc yêu cầu nhà cung cấp bật nesting."
        exit 1
    }
} else {
    Write-Success "Supabase đã khởi động."
}

# Bước 7: Import database và storage
Write-Step 7 7 "IMPORT DỮ LIỆU"
$dbContainer = Find-DatabaseContainer
if ($dbContainer) {
    # Đợi database sẵn sàng
    if (Wait-DatabaseReady -DbContainer $dbContainer -TimeoutSeconds 60) {
        # Import DB
        $sqlGz = Join-Path $backupDataDir "database\full_backup.sql.gz"
        if (Test-Path $sqlGz) {
            Write-Info "Import database..."
            $sqlOut = Join-Path $env:TEMP "restore.sql"
            
            # Decompress the gzipped SQL file
            $inputStream = New-Object System.IO.FileStream($sqlGz, [System.IO.FileMode]::Open)
            $gzipStream = New-Object System.IO.Compression.GzipStream($inputStream, [System.IO.Compression.CompressionMode]::Decompress)
            $outputStream = New-Object System.IO.MemoryStream
            $buffer = New-Object byte[] 4096
            do {
                $read = $gzipStream.Read($buffer, 0, 4096)
                if ($read -gt 0) {
                    $outputStream.Write($buffer, 0, $read)
                }
            } while ($read -gt 0)
            $gzipStream.Close()
            $inputStream.Close()
            
            $decompressedBytes = $outputStream.ToArray()
            $sqlContent = [System.Text.Encoding]::UTF8.GetString($decompressedBytes)
            [System.IO.File]::WriteAllText($sqlOut, $sqlContent, [System.Text.Encoding]::UTF8)
            $outputStream.Close()
            
            # Import to database
            Get-Content $sqlOut | docker exec -i $dbContainer psql -U postgres
            Write-Success "Database đã được phục hồi."
            Remove-Item $sqlOut
        }
        # Import storage
        $storageTar = Join-Path $backupDataDir "storage\storage.tar.gz"
        if (Test-Path $storageTar) {
            $storageVol = Find-StorageVolume
            if ($storageVol) {
                docker run --rm -v ${storageVol}:/mnt/storage -v "${backupDataDir}\storage:/backup:ro" alpine sh -c "cd /mnt/storage && tar xzf /backup/storage.tar.gz"
            } else {
                # Try using bind mount
                $targetStorageDir = Join-Path $targetDir "volumes\storage"
                if (Test-Path $targetStorageDir) {
                    # Extract to temp directory first
                    $tempExtractDir = Join-Path $env:TEMP "temp_storage_extract_$([System.Diagnostics.Process]::GetCurrentProcess().Id)"
                    New-Item -ItemType Directory -Path $tempExtractDir -Force | Out-Null
                    
                    # Using 7-Zip if available
                    if (Get-Command "7z" -ErrorAction SilentlyContinue) {
                        Set-Location $tempExtractDir
                        7z x $storageTar | Out-Null
                        Set-Location $PSScriptRoot
                    } else {
                        # Workaround: rename and use Expand-Archive
                        $tempZip = $storageTar -replace '\.tar\.gz$', '.zip'
                        Copy-Item -Path $storageTar -Destination $tempZip
                        Expand-Archive -Path $tempZip -DestinationPath $tempExtractDir
                        Remove-Item $tempZip
                    }
                    
                    # Copy extracted files to storage directory
                    Copy-Item -Path "$tempExtractDir\*" -Destination $targetStorageDir -Recurse
                    Remove-Item $tempExtractDir -Recurse -Force
                }
            }
            Write-Success "Storage đã được phục hồi."
        }
    } else {
        Write-ErrorMsg "Database không sẵn sàng sau 60 giây. Bỏ qua import."
    }
} else {
    Write-ErrorMsg "Không tìm thấy container database."
}

# Hoàn tất
$ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.InterfaceAlias -notmatch "Loopback"} | Select-Object -First 1).IPAddress
Write-Title "HOÀN TẤT KHÔI PHỤC"
Write-Info "Truy cập Supabase Studio: http://${ip}:8000"
$envContent = Get-Content "$targetDir\.env" -ErrorAction SilentlyContinue
$adminEmail = ($envContent | Select-String '^ADMIN_EMAIL=') -replace 'ADMIN_EMAIL=', ''
$adminPassword = ($envContent | Select-String '^ADMIN_PASSWORD=') -replace 'ADMIN_PASSWORD=', ''
Write-Info "Email: $adminEmail"
Write-Info "Mật khẩu: $adminPassword"

# Dọn dẹp
Remove-TempDir $tmpDir