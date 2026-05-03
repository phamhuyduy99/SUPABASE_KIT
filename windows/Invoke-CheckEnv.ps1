# ==============================================
# INVOKE-CHECKENV.PS1 – Kiểm tra môi trường Windows cho Supabase
# ==============================================

# Import module
Import-Module "$PSScriptRoot\SupabaseKit.psm1" -Force

Write-Host "🔍 KIỂM TRA TƯƠNG THÍCH MÔI TRƯỜNG CHO SUPABASE..." @COLOR_TITLE

# ---------- 1. Kiểm tra hệ điều hành ----------
Write-Info "1. Phát hiện hệ điều hành..."
$osVersion = [System.Environment]::OSVersion.Version
$osCaption = (Get-WmiObject -Class Win32_OperatingSystem).Caption

Write-Host "   Hệ điều hành: $osCaption" -ForegroundColor White
Write-Host "   Phiên bản: $($osVersion.Major).$($osVersion.Minor).$($osVersion.Build)" -ForegroundColor White

# Windows 10/11 có major version >= 10
if ($osVersion.Major -ge 10) {
    Write-Success "✅ Hệ điều hành được hỗ trợ (Windows 10/11)."
    $compat = $true
} else {
    Write-ErrorCustom "❌ Hệ điều hành không được hỗ trợ (cần Windows 10 trở lên)."
    $compat = $false
}

# ---------- 2. Kiểm tra tài nguyên hệ thống ----------
Write-Info "2. Kiểm tra tài nguyên hệ thống..."

# CPU
$cpu = Get-WmiObject Win32_Processor
Write-Host "   CPU: $($cpu.Name.Trim())" -ForegroundColor White

# Kiểm tra kiến trúc CPU (x64)
$cpuArch = $env:PROCESSOR_ARCHITECTURE
if ($cpuArch -eq "AMD64") {
    Write-Success "✅ Kiến trúc CPU x64 được hỗ trợ."
} else {
    Write-WarningCustom "⚠️ Kiến trúc CPU không phải x64: $cpuArch"
    $compat = $false
}

# RAM
$ram = Get-WmiObject Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum
$ramMB = [math]::Round($ram.Sum / 1MB)
Write-Host "   RAM: $ramMB MB" -ForegroundColor White

if ($ramMB -ge 2048) {
    Write-Success "✅ RAM đủ (>= 2GB): ${ramMB}MB"
} else {
    Write-WarningCustom "⚠️ RAM thấp (< 2GB): ${ramMB}MB - Supabase có thể hoạt động chậm"
}

# ---------- 3. Kiểm tra Docker ----------
Write-Info "3. Kiểm tra Docker..."

if (Get-Command "docker" -ErrorAction SilentlyContinue) {
    $dockerVersion = docker --version 2>$null
    Write-Host "   Docker: $dockerVersion" -ForegroundColor White
    
    # Kiểm tra xem Docker daemon có chạy không
    try {
        $dockerInfo = docker info 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "✅ Docker hoạt động tốt."
        } else {
            Write-ErrorCustom "❌ Docker không chạy được. Hãy khởi động Docker Desktop."
            $compat = $false
        }
    } catch {
        Write-ErrorCustom "❌ Docker không chạy được. Hãy khởi động Docker Desktop."
        $compat = $false
    }
} else {
    Write-ErrorCustom "❌ Docker chưa cài đặt. Vui lòng cài Docker Desktop."
    $compat = $false
}

# ---------- 4. Kiểm tra Hyper-V/Virtualization ----------
Write-Info "4. Kiểm tra ảo hóa..."

$hyperVFeature = Get-WindowsOptionalFeature -Online | Where-Object { $_.FeatureName -eq "Microsoft-Hyper-V-All" }
if ($hyperVFeature) {
    if ($hyperVFeature.State -eq "Enabled") {
        Write-Success "✅ Hyper-V được kích hoạt."
    } else {
        Write-WarningCustom "⚠️ Hyper-V không được kích hoạt. Docker có thể hoạt động chậm hơn."
    }
} else {
    Write-WarningCustom "⚠️ Không tìm thấy Hyper-V. Docker Desktop sử dụng WSL 2 backend."
}

# ---------- 5. Kiểm tra WSL2 (nếu cần) ----------
Write-Info "5. Kiểm tra WSL2 (yêu cầu cho Docker trên Windows)..."

try {
    $wslVersion = wsl --version 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Success "✅ WSL được cài đặt: $wslVersion"
        
        # Kiểm tra phiên bản WSL mặc định
        $wslDefaultVersion = wsl --set-default-version 2 2>$null
        if ($?) {
            Write-Success "✅ WSL2 là phiên bản mặc định."
        } else {
            Write-WarningCustom "⚠️ Không thể thiết lập WSL2 là mặc định."
        }
    } else {
        Write-WarningCustom "⚠️ WSL không được cài đặt (WSL2 được Docker khuyến nghị)."
    }
} catch {
    Write-WarningCustom "⚠️ WSL không được cài đặt (WSL2 được Docker khuyến nghị)."
}

# ---------- 6. Kiểm tra dung lượng đĩa ----------
Write-Info "6. Kiểm tra dung lượng đĩa trống..."

$drive = (Get-Location).Drive
$freeSpaceMB = [math]::Round($drive.Free / 1MB)

Write-Host "   Ổ đĩa hiện tại: $($drive.Name) ($([math]::Round($drive.TotalSize / 1GB)) GB tổng) - $freeSpaceMB MB trống" -ForegroundColor White

if ($freeSpaceMB -gt 5000) {  # > 5GB
    Write-Success "✅ Dung lượng đĩa đủ cho Supabase."
} else {
    Write-WarningCustom "⚠️ Dung lượng đĩa thấp: $freeSpaceMB MB trống. Supabase cần ít nhất ~5GB."
    if ($freeSpaceMB -lt 2000) {
        $compat = $false
    }
}

# ---------- 7. Kiểm tra kết nối Internet ----------
Write-Info "7. Kiểm tra kết nối Internet..."

if (Test-NetworkConnectivity) {
    Write-Success "✅ Kết nối Internet ổn định."
} else {
    Write-ErrorCustom "❌ Không có kết nối Internet."
    $compat = $false
}

# ---------- Kết luận ----------
Write-Host ""
if ($compat) {
    Write-Success "Môi trường của bạn TƯƠNG THÍCH để chạy Supabase trên Windows."
    Write-Host "   Bạn có thể tiếp tục sử dụng chức năng Khôi phục/Đóng băng." -ForegroundColor Green
} else {
    Write-ErrorCustom "Môi trường của bạn CÓ THỂ KHÔNG TƯƠNG THÍCH hoàn toàn."
    Write-Host "   - Vui lòng kiểm tra các cảnh báo ở trên và khắc phục." -ForegroundColor Yellow
    Write-Host "   - Đảm bảo Docker Desktop đã được cài đặt và đang chạy." -ForegroundColor Yellow
    Write-Host "   - Kiểm tra lại tài nguyên hệ thống (RAM, dung lượng đĩa)." -ForegroundColor Yellow
}

# Invoke-CheckEnv.ps1 – Kiểm tra môi trường Windows cho Supabase
Import-Module .\SupabaseKit.psm1 -Force

Write-Title "KIỂM TRA MÔI TRƯỜNG VPS"

# 1. Ảo hóa
Write-Info "1. Phát hiện công nghệ ảo hóa..."
$hypervisorPresent = (Get-CimInstance -ClassName Win32_ComputerSystem).HypervisorPresent
$manufacturer = (Get-CimInstance -ClassName Win32_ComputerSystem).Manufacturer
$virtualMachine = $manufacturer -match "VMware|VirtualBox|Parallels|QEMU|Bochs|Xen"

if ($hypervisorPresent) {
    Write-Success "Máy ảo/hypervisor hoạt động (thường là Hyper-V hoặc phần mềm ảo hóa khác)."
} elseif ($virtualMachine) {
    Write-Success "Máy ảo được phát hiện thông qua nhà sản xuất."
} else {
    Write-WarningMsg "Máy vật lý hoặc không xác định ảo hóa."
}

# 2. CPU & RAM
Write-Info "2. Kiểm tra CPU & RAM..."
$cpu = (Get-CimInstance -ClassName Win32_Processor).Name
$ram = [math]::Round((Get-CimInstance -ClassName Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
if ($ram -ge 4) {
    Write-Success "CPU: $cpu, RAM: $ram GB"
} else {
    Write-ErrorMsg "RAM chỉ có $ram GB, cần tối thiểu 4GB."
}

# 3. Docker
Write-Info "3. Kiểm tra Docker..."
if (Test-DockerAvailable) {
    Write-Success "Docker sẵn sàng."
} else {
    Write-ErrorMsg "Docker không hoạt động."
}

# 4. Dung lượng đĩa
Write-Info "4. Dung lượng đĩa..."
$drive = (Get-Location).Drive
$free = [math]::Round($drive.Free / 1GB)
if ($free -ge 20) {
    Write-Success "Dung lượng trống: $free GB"
} else {
    Write-WarningMsg "Dung lượng trống thấp: $free GB (khuyên dùng 20GB trở lên)."
}

# 5. Kiểm tra hệ điều hành
Write-Info "5. Kiểm tra hệ điều hành..."
$os = Get-CimInstance Win32_OperatingSystem
$osName = $os.Caption
$osVersion = $os.Version
Write-Info "Hệ điều hành: $osName (phiên bản $osVersion)"

if ([System.Environment]::OSVersion.Version.Major -ge 10) {
    Write-Success "Hệ điều hành được hỗ trợ (Windows 10/11)."
} else {
    Write-WarningMsg "Hệ điều hành có thể không được hỗ trợ đầy đủ (cần Windows 10 trở lên)."
}

# 6. Kiểm tra Hyper-V feature
Write-Info "6. Kiểm tra Hyper-V..."
$hyperVFeature = Get-WindowsOptionalFeature -Online | Where-Object { $_.FeatureName -eq "Microsoft-Hyper-V-All" }
if ($hyperVFeature) {
    if ($hyperVFeature.State -eq "Enabled") {
        Write-Success "Hyper-V được kích hoạt."
    } else {
        Write-WarningMsg "Hyper-V không được kích hoạt."
    }
} else {
    Write-Info "Hyper-V không được cài đặt (không bắt buộc nếu dùng Docker Desktop)."
}

Write-Title "KIỂM TRA HOÀN TẤT"
