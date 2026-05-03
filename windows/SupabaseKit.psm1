# ==============================================
# SUPABASEKIT.PSM1 – Module tiện ích cho Supabase Kit
# -------------------------------------------------
# Module này cung cấp các hàm tiện ích dùng chung cho các script PowerShell khác
# ==============================================

function Write-Title {
    param([string]$Message)
    Write-Host "=" * 50 -ForegroundColor Cyan
    Write-Host $Message -ForegroundColor Yellow -BackgroundColor Black
    Write-Host "=" * 50 -ForegroundColor Cyan
}

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Green
}

function Write-WarningMsg {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-ErrorMsg {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Step {
    param([int]$Current, [int]$Total, [string]$Description)
    Write-Host "[$Current/$Total] $Description" -ForegroundColor Cyan
}

function Test-DockerAvailable {
    if (!(Get-Command docker -ErrorAction SilentlyContinue)) {
        Write-ErrorMsg "Docker chưa được cài đặt."
        return $false
    }
    return $true
}

function Test-Network {
    try {
        $response = Invoke-WebRequest -Uri "https://www.google.com" -TimeoutSec 10 -UseBasicParsing
        if ($response.StatusCode -eq 200) {
            Write-Success "Kết nối mạng ổn định."
            return $true
        }
    } catch {
        Write-ErrorMsg "Lỗi kết nối mạng: $_"
        return $false
    }
    return $false
}

function Find-SupabaseDir {
    param([string]$StartPath)
    
    # Tìm trong thư mục hiện tại trước
    if (Test-Path (Join-Path $StartPath ".env") -PathType Leaf -and 
        (Test-Path (Join-Path $StartPath "docker-compose.yml") -PathType Leaf)) {
        return $StartPath
    }
    
    # Tìm đệ quy trong thư mục cha
    $currentDir = $StartPath
    while ($currentDir) {
        if (Test-Path (Join-Path $currentDir ".env") -PathType Leaf -and 
            (Test-Path (Join-Path $currentDir "docker-compose.yml") -PathType Leaf)) {
            return $currentDir
        }
        $parentDir = Split-Path $currentDir -Parent
        if ($parentDir -eq $currentDir) { break }  # Đã đến root
        $currentDir = $parentDir
    }
    
    return $null
}

function Test-SupabaseDir {
    param([string]$Path)
    
    if (Test-Path $Path) {
        $envPath = Join-Path $Path ".env"
        $composePath = Join-Path $Path "docker-compose.yml"
        
        return (Test-Path $envPath -and (Test-Path $composePath))
    }
    
    return $false
}

function Get-DockerComposeCommand {
    if (Get-Command "docker-compose" -ErrorAction SilentlyContinue) {
        return "docker-compose"
    } elseif (Get-Command "docker" -ErrorAction SilentlyContinue) {
        # Kiểm tra xem docker có hỗ trợ subcommand compose không
        $dockerHelp = docker help | Out-String
        if ($dockerHelp -match "compose") {
            return "docker compose"
        }
    }
    throw "Không tìm thấy docker-compose"
}

function Get-FileChecksum {
    param([string]$FilePath)
    
    if (Test-Path $FilePath) {
        $hash = Get-FileHash -Path $FilePath -Algorithm SHA256
        Write-Info "Checksum (SHA256) của $FilePath :"
        Write-Host $hash.Hash
        return $hash.Hash
    }
    return $null
}

function Remove-TempDir {
    param([string]$TempDir)
    
    if (Test-Path $TempDir) {
        Remove-Item -Path $TempDir -Recurse -Force
        Write-Info "Đã dọn thư mục tạm: $TempDir"
    }
}

function Test-Admin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Invoke-GDriveUpload {
    param([string]$FilePath)
    
    if (!(Get-Command rclone -ErrorAction SilentlyContinue)) {
        Write-ErrorMsg "rclone chưa được cài đặt. Vui lòng cài đặt rclone để upload Google Drive."
        return
    }
    
    # Kiểm tra xem remote gdrive đã được cấu hình chưa
    $remotes = rclone listremotes
    if ($remotes -notmatch "^gdrive:") {
        Write-ErrorMsg "Remote 'gdrive' chưa được cấu hình. Vui lòng chạy supa-setup-gdrive.sh trước."
        return
    }
    
    $fileName = Split-Path $FilePath -Leaf
    Write-Info "Đang upload $fileName lên Google Drive..."
    rclone copy "$FilePath" "gdrive:/" --progress
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Upload thành công lên Google Drive."
    } else {
        Write-ErrorMsg "Upload thất bại."
    }
}

# ==============================================
# CÁC HÀM MỚI ĐƯỢC BỔ SUNG ĐỂ TƯƠNG THÍCH VỚI PHIÊN BẢN LINUX
# ==============================================

# Hàm kiểm tra dung lượng đĩa
function Test-DiskSpace {
    param(
        [int]$RequiredMB,
        [string]$Path = $PWD
    )
    
    $drive = Get-PSDrive -Name ([System.IO.Path]::GetPathRoot($Path)) -ErrorAction SilentlyContinue
    if ($drive) {
        $freeSpaceMB = [math]::Round($drive.Free / 1MB)
        Write-Info "Dung lượng trống: $freeSpaceMB MB, yêu cầu: $RequiredMB MB"
        
        if ($freeSpaceMB -lt $RequiredMB) {
            Write-ErrorMsg "Không đủ dung lượng đĩa. Cần ít nhất $RequiredMB MB trống."
            return $false
        }
        return $true
    }
    
    Write-ErrorMsg "Không thể kiểm tra dung lượng đĩa cho đường dẫn: $Path"
    return $false
}

# Hàm kiểm tra domain
function Test-Domain {
    param([string]$Domain)
    
    # Kiểm tra định dạng cơ bản của domain
    if ($Domain -match "^[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,}$") {
        return $true
    }
    
    Write-ErrorMsg "Định dạng domain không hợp lệ: $Domain"
    return $false
}

# Hàm kiểm tra và xử lý sysctl trong file docker-compose.yml
function Repair-SysctlConfig {
    param([string]$ComposeFilePath)
    
    if (Test-Path $ComposeFilePath) {
        $content = Get-Content $ComposeFilePath -Raw
        
        # Kiểm tra xem có chứa cấu hình sysctl không tương thích không
        if ($content -match "ip_unprivileged_port_start") {
            Write-WarningMsg "Tìm thấy cấu hình sysctl không tương thích, đang sửa..."
            
            # Xóa các dòng có chứa ip_unprivileged_port_start
            $newContent = $content -replace '\s*-\s*sysctl\s*.\s*net\.ipv4\.ip_unprivileged_port_start.*\n', "`n"
            $newContent = $newContent -replace '\s*net\.ipv4\.ip_unprivileged_port_start.*\n', "`n"
            
            # Ghi lại file
            Set-Content -Path $ComposeFilePath -Value $newContent
            Write-Success "Đã sửa file docker-compose.yml để tương thích với container."
            
            return $true
        }
    }
    
    return $false
}

# Hàm chờ cho đến khi database sẵn sàng
function Wait-DatabaseReady {
    param(
        [string]$DbContainer,
        [int]$TimeoutSeconds = 60
    )
    
    Write-Info "Chờ database sẵn sàng (tối đa $TimeoutSeconds giây)..."
    
    $elapsed = 0
    while ($elapsed -lt $TimeoutSeconds) {
        try {
            $result = docker exec $DbContainer pg_isready -U postgres 2>$null
            if ($LASTEXITCODE -eq 0) { 
                Write-Success "Database đã sẵn sàng."
                return $true
            }
        } catch {
            # ignore error and continue
        }
        
        Start-Sleep -Seconds 3
        $elapsed += 3
    }
    
    Write-ErrorMsg "Database không sẵn sàng sau $TimeoutSeconds giây."
    return $false
}

# Hàm tìm container database
function Find-DatabaseContainer {
    $dbContainers = docker ps --format "{{.Names}}" | Where-Object { $_ -match "supabase.*db|db" }
    return $dbContainers | Select-Object -First 1
}

# Hàm tìm container storage
function Find-StorageVolume {
    $storageVolumes = docker volume ls --format "{{.Name}}" | Where-Object { $_ -match "_storage" }
    return $storageVolumes | Select-Object -First 1
}

# Hàm kiểm tra phiên bản OS
function Test-OSVersion {
    $os = Get-CimInstance Win32_OperatingSystem
    Write-Info "Hệ điều hành: Windows $($os.Version)"
    
    # Chỉ kiểm tra cơ bản trên Windows
    return $true
}

# Hàm dọn dẹp các container cũ
function Remove-OldContainers {
    param([string]$ProjectDir)
    
    Write-Info "Đang kiểm tra các container cũ..."
    
    # Tìm các container có tên chứa "supabase"
    $orphanContainers = docker ps -a --filter "name=supabase" --format "{{.ID}}"
    
    if ($orphanContainers) {
        Write-WarningMsg "Tìm thấy các container Supabase cũ."
        docker ps -a --filter "name=supabase" --format "table {{.Names}}\t{{.Status}}"
        
        $confirm = Read-Host "Bạn có muốn xóa các container này không? (y/n)"
        if ($confirm -eq 'y') {
            docker rm -f $orphanContainers 2>$null | Out-Null
            Write-Success "Đã xóa các container cũ."
        }
    } else {
        Write-Info "Không tìm thấy container cũ nào."
    }
}

# Xuất các hàm để sử dụng khi module được import
Export-ModuleMember -Function *