# ==============================================
# INVOKE-CHECKENV.PS1 – Kiem tra moi truong Windows cho Supabase
# ==============================================

# Import module - dam bao load dung cach bat ke chay tu thu muc nao
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$modulePath = Join-Path $scriptDir "SupabaseKit.psm1"
if (Test-Path $modulePath) {
    Import-Module $modulePath -Force
} else {
    Write-Host "LOI: Khong tim thay module SupabaseKit.psm1 tai: $modulePath" -ForegroundColor Red
    exit 1
}

Write-Host "🔍 KIEM TRA TUONG THICH MOI TRUONG CHO SUPABASE..." @COLOR_TITLE

# ---------- 1. Kiem tra he dieu hanh ----------
Write-Info "1. Phat hien he dieu hanh..."
$osVersion = [System.Environment]::OSVersion.Version
$osCaption = (Get-WmiObject -Class Win32_OperatingSystem).Caption

Write-Host "   He dieu hanh: $osCaption" -ForegroundColor White
Write-Host "   Phien ban: $($osVersion.Major).$($osVersion.Minor).$($osVersion.Build)" -ForegroundColor White

# Windows 10/11 co major version >= 10
if ($osVersion.Major -ge 10) {
    Write-Success "[OK] He dieu hanh duoc ho tro (Windows 10/11)."
    $compat = $true
} else {
    Write-ErrorMsg "[ERROR] He dieu hanh khong duoc ho tro (can Windows 10 tro len)."
    $compat = $false
}

# ---------- 2. Kiem tra tai nguyen he thong ----------
Write-Info "2. Kiem tra tai nguyen he thong..."

# CPU
$cpu = Get-WmiObject Win32_Processor
Write-Host "   CPU: $($cpu.Name.Trim())" -ForegroundColor White

# Kiem tra kien truc CPU (x64)
$cpuArch = $env:PROCESSOR_ARCHITECTURE
if ($cpuArch -eq "AMD64") {
    Write-Success "[OK] Kien truc CPU x64 duoc ho tro."
} else {
    Write-WarningMsg "[WARN] Kien truc CPU khong phai x64: $cpuArch"
    $compat = $false
}

# RAM
$ram = Get-WmiObject Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum
$ramMB = [math]::Round($ram.Sum / 1MB)
Write-Host "   RAM: $ramMB MB" -ForegroundColor White

if ($ramMB -ge 2048) {
    Write-Success "[OK] RAM du (>= 2GB): ${ramMB}MB"
} else {
    Write-WarningMsg "[WARN] RAM thap (< 2GB): ${ramMB}MB - Supabase co the hoat dong cham"
}

# ---------- 3. Kiem tra Docker ----------
Write-Info "3. Kiem tra Docker..."

if (Get-Command "docker" -ErrorAction SilentlyContinue) {
    $dockerVersion = docker --version 2>$null
    Write-Host "   Docker: $dockerVersion" -ForegroundColor White
    
    # Kiem tra xem Docker daemon co chay khong
    try {
        $dockerInfo = docker info 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "[OK] Docker hoat dong tot."
        } else {
            Write-ErrorMsg "[ERROR] Docker khong chay duoc. Hay khoi dong Docker Desktop."
            $compat = $false
        }
    } catch {
        Write-ErrorMsg "[ERROR] Docker khong chay duoc. Hay khoi dong Docker Desktop."
        $compat = $false
    }
} else {
    Write-ErrorMsg "[ERROR] Docker chua cai dat. Vui long cai Docker Desktop."
    $compat = $false
}

# ---------- 4. Kiem tra Hyper-V/Virtualization ----------
Write-Info "4. Kiem tra ao hoa..."

$hyperVFeature = Get-WindowsOptionalFeature -Online | Where-Object { $_.FeatureName -eq "Microsoft-Hyper-V-All" }
if ($hyperVFeature) {
    if ($hyperVFeature.State -eq "Enabled") {
        Write-Success "[OK] Hyper-V duoc kich hoat."
    } else {
        Write-WarningMsg "[WARN] Hyper-V khong duoc kich hoat. Docker co the hoat dong cham hon."
    }
} else {
    Write-WarningMsg "[WARN] Khong tim thay Hyper-V. Docker Desktop su dung WSL 2 backend."
}

# ---------- 5. Kiem tra WSL2 (neu can) ----------
Write-Info "5. Kiem tra WSL2 (yeu cau cho Docker tren Windows)..."

try {
    $wslVersion = wsl --version 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Success "[OK] WSL duoc cai dat: $wslVersion"
        
        # Kiem tra phien ban WSL mac dinh
        $wslDefaultVersion = wsl --set-default-version 2 2>$null
        if ($?) {
            Write-Success "[OK] WSL2 la phien ban mac dinh."
        } else {
            Write-WarningMsg "[WARN] Khong the thiet lap WSL2 la mac dinh."
        }
    } else {
        Write-WarningMsg "[WARN] WSL khong duoc cai dat (WSL2 duoc Docker khuyen nghi)."
    }
} catch {
    Write-WarningMsg "[WARN] WSL khong duoc cai dat (WSL2 duoc Docker khuyen nghi)."
}

# ---------- 6. Kiem tra dung luong dia ----------
Write-Info "6. Kiem tra dung luong dia trong..."

$drive = (Get-Location).Drive
$freeSpaceMB = [math]::Round($drive.Free / 1MB)

Write-Host "   O dia hien tai: $($drive.Name) ($([math]::Round($drive.TotalSize / 1GB)) GB tong) - $freeSpaceMB MB trong" -ForegroundColor White

if ($freeSpaceMB -gt 5000) {  # > 5GB
    Write-Success "[OK] Dung luong dia du cho Supabase."
} else {
    Write-WarningMsg "[WARN] Dung luong dia thap: $freeSpaceMB MB trong. Supabase can it nhat ~5GB."
    if ($freeSpaceMB -lt 2000) {
        $compat = $false
    }
}

# ---------- 7. Kiem tra ket noi Internet ----------
Write-Info "7. Kiem tra ket noi Internet..."

if (Test-NetworkConnectivity) {
    Write-Success "[OK] Ket noi Internet on dinh."
} else {
    Write-ErrorMsg "[ERROR] Khong co ket noi Internet."
    $compat = $false
}

# ---------- Ket luan ----------
Write-Host ""
if ($compat) {
    Write-Success "Moi truong cua ban TUONG THICH de chay Supabase tren Windows."
    Write-Host "   Ban co the tiep tuc su dung chuc nang Khoi phuc/Dong bang." -ForegroundColor Green
} else {
    Write-ErrorMsg "Moi truong cua ban CO THE KHONG TUONG THICH hoan toan."
    Write-Host "   - Vui long kiem tra cac canh bao o tren va khac phuc." -ForegroundColor Yellow
    Write-Host "   - Dam bao Docker Desktop da duoc cai dat va dang chay." -ForegroundColor Yellow
    Write-Host "   - Kiem tra lai tai nguyen he thong (RAM, dung luong dia)." -ForegroundColor Yellow
}

Write-Title "KIEM TRA HOAN TAT"