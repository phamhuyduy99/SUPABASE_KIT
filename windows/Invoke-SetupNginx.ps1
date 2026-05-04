# ==============================================
# INVOKE-SETUPNGINX.PS1 – Cai dat Nginx va cau hinh HTTPS
# -------------------------------------------------
# Cau hinh Nginx reverse proxy voi SSL cho Supabase
# ==============================================

param(
    [string]$Domain = "",
    [string]$ProjectDir = ""
)

# Import module - dam bao load dung cach bat ke chay tu thu muc nao
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$modulePath = Join-Path $scriptDir "SupabaseKit.psm1"
if (Test-Path $modulePath) {
    Import-Module $modulePath -Force
} else {
    Write-Host "LOI: Khong tim thay module SupabaseKit.psm1 tai: $modulePath" -ForegroundColor Red
    exit 1
}

Write-Title "CAI DAT NGINX VA CAU HINH HTTPS"

# Kiem tra quyen Admin
if (-not (Test-Admin)) {
    Write-ErrorMsg "Can quyen Administrator de cai dat Nginx."
    Write-Info "Vui long chay PowerShell voi quyen Administrator va thu lai."
    exit 1
}

# Nhap domain
if ([string]::IsNullOrWhiteSpace($Domain)) {
    $Domain = Read-Host "Nhap domain cua ban (vi du: supabase.example.com)"
}
if (-not (Test-Domain $Domain)) { exit 1 }

# Xac dinh thu muc du an
if ([string]::IsNullOrWhiteSpace($ProjectDir)) {
    $ProjectDir = Find-SupabaseDir (Get-Location).Path
    if (-not $ProjectDir) {
        do { $ProjectDir = Read-Host "Nhap duong dan thu muc Supabase (chua .env va docker-compose.yml)" }
        until (Test-Path $ProjectDir) # Note: Reference used Test-SupabaseDir but standard check is often sufficient or defined in module
    }
}

# Kiem tra Docker dang chay
if (-not (Test-DockerAvailable)) { exit 1 }

# Tai va cai dat Nginx
Write-Step 1 4 "CAI DAT NGINX"
$nginxUrl = "http://nginx.org/download/nginx-1.25.3.zip"
$nginxZip = Join-Path $env:TEMP "nginx.zip"
$nginxDir = "C:\nginx"

if (Test-Path $nginxDir) {
    Write-WarningMsg "Nginx da duoc cai dat tai $nginxDir"
} else {
    Write-Info "Dang tai Nginx..."
    try {
        Invoke-WebRequest -Uri $nginxUrl -OutFile $nginxZip
        Expand-Archive -Path $nginxZip -DestinationPath $env:TEMP
        $extracted = Get-ChildItem -Path $env:TEMP -Filter "nginx-*" | Select-Object -First 1
        Move-Item $extracted.FullName $nginxDir
        Remove-Item $nginxZip
        Write-Success "Da cai dat Nginx tai $nginxDir"
    } catch {
        Write-ErrorMsg "Khong the tai hoac cai dat Nginx: $($_.Exception.Message)"
        exit 1
    }
}

# Cau hinh Nginx
Write-Step 2 4 "CAU HINH NGINX"
$nginxConf = "$nginxDir\conf\nginx.conf"
$backupConf = "$nginxDir\conf\nginx.conf.bak"
Copy-Item $nginxConf $backupConf -Force

# Lay cong Supabase tu .env
$envPath = Join-Path $ProjectDir ".env"
if (Test-Path $envPath) {
    $envContent = Get-Content $envPath
    $kongPort = ($envContent | Select-String '^KONG_PORT=') -replace 'KONG_PORT=', ''
    $studioPort = ($envContent | Select-String '^STUDIO_PORT=') -replace 'STUDIO_PORT=', ''
} else {
    $kongPort = ""
    $studioPort = ""
}

if (-not $kongPort) { $kongPort = "8000" }
if (-not $studioPort) { $studioPort = "3000" }

# Tao cau hinh Nginx
$nginxConfig = @"
worker_processes  1;
events {
    worker_connections  1024;
}
http {
    include       mime.types;
    default_type  application/octet-stream;
    sendfile        on;
    keepalive_timeout  65;
    
    # Redirect HTTP to HTTPS
    server {
        listen 80;
        server_name $Domain;
        return 301 https://$Domain`$request_uri;
    }
    
    # HTTPS server
    server {
        listen 443 ssl http2;
        server_name $Domain;
        
        ssl_certificate      cert.pem;
        ssl_certificate_key  cert.key;
        
        ssl_session_cache    shared:SSL:1m;
        ssl_session_timeout  5m;
        
        ssl_ciphers  HIGH:!aNULL:!MD5;
        ssl_prefer_server_ciphers  on;
        
        location / {
            proxy_pass http://localhost:$kongPort;
            proxy_set_header Host `$host;
            proxy_set_header X-Real-IP `$remote_addr;
            proxy_set_header X-Forwarded-For `$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto `$scheme;
        }
        
        location /studio/ {
            proxy_pass http://localhost:$studioPort/;
            proxy_set_header Host `$host;
            proxy_set_header X-Real-IP `$remote_addr;
            proxy_set_header X-Forwarded-For `$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto `$scheme;
        }
    }
}
"@

Set-Content -Path $nginxConf -Value $nginxConfig
Write-Success "Da cau hinh Nginx cho domain: $Domain"

# Cai dat chung chi SSL (tu ky cho muc dich thu nghiem)
Write-Step 3 4 "CAI DAT CHUNG CHI SSL"
$certPath = "$nginxDir\conf\cert.pem"
$keyPath = "$nginxDir\conf\cert.key"

if (!(Test-Path $certPath) -or !(Test-Path $keyPath)) {
    Write-Info "Tao chung chi SSL tu ky..."
    try {
        $cert = New-SelfSignedCertificate -DnsName $Domain -CertStoreLocation "cert:\LocalMachine\My" -FriendlyName "Supabase SSL Certificate"
        Export-Certificate -Cert $cert -FilePath $certPath -Type PEM | Out-Null
        Export-PfxCertificate -Cert $cert -FilePath "$nginxDir\conf\cert.pfx" -Password (ConvertTo-SecureString -String "supabase" -Force -AsPlainText) | Out-Null
        
        # Trich xuat private key tu PFX (can OpenSSL)
        if (Get-Command openssl -ErrorAction SilentlyContinue) {
            openssl pkcs12 -in "$nginxDir\conf\cert.pfx" -nocerts -out "$nginxDir\conf\temp.key" -password pass:supabase -passout pass:supabase | Out-Null
            openssl rsa -in "$nginxDir\conf\temp.key" -out $keyPath -passin pass:supabase | Out-Null
            Remove-Item "$nginxDir\conf\temp.key", "$nginxDir\conf\cert.pfx"
        } else {
            Write-WarningMsg "OpenSSL khong duoc cai dat. Private key se khong duoc tao."
            Write-Info "Cai dat OpenSSL tu https://slproweb.com/products/Win32OpenSSL.html"
        }
        Write-Success "Da tao chung chi SSL tu ky."
    } catch {
        Write-WarningMsg "Khong the tao chung chi SSL: $($_.Exception.Message)"
        Write-Info "Ban can cau hinh chung chi SSL thu cong sau khi cai dat."
    }
} else {
    Write-Success "Chung chi SSL da ton tai."
}

# Khoi dong Nginx
Write-Step 4 4 "KHOI DONG NGINX"
try {
    Stop-Process -Name nginx -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    Start-Process -FilePath "$nginxDir\nginx.exe" -WorkingDirectory $nginxDir
    Start-Sleep -Seconds 2
    
    $nginxRunning = Get-Process -Name nginx -ErrorAction SilentlyContinue
    if ($nginxRunning) {
        Write-Success "Nginx da khoi dong thanh cong!"
        Write-Info "Truy cap Supabase qua: https://$Domain"
        Write-WarningMsg "Chung chi SSL hien tai la tu ky. Trinh duyet se hien thi canh bao bao mat."
        Write-Info "De su dung chung chi hop le, thay the cert.pem va cert.key trong $nginxDir\conf\"
    } else {
        Write-ErrorMsg "Nginx khong khoi dong duoc. Kiem tra file cau hinh va log loi."
        Write-Info "Log loi: $nginxDir\logs\error.log"
    }
} catch {
    Write-ErrorMsg "Loi khi khoi dong Nginx: $($_.Exception.Message)"
}

Write-Title "HOAN TAT CAI DAT NGINX"
Write-Info "Cau hinh Nginx da duoc sao luu tai: $backupConf"