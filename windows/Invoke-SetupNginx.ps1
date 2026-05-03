# ==============================================
# INVOKE-SETUPNGINX.PS1 – Cài đặt Nginx và cấu hình HTTPS
# -------------------------------------------------
# Cấu hình Nginx reverse proxy với SSL cho Supabase
# ==============================================

param(
    [string]$Domain = "",
    [string]$ProjectDir = ""
)

Import-Module .\SupabaseKit.psm1 -Force

Write-Title "CÀI ĐẶT HTTPS & DOMAIN CHO SUPABASE"

# Kiểm tra quyền admin
if (!(Test-Admin)) {
    Write-ErrorMsg "Chức năng này yêu cầu quyền Administrator để cài đặt và cấu hình Nginx."
    Write-Info "Vui lòng chạy PowerShell với quyền Administrator và thử lại."
    exit 1
}

# Xác định thư mục dự án nếu chưa được truyền vào
if ([string]::IsNullOrWhiteSpace($ProjectDir)) {
    $ProjectDir = Find-SupabaseDir (Get-Location).Path
    if (-not $ProjectDir) {
        do {
            $ProjectDir = Read-Host "Nhập đường mục dự án Supabase (chứa .env và docker-compose.yml)"
        } until (Test-Path $ProjectDir)
    }
}

# Nếu không có domain, yêu cầu người dùng nhập
if ([string]::IsNullOrWhiteSpace($Domain)) {
    do {
        $Domain = Read-Host "Nhập domain của bạn"
    } while (!(Test-Domain $Domain))
}

Write-Info "Domain: $Domain"
Write-Info "Thư mục dự án: $ProjectDir"

# Kiểm tra xem Docker có đang chạy không
if (!(Test-DockerAvailable)) {
    Write-ErrorMsg "Docker không khả dụng. Vui lòng cài đặt hoặc khởi động Docker."
    exit 1
}

# Kiểm tra xem Supabase có đang chạy không
$supabaseContainers = docker ps --format "{{.Names}}" | Select-String "supabase"
if (!($supabaseContainers)) {
    Write-WarningMsg "Không tìm thấy container Supabase đang chạy. Vui lòng khởi động Supabase trước khi tiếp tục."
    $startNow = Read-Host "Bạn có muốn thử khởi động Supabase ngay không? (y/n)"
    if ($startNow -eq "y") {
        Push-Location $ProjectDir
        $composeCmd = Get-DockerComposeCommand
        & $composeCmd -f "docker-compose.yml" up -d
        Pop-Location
        
        # Đợi một chút để container khởi động
        Start-Sleep -Seconds 10
    }
}

# Cài đặt Chocolatey nếu chưa có
if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Info "Đang cài đặt Chocolatey (trình quản lý gói cho Windows)..."
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
}

# Cài đặt Nginx
if (!(Get-Command nginx -ErrorAction SilentlyContinue)) {
    Write-Info "Đang cài đặt Nginx..."
    choco install nginx -y
    if ($LASTEXITCODE -ne 0) {
        Write-ErrorMsg "Cài đặt Nginx thất bại."
        exit 1
    }
    Write-Success "Nginx đã được cài đặt."
} else {
    Write-Info "Nginx đã được cài đặt."
}

# Dừng Nginx nếu đang chạy
Write-Info "Đang dừng Nginx nếu đang chạy..."
Stop-Service nginx -Force -ErrorAction SilentlyContinue
# Chờ một chút để đảm bảo Nginx đã dừng
Start-Sleep -Seconds 2

# Cấu hình Nginx
$confDir = "C:\tools\nginx\conf"
$nginxConfPath = Join-Path $confDir "nginx.conf"

if (Test-Path $nginxConfPath) {
    # Sao lưu cấu hình gốc
    Copy-Item $nginxConfPath "$nginxConfPath.backup" -Force
    Write-Info "Đã sao lưu cấu hình Nginx gốc."
    
    # Tạo cấu hình cho Supabase
    $nginxConfig = @"
worker_processes  1;

events {
    worker_connections  1024;
}

http {
    include       mime.types;
    default_type  application/octet-stream;
    sendfile      on;
    keepalive_timeout  65;

    # Upstream servers
    upstream supabase_api {
        server 127.0.0.1:8000;  # API endpoint
    }

    upstream supabase_db {
        server 127.0.0.1:54322;  # Database port
    }

    upstream supabase_auth {
        server 127.0.0.1:9999;  # Auth endpoint
    }

    server {
        listen 80;
        server_name $Domain;

        # Redirect all HTTP traffic to HTTPS
        return 301 https://$Domain\$request_uri;
    }

    server {
        listen 443 ssl http2;
        server_name $Domain;

        ssl_certificate      C:\tools\nginx\ssl\${Domain}.crt;
        ssl_certificate_key  C:\tools\nginx\ssl\${Domain}.key;

        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers HIGH:!aNULL:!MD5;
        ssl_prefer_server_ciphers off;

        # Proxy settings
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;

        # API endpoint
        location / {
            proxy_pass http://supabase_api;
        }

        # Auth endpoint
        location /auth {
            proxy_pass http://supabase_auth;
        }

        # Database endpoint
        location /pg {
            proxy_pass http://supabase_db;
        }
    }
}
"@

    # Ghi cấu hình vào file
    Set-Content -Path $nginxConfPath -Value $nginxConfig
    Write-Success "Đã cập nhật cấu hình Nginx cho $Domain"
    
    # Tạo thư mục SSL nếu chưa có
    $sslDir = "C:\tools\nginx\ssl"
    if (!(Test-Path $sslDir)) {
        New-Item -ItemType Directory -Path $sslDir -Force | Out-Null
    }
    
    # Tạo chứng chỉ tự ký (trong thực tế, bạn nên dùng Let's Encrypt)
    Write-Info "Đang tạo chứng chỉ SSL tự ký..."
    $certConfig = @"
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn

[dn]
CN=$Domain
"@
    
    $certConfigPath = Join-Path $env:TEMP "cert_config.cnf"
    Set-Content -Path $certConfigPath -Value $certConfig
    
    # Tạo key và cert
    $opensslCmd = "openssl req -x509 -newkey rsa:2048 -keyout `"$sslDir\${Domain}.key`" -out `"$sslDir\${Domain}.crt`" -days 365 -nodes -config `"$certConfigPath`" -subj `"/C=VN/ST=Ho Chi Minh/L=Ho Chi Minh/O=Supabase/OU=IT/CN=$Domain`""
    
    # Kiểm tra xem có OpenSSL không
    if (Get-Command openssl -ErrorAction SilentlyContinue) {
        Invoke-Expression $opensslCmd
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Đã tạo chứng chỉ SSL cho $Domain"
        } else {
            Write-ErrorMsg "Tạo chứng chỉ SSL thất bại"
            exit 1
        }
    } else {
        Write-WarningMsg "OpenSSL không khả dụng. Bạn cần cài đặt OpenSSL để tạo chứng chỉ SSL."
        Write-Info "Bạn có thể cài đặt OpenSSL bằng lệnh: choco install openssl"
        exit 1
    }
    
    # Khởi động lại Nginx
    Write-Info "Đang khởi động lại Nginx..."
    Start-Service nginx -ErrorAction SilentlyContinue
    
    # Kiểm tra lại trạng thái dịch vụ
    $nginxService = Get-Service nginx
    if ($nginxService.Status -eq "Running") {
        Write-Success "Nginx đang chạy và cấu hình SSL đã được áp dụng."
        Write-Info "Supabase hiện có thể truy cập qua: https://$Domain"
    } else {
        Write-ErrorMsg "Nginx không thể khởi động. Vui lòng kiểm tra cấu hình."
        Write-Info "Bạn có thể kiểm tra cấu hình bằng lệnh: nginx -t"
        exit 1
    }
} else {
    Write-ErrorMsg "Không tìm thấy file cấu hình Nginx: $nginxConfPath"
    exit 1
}

Write-Title "HOÀN TẤT CẤU HÌNH HTTPS & DOMAIN"
Write-Info "Truy cập Supabase của bạn tại: https://$Domain"
Write-Info "Cấu hình đã được lưu và Nginx đang chạy."
Write-Info "Lưu ý: Trong môi trường thực tế, bạn nên sử dụng chứng chỉ từ Let's Encrypt thay vì chứng chỉ tự ký."