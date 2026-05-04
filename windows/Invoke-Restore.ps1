# Invoke-Restore.ps1 – Khoi phuc Supabase tren Windows (day du 25 chien luoc sysctl)
# ================================================================================
# Script nay thuc hien khoi phuc toan bo he thong Supabase tu mot file backup.
# Tuong thich voi backup tao boi supa-freeze.sh (Linux) hoac Invoke-Freeze.ps1 (Windows).
# Yeu cau: Docker Desktop dang chay, PowerShell voi quyen Administrator (khuyen dung).

# Import module - dam bao load dung cach bat ke chay tu thu muc nao
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$modulePath = Join-Path $scriptDir "SupabaseKit.psm1"
if (Test-Path $modulePath) {
    Import-Module $modulePath -Force
} else {
    Write-Host "LOI: Khong tim thay module SupabaseKit.psm1 tai: $modulePath" -ForegroundColor Red
    exit 1
}

Write-Title "KHOI PHUC HE THONG SUPABASE (DAY DU CHIEN LUOC)"

# ---------- KIEM TRA MOI TRUONG ----------
Write-Info "Dang kiem tra moi truong..."
if (!(Test-DockerAvailable)) { exit 1 }
if (!(Test-Network)) { exit 1 }
Write-Success "Moi truong Docker va mang on dinh."

# ---------- CHON NGUON BACKUP ----------
Write-Step 1 6 "CHON NGUON BACKUP"
$source = Read-Host "Duong dan file backup (.tar.gz, .zip) hoac thu muc da giai nen"
if ($source -match '^gdrive:') {
    if (!(Get-Command rclone -ErrorAction SilentlyContinue)) { Write-ErrorMsg "rclone chua cai."; exit 1 }
    $local = Join-Path $env:TEMP "restore-$pid.tar.gz"
    rclone copy $source $local --progress
    $source = $local
}
if (!(Test-Path $source)) { Write-ErrorMsg "Khong tim thay nguon backup."; exit 1 }

$backupDataDir = $null
if (Test-Path $source -PathType Container) {
    $backupDataDir = Join-Path $source "backup_data"
} elseif ($source -like '*.tar.gz' -or $source -like '*.zip') {
    $tmpDir = Join-Path $env:TEMP "supabase-restore-$pid"
    Remove-Item -Recurse -Force $tmpDir -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $tmpDir | Out-Null
    if ($source -like '*.tar.gz') {
        if (Get-Command "7z" -ErrorAction SilentlyContinue) { Set-Location $tmpDir; 7z x $source | Out-Null; Set-Location $PSScriptRoot }
        elseif (Get-Command "tar" -ErrorAction SilentlyContinue) { tar -xzf $source -C $tmpDir }
        else { Write-ErrorMsg "Can 7-Zip hoac Git."; exit 1 }
    } else { Expand-Archive -Path $source -DestinationPath $tmpDir }
    $firstDir = Get-ChildItem $tmpDir -Directory | Select-Object -First 1
    $backupDataDir = Join-Path $firstDir.FullName "backup_data"
} else { Write-ErrorMsg "Dinh dang khong duoc ho tro."; exit 1 }
if (!(Test-Path $backupDataDir)) { Write-ErrorMsg "Khong tim thay backup_data."; exit 1 }

# ---------- THU MUC CAI DAT ----------
Write-Step 2 6 "CHON THU MUC CAI DAT"
$targetDir = Read-Host "Thu muc cai dat (mac dinh C:\supabase-restored)"
if ([string]::IsNullOrWhiteSpace($targetDir)) { $targetDir = "C:\supabase-restored" }
New-Item -ItemType Directory -Path $targetDir -Force | Out-Null

# ---------- DON DEP CONTAINER CU ----------
Remove-OldContainers

# ---------- SAO CHEP CAU HINH & VOLUMES ----------
Write-Step 3 6 "SAO CHEP CAU HINH"
Copy-Item "$backupDataDir\config\.env" $targetDir
Copy-Item "$backupDataDir\config\docker-compose.yml" $targetDir
$volBackup = Join-Path $backupDataDir "volumes"
if (Test-Path $volBackup) { Copy-Item "$volBackup\*" $targetDir -Recurse }

# ---------- SUA SYSCTL ----------
Repair-SysctlConfig "$targetDir\docker-compose.yml"

# ---------- KHOI DONG (25 CHIEN LUOC) ----------
Write-Step 4 6 "KHOI DONG SUPABASE"
$composeCmd = Get-DockerComposeCommand
$originalCompose = Join-Path $targetDir "docker-compose.yml.original"
Copy-Item "$targetDir\docker-compose.yml" $originalCompose

function Try-Start {
    & $composeCmd -f "$targetDir\docker-compose.yml" up -d 2>$null
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
    # Chien luoc 1: Xoa dong sysctl khoi docker-compose.yml
    {
        Write-Info "Chien luoc 1: Xoa dong sysctl (ip_unprivileged_port_start)..."
        $content = Get-Content "$targetDir\docker-compose.yml" -Raw
        $content -replace '.*ip_unprivileged_port_start.*', '' | Set-Content "$targetDir\docker-compose.yml"
        Try-Start
    },
    # Chien luoc 2: Them privileged: true cho cac service can thiet
    {
        Write-Info "Chien luoc 2: Them privileged: true cho vector, imgproxy, db..."
        $lines = Get-Content "$targetDir\docker-compose.yml"
        $new = @()
        foreach ($l in $lines) {
            $new += $l
            if ($l -match '^\s+image:') { $new += '    privileged: true' }
        }
        $new | Set-Content "$targetDir\docker-compose.yml"
        Try-Start
    },
    # Chien luoc 3: Them security_opt va cap_add
    {
        Write-Info "Chien luoc 3: Them security_opt va cap_add..."
        $lines = Get-Content "$targetDir\docker-compose.yml"
        $new = @()
        foreach ($l in $lines) {
            $new += $l
            if ($l -match '^\s+image:') {
                $new += '    security_opt:'
                $new += '      - seccomp:unconfined'
                $new += '    cap_add:'
                $new += '      - SYS_ADMIN'
            }
        }
        $new | Set-Content "$targetDir\docker-compose.yml"
        Try-Start
    },
    # Chien luoc 4: Cau hinh Docker daemon (tang ulimit)
    {
        Write-Info "Chien luoc 4: Cau hinh Docker daemon..."
        $daemonConfig = "$env:ProgramData\Docker\config\daemon.json"
        if (Test-Path $daemonConfig) {
            $json = Get-Content $daemonConfig -Raw | ConvertFrom-Json
            $json | Add-Member -NotePropertyName "default-ulimits" -NotePropertyValue @{ nofile = @{ Hard = 65536; Name = "nofile"; Soft = 65536 } } -Force
            $json | ConvertTo-Json -Depth 5 | Set-Content $daemonConfig
            Restart-Service *docker*
        }
        Try-Start
    },
    # Chien luoc 5: Ha cap containerd (khong ho tro tren Windows)
    {
        Write-Info "Chien luoc 5: Ha cap containerd (khong ap dung tren Windows)..."
        Write-WarningMsg "Windows khong ho tro tu dong ha cap containerd."
        $false
    },
    # Chien luoc 6: Doi tag image (sang phien ban cu hon)
    {
        Write-Info "Chien luoc 6: Doi tag image sang phien ban cu hon (v0.23.11)..."
        $content = Get-Content "$targetDir\docker-compose.yml" -Raw
        $content -replace ':latest', ':v0.23.11' | Set-Content "$targetDir\docker-compose.yml"
        Try-Start
    },
    # Chien luoc 7: Huong dan thu runtime khac (sysbox)
    {
        Write-Info "Chien luoc 7: Huong dan thu runtime khac..."
        Write-WarningMsg "Hay thu cai dat sysbox hoac nvidia-runtime va them 'runtime: sysbox-runc' vao compose."
        $false
    },
    # Chien luoc 8: Kiem tra AppArmor/SELinux (khong ap dung tren Windows)
    {
        Write-Info "Chien luoc 8: Vo hieu hoa AppArmor/SELinux (khong ap dung tren Windows)..."
        Write-WarningMsg "Windows khong su dung AppArmor/SELinux."
        $false
    },
    # Chien luoc 9: Yeu cau nha cung cap VPS bat nesting (khong ap dung)
    {
        Write-Info "Chien luoc 9: Yeu cau nha cung cap VPS bat nesting (khong ap dung)..."
        Write-WarningMsg "Day la giai phap danh cho VPS LXC/OpenVZ, khong ap dung tren Windows."
        $false
    },
    # Chien luoc 10: Chuyen sang VPS KVM (khong ap dung)
    {
        Write-Info "Chien luoc 10: Chuyen sang VPS KVM (khong ap dung tren Windows)..."
        Write-WarningMsg "Windows chay tren may vat ly hoac Hyper-V, khong can chuyen doi."
        $false
    },
    # Chien luoc 11: Them sysctls thu cong
    {
        Write-Info "Chien luoc 11: Them sysctls thu cong vao docker-compose.yml..."
        $lines = Get-Content "$targetDir\docker-compose.yml"
        $new = @()
        foreach ($l in $lines) {
            $new += $l
            if ($l -match '^\s+image:') {
                $new += '    sysctls:'
                $new += '      - net.core.somaxconn=65535'
                $new += '      - net.ipv4.tcp_syncookies=1'
                $new += '      - net.ipv4.ip_unprivileged_port_start=0'
            }
        }
        $new | Set-Content "$targetDir\docker-compose.yml"
        Try-Start
    },
    # Chien luoc 12: Dat bien moi truong bo qua sysctl
    {
        Write-Info "Chien luoc 12: Dat bien moi truong COMPOSE_IGNORE_ORPHANS..."
        Add-Content "$targetDir\.env" "COMPOSE_IGNORE_ORPHANS=True"
        $env:COMPOSE_IGNORE_ORPHANS = "True"
        Try-Start
    },
    # Chien luoc 13: Khoi dong rieng tung service
    {
        Write-Info "Chien luoc 13: Khoi dong rieng tung service (db, imgproxy, vector)..."
        foreach ($svc in @('db', 'imgproxy', 'vector')) {
            & $composeCmd -f "$targetDir\docker-compose.yml" up -d $svc 2>$null
        }
        & $composeCmd -f "$targetDir\docker-compose.yml" up -d 2>$null
        Try-Start
    },
    # Chien luoc 14: Xoa toan bo volumes va networks cu
    {
        Write-Info "Chien luoc 14: Xoa toan bo volumes va networks cu..."
        docker system prune -af --volumes 2>$null
        Try-Start
    },
    # Chien luoc 15: Su dung Docker Compose V1 neu co
    {
        Write-Info "Chien luoc 15: Thu dung Docker Compose V1 (docker-compose)..."
        if (Get-Command docker-compose -ErrorAction SilentlyContinue) {
            & $composeCmd -f "$targetDir\docker-compose.yml" down 2>$null
            docker-compose -f "$targetDir\docker-compose.yml" up -d 2>$null
            Try-Start
        } else {
            Write-WarningMsg "docker-compose (V1) khong kha dung."
            $false
        }
    },
    # Chien luoc 16: Khoi dong voi co --compatibility
    {
        Write-Info "Chien luoc 16: Khoi dong voi co --compatibility..."
        & $composeCmd -f "$targetDir\docker-compose.yml" --compatibility up -d 2>$null
        Try-Start
    },
    # Chien luoc 17: Cap nhat Docker len phien ban moi nhat (khong tu dong)
    {
        Write-Info "Chien luoc 17: Cap nhat Docker len phien ban moi nhat..."
        Write-WarningMsg "Tu dong cap nhat Docker khong duoc ho tro tren Windows. Hay cap nhat Docker Desktop thu cong."
        $false
    },
    # Chien luoc 18: Khoi dong lai dich vu Docker
    {
        Write-Info "Chien luoc 18: Khoi dong lai dich vu Docker..."
        Restart-Service *docker*
        Start-Sleep -Seconds 5
        Try-Start
    },
    # Chien luoc 19: File docker-compose toi thieu
    {
        Write-Info "Chien luoc 19: Tao file docker-compose toi thieu chi chua cac service can sysctl..."
        $min = Join-Path $env:TEMP "minimal-compose.yml"
        Get-Content "$targetDir\docker-compose.yml" | Select-String -Pattern "^(  vector:|  imgproxy:|  db:)" -Context 0,20 | Out-File $min
        & $composeCmd -f $min up -d 2>$null
        $result = Try-Start
        Remove-Item $min -ErrorAction SilentlyContinue
        $result
    },
    # Chien luoc 20: De xuat su dung Supabase Cloud
    {
        Write-Info "Chien luoc 20: De xuat su dung Supabase Cloud..."
        Write-WarningMsg "Neu tat ca deu that bai, hay can nhac dung Supabase Cloud."
        $false
    },
    # Chien luoc 21: Vo hieu hoa toan bo sysctl trong compose
    {
        Write-Info "Chien luoc 21: Vo hieu hoa toan bo sysctl trong docker-compose.yml..."
        $content = Get-Content "$targetDir\docker-compose.yml" -Raw
        $content -replace 'sysctls:', '' -replace '^\s*- net\.', '' | Set-Content "$targetDir\docker-compose.yml"
        Try-Start
    },
    # Chien luoc 22: Khoi dong voi --no-deps --no-healthcheck
    {
        Write-Info "Chien luoc 22: Khoi dong voi --no-deps --no-healthcheck..."
        & $composeCmd -f "$targetDir\docker-compose.yml" up -d --no-deps --no-healthcheck 2>$null
        Try-Start
    },
    # Chien luoc 23: Dung docker run truc tiep
    {
        Write-Info "Chien luoc 23: Thu dung docker run truc tiep cho tung service..."
        $svcs = @('vector', 'imgproxy', 'db')
        foreach ($svc in $svcs) {
            $img = (Select-String -Path "$targetDir\docker-compose.yml" -Pattern "^  ${svc}:" -Context 0,5 | ForEach-Object { $_.Context.PostContext } | Select-String "image:" | ForEach-Object { $_ -replace '.*image:\s*', '' })
            if ($img) { docker run -d --name "supabase-$svc" --privileged $img 2>$null }
        }
        Try-Start
    },
    # Chien luoc 24: Lien he nha cung cap VPS sua AppArmor (khong ap dung)
    {
        Write-Info "Chien luoc 24: Lien he nha cung cap VPS sua AppArmor/profile (khong ap dung)..."
        Write-WarningMsg "Khong ap dung tren Windows."
        $false
    },
    # Chien luoc 25: Docker trong Docker hoac may ao
    {
        Write-Info "Chien luoc 25: Su dung Docker trong Docker (dind) hoac may ao..."
        Write-WarningMsg "Giai phap cuoi cung: cai may ao KVM trong Windows va chay Supabase tren do."
        $false
    }
)

$started = $false
for ($i = 0; $i -lt $strategies.Count; $i++) {
    $strategyNum = $i + 1
    Write-Info "Dang thu chien luoc ${strategyNum}/25..."
    if (& $strategies[$i]) {
        Write-Success "Thanh cong voi chien luoc ${strategyNum}!"
        $started = $true
        break
    }
    # Khoi phuc file compose goc neu bi hong
    Copy-Item $originalCompose "$targetDir\docker-compose.yml" -Force
}

if (-not $started) {
    Write-ErrorMsg "Da thu tat ca 25 chien luoc nhung khong khoi dong duoc."
    Write-WarningMsg "Nguyen nhan: moi truong ao hoa khong ho tro day du Docker."
    Write-Info "Hay chuyen sang VPS KVM hoac yeu cau nha cung cap bat nesting."
    exit 1
}

# ---------- IMPORT DATABASE & STORAGE ----------
Write-Step 5 6 "IMPORT DU LIEU"
$dbContainer = Find-DatabaseContainer
if ($dbContainer -and (Wait-DatabaseReady $dbContainer)) {
    $sqlGz = Join-Path $backupDataDir "database\full_backup.sql.gz"
    if (Test-Path $sqlGz) {
        Write-Info "Dang import database..."
        $sqlOut = Join-Path $env:TEMP "restore.sql"
        $in = [System.IO.File]::OpenRead($sqlGz)
        $gzip = New-Object System.IO.Compression.GzipStream($in, [System.IO.Compression.CompressionMode]::Decompress)
        $out = [System.IO.File]::Create($sqlOut)
        $gzip.CopyTo($out)
        $gzip.Close(); $in.Close(); $out.Close()
        Get-Content $sqlOut | docker exec -i $dbContainer psql -U postgres
        Remove-Item $sqlOut
        Write-Success "Database da phuc hoi."
    }
    $storageTar = Join-Path $backupDataDir "storage\storage.tar.gz"
    if (Test-Path $storageTar) {
        $storageVol = Find-StorageVolume
        if ($storageVol) {
            docker run --rm -v ${storageVol}:/mnt/storage -v "${backupDataDir}\storage:/backup:ro" alpine sh -c "cd /mnt/storage && tar xzf /backup/storage.tar.gz"
        } elseif (Test-Path "$targetDir\volumes\storage") {
            tar xzf $storageTar -C "$targetDir\volumes\storage"
        }
        Write-Success "Storage da phuc hoi."
    }
} else {
    Write-ErrorMsg "Khong tim thay container database hoac database khong san sang."
}

# ---------- HOAN TAT ----------
Write-Step 6 6 "HOAN TAT"
$ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notmatch "Loopback" } | Select-Object -First 1).IPAddress
Write-Title "KHOI PHUC HOAN TAT"
Write-Info "Truy cap Studio: http://${ip}:8000"
$envContent = Get-Content "$targetDir\.env"
Write-Info "Email: $( ($envContent | Select-String '^ADMIN_EMAIL=') -replace 'ADMIN_EMAIL=', '')"
Write-Info "Mat khau: $( ($envContent | Select-String '^ADMIN_PASSWORD=') -replace 'ADMIN_PASSWORD=', '')"