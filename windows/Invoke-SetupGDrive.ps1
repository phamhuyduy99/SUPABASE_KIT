# Invoke-SetupGDrive.ps1 – Cấu hình Google Drive cho rclone
Import-Module .\SupabaseKit.psm1 -Force

Write-Title "CẤU HÌNH GOOGLE DRIVE"
if (!(Get-Command rclone -ErrorAction SilentlyContinue)) {
    Write-ErrorMsg "rclone chưa được cài đặt."
    $install = Read-Host "Cài đặt rclone? (y/n)"
    if ($install -eq 'y') {
        Write-Info "Đang tải và cài đặt rclone..."
        try {
            # Download rclone
            $downloadUrl = "https://downloads.rclone.org/rclone-current-windows-amd64.zip"
            $zipPath = Join-Path $env:TEMP "rclone.zip"
            Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath
            
            # Extract to temp folder
            $extractPath = Join-Path $env:TEMP "rclone-temp"
            Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
            
            # Find rclone folder and copy to Program Files
            $rcloneFolder = Get-ChildItem -Path $extractPath -Directory | Select-Object -First 1
            $installPath = "$env:ProgramFiles\rclone"
            New-Item -ItemType Directory -Path $installPath -Force | Out-Null
            Copy-Item -Path "$($rcloneFolder.FullName)\*" -Destination $installPath -Recurse
            
            # Add to PATH
            $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
            if ($currentPath -notlike "*rclone*") {
                [Environment]::SetEnvironmentVariable("Path", "$currentPath;$installPath", "User")
                $env:PATH += ";$installPath"
            }
            
            Remove-Item -Path $zipPath -Force
            Remove-Item -Path $extractPath -Recurse -Force
            
            Write-Success "rclone đã được cài đặt thành công!"
        } catch {
            Write-ErrorMsg "Lỗi khi cài đặt rclone: $($_.Exception.Message)"
            exit 1
        }
    } else {
        exit
    }
}

Write-Info "Hướng dẫn cấu hình Google Drive:"
Write-Info "1. Mở trình duyệt và truy cập: https://rclone.org/drive/#making-your-own-client-id"
Write-Info "2. Làm theo hướng dẫn để tạo Client ID và Secret"
Write-Info "3. Sau đó chạy lệnh sau trong terminal trên máy tính cá nhân:"
Write-Info "   rclone config create gdrive drive config_is_local=false"
Write-Info ""
Write-Info "Hoặc bạn có thể sử dụng phương pháp tự động:"
$method = Read-Host "Sử dụng phương pháp tự động (1) hay thủ công (2)? (1/2)"

if ($method -eq "1") {
    Write-Info "Chạy lệnh sau để tạo cấu hình Google Drive:"
    Write-Info "rclone config create gdrive drive"
    Start-Process "cmd" -ArgumentList "/k", "rclone config create gdrive drive"
    Write-Info "Sau khi hoàn tất, kiểm tra bằng lệnh: rclone listremotes"
} elseif ($method -eq "2") {
    Write-Info "Mở trình duyệt để truy cập Google Drive API Console..."
    Start-Process "https://console.cloud.google.com/apis/library/drive.googleapis.com"
    
    Write-Info "Sau khi tạo xong Client ID và Secret, vui lòng dán vào đây:")
    $clientId = Read-Host "Client ID"
    $clientSecret = Read-Host "Client Secret"
    
    if ($clientId -and $clientSecret) {
        $configPath = "$env:USERPROFILE\.config\rclone\rclone.conf"
        $configDir = Split-Path $configPath -Parent
        
        if (!(Test-Path $configDir)) {
            New-Item -ItemType Directory -Path $configDir -Force | Out-Null
        }
        
        @"
[gdrive]
type = drive
client_id = $clientId
client_secret = $clientSecret
scope = drive
token = 
"@ | Out-File -FilePath $configPath -Encoding UTF8
        
        Write-Info "Cấu hình đã được lưu. Bây giờ bạn cần cấp quyền:"
        Write-Info "Chạy lệnh: rclone config"
        Write-Info "Chọn remote 'gdrive' và làm theo hướng dẫn để cấp quyền."
        Start-Process "cmd" -ArgumentList "/k", "rclone config"
    } else {
        Write-ErrorMsg "Client ID và Secret không được để trống."
    }
} else {
    Write-ErrorMsg "Lựa chọn không hợp lệ."
}

Write-Info "Lưu ý: Bạn cần cấp quyền cho rclone để truy cập Google Drive của bạn."
Write-Info "Sau khi cấu hình xong, kiểm tra bằng lệnh: rclone ls gdrive: -MAX_DEPTH 1"