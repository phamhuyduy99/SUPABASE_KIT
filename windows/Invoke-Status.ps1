# Invoke-Status.ps1 – Kiểm tra container Supabase
Import-Module .\SupabaseKit.psm1 -Force

Write-Title "TRẠNG THÁI CONTAINER"
if (!(Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-ErrorCustom "Docker chưa được cài đặt."
    exit
}

$containers = docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>$null
if ($containers) {
    foreach ($line in $containers) {
        if ($line -match "Up") { 
            Write-Host $line -ForegroundColor Green 
        }
        elseif ($line -match "Exited|Dead") { 
            Write-Host $line -ForegroundColor Yellow 
        }
        else { 
            Write-Host $line 
        }
    }
} else {
    Write-WarningCustom "Không có container nào đang chạy."
}

# Additional status check for Supabase services
Write-Info "Kiểm tra các dịch vụ Supabase..."
$composeFile = Join-Path (Get-Location) "docker-compose.yml"
if (Test-Path $composeFile) {
    $composeCmd = Get-DockerComposeCommand
    $services = & $composeCmd -f $composeFile config --services 2>$null
    if ($services) {
        Write-Info "Dịch vụ Supabase:"
        foreach ($service in $services) {
            if ($service) {
                $status = & $composeCmd -f $composeFile ps $service --format "table {{.Service}}\t{{.Status}}\t{{.Publishers}}"
                Write-Host $status
            }
        }
    }
} else {
    Write-WarningCustom "Không tìm thấy docker-compose.yml trong thư mục hiện tại."
}