#!/bin/bash
# supabase-kit/linux/supa-setup-nginx.sh
# Script để cài đặt và cấu hình Nginx reverse proxy cho Supabase

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

print_title "CÀI ĐẶT NGINX REVERSE PROXY CHO SUPABASE"

# Kiểm tra hệ điều hành
OS_TYPE=$(uname -s)
if [ "$OS_TYPE" != "Linux" ]; then
    print_error "Script này chỉ hỗ trợ Linux (không hỗ trợ macOS trực tiếp)."
    print_info "Đối với macOS, bạn có thể sử dụng Caddy hoặc thiết lập thủ công."
    exit 1
fi

# Kiểm tra quyền root
if ! sudo -n true 2>/dev/null; then
    print_error "Bạn cần quyền sudo để cài đặt Nginx."
    print_info "Vui lòng chạy lệnh này với quyền quản trị: sudo $0"
    exit 1
fi

# Hỏi thông tin cấu hình
read -p "Tên miền cho Supabase (ví dụ: supabase.example.com): " domain_name
if [[ -z "$domain_name" ]]; then
    print_error "Tên miền không được để trống."
    exit 1
fi

read -p "IP máy chủ (mặc định: 127.0.0.1): " server_ip
server_ip=${server_ip:-127.0.0.1}

print_info "Cấu hình sẽ được tạo cho tên miền: $domain_name"

# Cài đặt Nginx nếu chưa có
if ! command -v nginx &>/dev/null; then
    print_info "Đang cài đặt Nginx..."
    sudo apt update
    sudo apt install -y nginx
else
    print_success "Nginx đã được cài đặt."
fi

# Tạo cấu hình Nginx cho Supabase
config_file="/etc/nginx/sites-available/supabase-$domain_name"

print_info "Đang tạo tệp cấu hình Nginx..."

sudo tee "$config_file" > /dev/null <<EOF
# Cấu hình reverse proxy cho Supabase
server {
    listen 80;
    server_name $domain_name;

    # Redirect HTTP -> HTTPS
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $domain_name;

    # Đường dẫn tới SSL certificate (thiết lập sau với Let's Encrypt)
    ssl_certificate /path/to/certificate.crt;
    ssl_certificate_key /path/to/private.key;

    # Cấu hình SSL phổ biến
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;

    # Thời gian giữ kết nối
    keepalive_timeout    70;
    send_timeout         60;
    client_body_timeout  60;
    client_header_timeout 60;

    # Kích thước tối đa của request body
    client_max_body_size 100M;

    # API routes
    location ~ ^/(auth|rest|graphql|rpc|realtime|storage) {
        proxy_pass http://$server_ip:54321\$request_uri;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        proxy_redirect off;
    }

    # Auth redirects
    location ~ ^/(auth|rest|graphql|rpc|realtime|storage)/redirect {
        proxy_pass http://$server_ip:54321\$request_uri;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        proxy_redirect http://$server_ip:54321/ https://\$host/;
    }

    # Storage routes (for larger uploads)
    location /storage/v1 {
        proxy_pass http://$server_ip:54323\$request_uri;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        proxy_redirect off;
        
        # Upload limits
        client_max_body_size 5000M;
        proxy_connect_timeout       600;
        proxy_send_timeout          600;
        proxy_read_timeout          600;
        send_timeout                600;
    }

    # Image transformation
    location /functions/v1 {
        proxy_pass http://$server_ip:54321\$request_uri;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        proxy_redirect off;
    }

    # Catch-all for Studio
    location / {
        proxy_pass http://$server_ip:54323\$request_uri;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        proxy_redirect off;
    }
}
EOF

# Kích hoạt site
site_link="/etc/nginx/sites-enabled/supabase-$domain_name"
if [[ -L "$site_link" ]]; then
    sudo rm "$site_link"
fi
sudo ln -s "$config_file" "$site_link"

# Kiểm tra cấu hình Nginx
print_info "Đang kiểm tra cấu hình Nginx..."
if sudo nginx -t; then
    print_success "Cấu hình Nginx hợp lệ."
    
    # Restart Nginx
    print_info "Đang khởi động lại Nginx..."
    sudo systemctl restart nginx
    
    if sudo systemctl is-active --quiet nginx; then
        print_success "Nginx đã được khởi động lại thành công."
    else
        print_error "Nginx không khởi động được, kiểm tra lại cấu hình."
        exit 1
    fi
else
    print_error "Cấu hình Nginx không hợp lệ! Vui lòng kiểm tra lại."
    exit 1
fi

print_info ""
print_success "Cấu hình Nginx cho Supabase đã được thiết lập!"
print_info "Tên miền: $domain_name"
print_info "Tệp cấu hình: $config_file"
print_info ""
print_warning "LƯU Ý: Bạn cần cập nhật đường dẫn chứng chỉ SSL trong tệp cấu hình."
print_info "Để thiết lập SSL với Let's Encrypt, bạn có thể sử dụng Certbot:"
echo "  sudo apt install certbot python3-certbot-nginx"
echo "  sudo certbot --nginx -d $domain_name"
print_info ""
print_info "Sau khi có SSL, bạn cần chỉnh sửa tệp cấu hình để cập nhật đường dẫn chứng chỉ."