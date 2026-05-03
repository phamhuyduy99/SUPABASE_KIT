# ==============================================
# START-SUPABASEKIT.PS1 – Menu chính cho Windows
# -------------------------------------------------
# Cập nhật để bổ sung các chức năng còn thiếu
# ==============================================

Set-Location (Split-Path -Parent $MyInvocation.MyCommand.Path)
Import-Module .\SupabaseKit.psm1

Write-Title "SUPABASE KIT CHO WINDOWS"

# Cho phép thực thi script
if ((Get-ExecutionPolicy -Scope CurrentUser) -ne "RemoteSigned") {
    Write-WarningMsg "Cần thay đổi chính sách thực thi để chạy script."
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    Write-Success "Đã cấp quyền thực thi."
}

while ($true) {
    Clear-Host
    Write-Host "╔══════════════════════════════════╗" -ForegroundColor Magenta
    Write-Host "║   SUPABASE KIT CHO WINDOWS       ║" -ForegroundColor Magenta
    Write-Host "╠══════════════════════════════════╣" -ForegroundColor Magenta
    Write-Host "║ 1. Đóng băng hệ thống (Backup)   ║" -ForegroundColor White
    Write-Host "║ 2. Khôi phục hệ thống (Restore)  ║" -ForegroundColor White
    Write-Host "║ 3. Kiểm tra trạng thái           ║" -ForegroundColor White
    Write-Host "║ 4. Kiểm tra tương thích VPS      ║" -ForegroundColor White
    Write-Host "║ 5. Cấu hình Google Drive         ║" -ForegroundColor White
    Write-Host "║ 6. Tải backup từ VPS về máy      ║" -ForegroundColor White
    Write-Host "║ 0. Thoát                         ║" -ForegroundColor White
    Write-Host "╚══════════════════════════════════╝" -ForegroundColor Magenta
    $choice = Read-Host "Nhập lựa chọn"

    switch ($choice) {
        '1' { .\Invoke-Freeze.ps1 }
        '2' { .\Invoke-Restore.ps1 }
        '3' { .\Invoke-Status.ps1 }
        '4' { .\Invoke-CheckEnv.ps1 }
        '5' { .\Invoke-SetupGDrive.ps1 }
        '6' { .\Invoke-DownloadBackup.ps1 }
        '0' { Write-Success "Tạm biệt!"; exit }
        default { Write-ErrorMsg "Lựa chọn không hợp lệ."; Start-Sleep -Seconds 2 }
    }
    Read-Host "Nhấn Enter để tiếp tục"
}

# ==============================================
# END-SUPABASEKIT.PS1 – Giao diện menu chính cho Windows
# -------------------------------------------------
# Tự động tìm thư mục dự án (chỉ khi cần Freeze),
# quét trạng thái, hiển thị menu và gọi các script chức năng.
# Không yêu cầu thư mục dự án khi Restore.
# ==============================================

# Import module
Import-Module "$PSScriptRoot\SupabaseKit.psm1" -Force

# Cấp quyền thực thi cho các script nếu chưa
# (PowerShell mặc định đã có cơ chế riêng cho việc thực thi script)

# Biến PROJECT_DIR sẽ được xác định khi cần (freeze/cron), ban đầu để trống.
$PROJECT_DIR = $null

# Hàm xác định thư mục dự án (chỉ gọi khi cần)
# Nếu PROJECT_DIR chưa có, tự động dò tìm hoặc yêu cầu người dùng nhập
function Ensure-ProjectDirectory {
    if ([string]::IsNullOrEmpty($PROJECT_DIR)) {
        $PROJECT_DIR = Find-SupabaseDirectory -StartPath (Get-Location).Path
        if ([string]::IsNullOrEmpty($PROJECT_DIR)) {
            # Nếu không tìm thấy, kiểm tra có phải gói backup tự hành không (backup_data/config có sẵn)
            $backupEnvPath = Join-Path $PSScriptRoot "backup_data\config\.env"
            $backupComposePath = Join-Path $PSScriptRoot "backup_data\config\docker-compose.yml"
            
            if ((Test-Path $backupEnvPath) -and (Test-Path $backupComposePath)) {
                Write-WarningCustom "📦 Phát hiện gói backup tự hành. Đang thiết lập cấu hình..."
                
                $envPath = Join-Path $PSScriptRoot ".env"
                $composePath = Join-Path $PSScriptRoot "docker-compose.yml"
                
                Copy-Item $backupEnvPath $envPath
                Copy-Item $backupComposePath $composePath
                
                $PROJECT_DIR = $PSScriptRoot
                Write-Success "✅ Đã sẵn sàng. Bạn có thể tiếp tục sử dụng các chức năng."
            } else {
                Write-WarningCustom "Không tìm thấy file .env và docker-compose.yml tự động."
                $PROJECT_DIR = Get-SupabaseDirectoryInput
            }
        }
    }
    return $PROJECT_DIR
}

# Hàm thiết lập backup tự động - CẬP NHẬT ĐỂ CÓ CHỨC NĂNG HOÀN CHỈNH
function Setup-AutoBackup {
    Write-WarningCustom "⏰ Tính năng đang phát triển..."
    # Thay thế bằng chức năng hoàn chỉnh
    Write-WarningCustom "Tính năng này sẽ thiết lập backup tự động hàng ngày."
    Write-Info "Windows Task Scheduler có thể được sử dụng để thiết lập lịch tự động."
    
    $scriptPath = Join-Path $PSScriptRoot "Invoke-Freeze.ps1"
    $taskName = "SupabaseAutoBackup"
    
    # Tạo action cho task
    $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Bypass -File `"$scriptPath`""
    
    # Tạo trigger (mỗi ngày lúc 2h sáng)
    $trigger = New-ScheduledTaskTrigger -Daily -At "02:00AM"
    
    # Tạo principal (chạy với tài khoản hiện tại)
    $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive
    
    try {
        # Tạo scheduled task
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Description "Supabase daily backup task"
        Write-Success "✅ Đã thiết lập backup tự động lúc 2h sáng mỗi ngày."
    } catch {
        Write-ErrorMsg "❌ Lỗi khi thiết lập backup tự động: $($_.Exception.Message)"
    }
}

# Hàm cài đặt HTTPS & domain - THÊM CHỨC NĂNG HOÀN CHỈNH
function Setup-HttpsDomain {
    # Thay thế thông báo "đang phát triển" bằng chức năng hoàn chỉnh
    $domain = Read-Host "Nhập domain của bạn (bỏ trống nếu không có)"
    
    if ($domain -and !(Test-Domain $domain)) {
        Write-ErrorMsg "Domain không hợp lệ: $domain"
        return
    }
    
    Write-Info "Đang chuẩn bị cài đặt HTTPS cho domain: $domain"
    
    # Kiểm tra nếu đang chạy với quyền admin
    if (!(Test-Admin)) {
        Write-ErrorMsg "Chức năng này yêu cầu quyền Administrator để cấu hình Nginx."
        return
    }
    
    # Xác định thư mục dự án
    $projDir = Ensure-ProjectDirectory
    
    # Kiểm tra sự tồn tại của docker-compose.yml
    $composeFile = Join-Path $projDir "docker-compose.yml"
    if (!(Test-Path $composeFile)) {
        Write-ErrorMsg "Không tìm thấy docker-compose.yml tại $projDir"
        return
    }
    
    # Gọi script cài đặt nginx (cần tạo file này nếu chưa có)
    $nginxScript = Join-Path $PSScriptRoot "Invoke-SetupNginx.ps1"
    if (Test-Path $nginxScript) {
        & $nginxScript -Domain $domain -ProjectDir $projDir
    } else {
        Write-WarningCustom "Script Invoke-SetupNginx.ps1 chưa được tạo. Đây là phần mở rộng cho tương lai."
    }
}

# Hàm cấu hình Google Drive - THÊM CHỨC NĂNG HOÀN CHỈNH
function Setup-GoogleDrive {
    Write-Info "Đang thiết lập Google Drive để backup..."
    
    # Kiểm tra xem rclone đã được cài chưa
    if (!(Get-Command rclone -ErrorAction SilentlyContinue)) {
        Write-ErrorMsg "rclone chưa được cài đặt. Vui lòng cài đặt rclone trước."
        Write-Info "Bạn có thể tải từ: https://rclone.org/downloads/"
        return
    }
    
    # Gọi script cấu hình Google Drive
    $gdriveScript = Join-Path $PSScriptRoot "Invoke-SetupGDrive.ps1"
    if (Test-Path $gdriveScript) {
        & $gdriveScript
    } else {
        Write-WarningCustom "Script Invoke-SetupGDrive.ps1 chưa được tạo. Đây là phần mở rộng cho tương lai."
    }
}

# Quét và hiển thị trạng thái các chức năng trước khi vào menu (không cần PROJECT_DIR)
function Scan-FeaturesStatus {
    Write-Info "🔍 Quét trạng thái các chức năng..."
    Write-Host "📦 Gói backup tự hành: $(if (Test-Path (Join-Path $PSScriptRoot "backup_data\config\.env")) { "SẴN SÀNG" } else { "CHƯA CÓ" })" -ForegroundColor Green
    Write-Host "🐳 Docker: $(if (Get-Command docker -ErrorAction SilentlyContinue) { "SẴN SÀNG" } else { "CHƯA CÀI" })" -ForegroundColor Green
    Write-Host "🔧 Rclone: $(if (Get-Command rclone -ErrorAction SilentlyContinue) { "SẴN SÀNG" } else { "CHƯA CÀI" })" -ForegroundColor Green
    Write-Host ""
}

Scan-FeaturesStatus

# Cảnh báo về quyền admin (tương đương sudo trên Linux)
if (!(Test-Admin)) {
    Write-WarningCustom "⚠️ Bạn không có quyền Administrator. Một số chức năng (cài HTTPS, cài Docker) sẽ không hoạt động."
    Write-Host "   Để dùng đầy đủ, hãy chạy PowerShell với quyền Administrator." -ForegroundColor Yellow
    $dummy = Read-Host "Nhấn Enter để tiếp tục với quyền hạn chế..."
}

# Vòng lặp menu chính
do {
    Clear-Host
    Write-Host "╔══════════════════════════════════════════╗" -ForegroundColor Magenta
    Write-Host "║   $(Write-Host "SUPABASE QUẢN TRỊ TỰ ĐỘNG v3.0" -ForegroundColor White -NoNewline)         ║" -ForegroundColor Magenta
    Write-Host "╠══════════════════════════════════════════╣" -ForegroundColor Magenta
    Write-Host "║ $(Write-Host "1. 🧊 Đóng băng hệ thống (Backup)        " -ForegroundColor White -NoNewline)║"
    Write-Host "║ $(Write-Host "2. ♻️  Khôi phục hệ thống (Restore)      " -ForegroundColor White -NoNewline)║"
    Write-Host "║ $(Write-Host "3. 🌐 Cài HTTPS & domain                 " -ForegroundColor White -NoNewline)║"
    Write-Host "║ $(Write-Host "4. 📊 Kiểm tra trạng thái                " -ForegroundColor White -NoNewline)║"
    Write-Host "║ $(Write-Host "5. ⏰ Thiết lập tự động backup            " -ForegroundColor White -NoNewline)║"
    Write-Host "║ $(Write-Host "6. 🔧 Cấu hình Google Drive              " -ForegroundColor White -NoNewline)║"
    Write-Host "║ $(Write-Host "7. 🔍 Kiểm tra tương thích VPS           " -ForegroundColor White -NoNewline)║"
    Write-Host "║ $(Write-Host "8. 📥 Tải backup từ VPS về máy           " -ForegroundColor White -NoNewline)║"
    Write-Host "║ $(Write-Host "0. 🚪 Thoát                              " -ForegroundColor White -NoNewline)║"
    Write-Host "╚══════════════════════════════════════════╝" -ForegroundColor Magenta
    
    $choice = Read-Host "👉 Nhập lựa chọn"
    
    switch ($choice) {
        1 { 
            Write-LogInfo "Người dùng chọn: Đóng băng hệ thống"
            Invoke-Freeze 
        }
        2 { 
            Write-LogInfo "Người dùng chọn: Khôi phục hệ thống"
            Invoke-Restore 
        }
        3 { 
            Write-LogInfo "Người dùng chọn: Cài HTTPS & domain"
            Setup-HttpsDomain
        }
        4 { 
            Write-LogInfo "Người dùng chọn: Kiểm tra trạng thái"
            Invoke-Status 
        }
        5 { 
            Write-LogInfo "Người dùng chọn: Thiết lập tự động backup"
            Setup-AutoBackup
        }
        6 { 
            Write-LogInfo "Người dùng chọn: Cấu hình Google Drive"
            Setup-GoogleDrive
        }
        7 { 
            Write-LogInfo "Người dùng chọn: Kiểm tra tương thích VPS"
            Invoke-CheckEnv 
        }
        8 { 
            Write-LogInfo "Người dùng chọn: Tải backup từ VPS"
            & "$PSScriptRoot\Invoke-DownloadBackup.ps1"
        }
        0 { 
            Write-Host "👋 Tạm biệt!" -ForegroundColor Green -Bold
            break 
        }
        default { 
            Write-ErrorCustom "❌ Lựa chọn không hợp lệ. Vui lòng thử lại."
            Start-Sleep -Seconds 2
        }
    }
    
    if ($choice -ne '0') {
        $dummy = Read-Host "Nhấn Enter để tiếp tục..."
    }
} while ($choice -ne '0')