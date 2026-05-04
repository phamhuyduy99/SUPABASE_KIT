# SupabaseKit.psm1 - Module dung chung cho toan bo kit tren Windows

$script:Red = "Red"
$script:Green = "Green"
$script:Yellow = "Yellow"
$script:Cyan = "Cyan"
$script:Magenta = "Magenta"
$script:White = "White"

function Write-ColorOutput {
    param([string]$ForegroundColor, [string]$Message)
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    Write-Output $Message
    $host.UI.RawUI.ForegroundColor = $fc
}

function Write-Success($msg) { Write-ColorOutput Green "✓ $msg" }
function Write-ErrorMsg($msg) { Write-ColorOutput Red "✗ $msg" }
function Write-WarningMsg($msg) { Write-ColorOutput Yellow "⚠ $msg" }
function Write-Info($msg) { Write-ColorOutput Cyan "ℹ $msg" }
function Write-Title($msg) { Write-ColorOutput Magenta "=== $msg ===" }
function Write-Step($current, $total, $msg) { Write-ColorOutput White "[$current/$total] $msg" }

function Test-DockerAvailable {
    if (!(Get-Command docker -ErrorAction SilentlyContinue)) {
        Write-ErrorMsg "Docker chua duoc cai dat. Vui long cai Docker Desktop tu https://www.docker.com/products/docker-desktop/"
        return $false
    }
    $null = docker info 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-ErrorMsg "Docker Desktop chua chay. Hay mo Docker Desktop va thu lai."
        return $false
    }
    Write-Success "Docker da san sang."
    return $true
}

function Test-Network {
    if (Test-Connection -ComputerName 8.8.8.8 -Count 2 -Quiet) { return $true }
    else { Write-ErrorMsg "Khong co ket noi Internet."; return $false }
}

function Test-SupabaseDir {
    param([string]$Path)
    return (Test-Path "$Path\.env") -and (Test-Path "$Path\docker-compose.yml")
}

function Find-SupabaseDir {
    param([string]$StartDir)
    $dir = $StartDir
    for ($i=1; $i -le 5; $i++) {
        if (Test-SupabaseDir $dir) { return $dir }
        $dir = Split-Path -Parent $dir
        if ([string]::IsNullOrEmpty($dir)) { break }
    }
    return $null
}

function Test-DiskSpace {
    param([int]$RequiredMB, [string]$Path = ".")
    $root = (Resolve-Path $Path).Path.Split(":")[0] + ":"
    $free = (Get-PSDrive -Name $root.TrimEnd(':')).Free
    $freeMB = [math]::Round($free / 1MB)
    if ($freeMB -lt $RequiredMB) {
        Write-ErrorMsg "Khong du dung luong dia. Can it nhat $RequiredMB MB, hien chi co $freeMB MB."
        return $false
    }
    return $true
}

function Test-Domain {
    param([string]$Domain)
    if ($Domain -match '^([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}$') { return $true }
    Write-ErrorMsg "Domain khong hop le."
    return $false
}

function Get-DockerComposeCommand {
    $null = docker compose version 2>&1
    if ($LASTEXITCODE -eq 0) { return "docker compose" }
    if (Get-Command docker-compose -ErrorAction SilentlyContinue) { return "docker-compose" }
    Write-ErrorMsg "Khong tim thay docker compose."
    exit 1
}

function Get-FileChecksum {
    param([string]$File)
    try {
        $hash = (Get-FileHash -Path $File -Algorithm SHA256).Hash
        "$hash  $(Split-Path $File -Leaf)" | Out-File -FilePath "$File.sha256" -Encoding ASCII
        Write-Success "Checksum da duoc tao: $File.sha256"
    } catch {
        Write-WarningMsg "Khong the tao checksum."
    }
}

function Remove-TempDir {
    param([string]$Dir)
    if ($Dir -like "$env:TEMP\*") { Remove-Item -Recurse -Force $Dir -ErrorAction SilentlyContinue }
}

function Test-Admin {
    $current = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($current)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Invoke-GDriveUpload {
    param([string]$File, [string]$Folder = "supabase-backups")
    if (!(Get-Command rclone -ErrorAction SilentlyContinue)) { Write-WarningMsg "rclone chua cai dat."; return }
    if (!(rclone listremotes | Select-String "^gdrive:")) { Write-WarningMsg "Remote gdrive chua cau hinh."; return }
    Write-Info "Dang upload len Google Drive..."
    rclone copy $File "gdrive:$Folder" --progress
    if ($LASTEXITCODE -eq 0) { Write-Success "Upload thanh cong." }
    else { Write-ErrorMsg "Upload that bai." }
}

function Find-DatabaseContainer {
    docker ps --format ".Names" | Select-String "supabase.*db|db" | Select-Object -First 1
}

function Find-StorageVolume {
    docker volume ls --format ".Name" | Select-String "_storage" | Select-Object -First 1
}

function Wait-DatabaseReady {
    param([string]$DbContainer, [int]$TimeoutSeconds = 60)
    Write-Info "Cho database san sang..."
    for ($i=0; $i -lt $TimeoutSeconds/3; $i++) {
        if (docker exec $DbContainer pg_isready -U postgres 2>$null) {
            Write-Success "Database da san sang."
            return $true
        }
        Start-Sleep -Seconds 3
    }
    Write-ErrorMsg "Database khong san sang sau $TimeoutSeconds giay."
    return $false
}

function Remove-OldContainers {
    param([string]$ProjectDir)
    $orphans = docker ps -a --filter "name=supabase" -q
    if ($orphans) {
        Write-WarningMsg "Tim thay container Supabase cu, dang xoa..."
        docker rm -f $orphans 2>$null | Out-Null
        Write-Success "Da xoa."
    }
}

function Repair-SysctlConfig {
    param([string]$ComposeFilePath)
    if (!(Test-Path $ComposeFilePath)) { return $false }
    $content = Get-Content $ComposeFilePath -Raw
    if ($content -match "ip_unprivileged_port_start") {
        Write-WarningMsg "Dang sua sysctl khong tuong thich..."
        $newContent = $content -replace '.*ip_unprivileged_port_start.*', ''
        Set-Content -Path $ComposeFilePath -Value $newContent
        Write-Success "Da sua."
        return $true
    }
    return $false
}

Export-ModuleMember -Function *