# windows/Invoke-DownloadBackup.ps1
Import-Module .\SupabaseKit.psm1 -Force

Write-Title "TẢI FILE BACKUP TỪ VPS VỀ MÁY LOCAL"

# Nhập thông tin VPS
$remote = Read-Host "Nhập địa chỉ VPS (user@ip)"
if ([string]::IsNullOrWhiteSpace($remote)) {
    Write-ErrorMsg "Bạn phải nhập địa chỉ VPS."
    exit
}

# Đường dẫn thư mục backup trên VPS
$remoteDir = Read-Host "Đường dẫn thư mục chứa backup trên VPS (ví dụ: /opt/supabase/backup)"
if ([string]::IsNullOrWhiteSpace($remoteDir)) { 
    $remoteDir = "/opt/supabase/backup"
    Write-Info "Sử dụng đường dẫn mặc định: $remoteDir"
}

# Thư mục lưu trên Windows
$localDir = Read-Host "Thư mục lưu trên máy (mặc định: $env:USERPROFILE\Downloads)"
if ([string]::IsNullOrWhiteSpace($localDir)) { 
    $localDir = "$env:USERPROFILE\Downloads" 
}

# Kiểm tra kết nối SSH
Write-Info "Kiểm tra kết nối SSH tới $remote..."
$test = ssh -o ConnectTimeout=10 -o BatchMode=yes $remote 'echo OK' 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-ErrorMsg "Không thể kết nối SSH đến $remote. Hãy đảm bảo bạn đã cấu hình SSH key hoặc biết mật khẩu."
    exit
}
Write-Success "Kết nối SSH thành công."

# Tìm file backup mới nhất trên VPS
Write-Info "Đang tìm file backup mới nhất..."
$latestBackup = ssh $remote "ls -t $remoteDir/supabase-backup-*.tar.gz 2>/dev/null | head -1"
if ([string]::IsNullOrWhiteSpace($latestBackup)) {
    Write-ErrorMsg "Không tìm thấy file backup nào trong $remoteDir."
    exit
}

$backupName = Split-Path $latestBackup -Leaf
Write-Info "File backup mới nhất: $backupName"

# Tải về
Write-Info "Đang tải $backupName về $localDir..."
& scp "$remote`:${latestBackup}" $localDir\
if ($LASTEXITCODE -eq 0) {
    Write-Success "Đã tải thành công: $localDir\$backupName"
    
    # Kiểm tra checksum nếu có
    $checksumPath = Join-Path $localDir "$backupName.sha256"
    if (Test-Path $checksumPath) {
        Write-Info "Tìm thấy file checksum, đang kiểm tra tính toàn vẹn..."
        $downloadedFilePath = Join-Path $localDir $backupName
        $downloadedHash = Get-FileHash -Path $downloadedFilePath -Algorithm SHA256
        $storedHash = Get-Content $checksumPath
        
        if ($downloadedHash.Hash -eq $storedHash.Trim()) {
            Write-Success "Checksum hợp lệ. File không bị hỏng."
        } else {
            Write-WarningMsg "Checksum không khớp. File có thể bị hỏng trong quá trình truyền."
        }
    } else {
        Write-WarningMsg "Không tìm thấy file checksum (.sha256). Không thể xác minh tính toàn vẹn."
    }
} else {
    Write-ErrorMsg "Tải thất bại."
}