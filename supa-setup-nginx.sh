#!/bin/bash
# ==============================================
# SUPA-SETUP-NGINX.SH – Cài domain & SSL
# -------------------------------------------------
# Tự động kiểm tra quyền sudo, chờ lock apt,
# và xử lý xung đột cổng/domain.
# ==============================================

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

echo "======================================"
echo "  🌐 CÀI ĐẶT NGINX + HTTPS"
echo "======================================"

# Nhập và validate domain
read -p "Nhập domain của bạn: " DOMAIN
while ! validate_domain "$DOMAIN"; do
    read -p "Nhập lại domain: " DOMAIN
done

# Kiểm tra quyền sudo (cần cho tất cả thao tác bên dưới)
require_sudo_or_exit

# Kiểm tra xung đột cổng
PORT80=$(check_port 80)
PORT443=$(check_port 443)

if [[ "$PORT80" == DOCKER* ]] || [[ "$PORT443" == DOCKER* ]]; then
    echo -e "${YELLOW}⚠️ Phát hiện container Docker đang chiếm cổng 80/443.${NC}"
    docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Ports}}"
    read -p "Dừng container đó để cài Nginx mới? (y/n): " stop_ans
    if [ "$stop_ans" = "y" ]; then
        for cont in $(echo "$PORT80" "$PORT443" | grep -Po 'DOCKER\|\K[^|]+' | sort -u); do
            docker stop $cont && docker rm $cont
            echo "Đã dừng $cont"
        done
    else
        echo "Hủy bỏ."
        exit 0
    fi
elif [[ "$PORT80" != "FREE" ]] || [[ "$PORT443" != "FREE" ]]; then
    echo -e "${RED}Cổng 80/443 đang bị chiếm bởi tiến trình hệ thống, không thể tiếp tục.${NC}"
    exit 1
fi

# Cài đặt Nginx và Certbot nếu chưa có – chờ lock apt
if ! command -v nginx &> /dev/null || ! command -v certbot &> /dev/null; then
    echo "📦 Đang cài đặt Nginx và Certbot..."
    wait_for_apt_lock || exit 1
    sudo apt update
    command -v nginx &> /dev/null || sudo apt install -y nginx
    command -v certbot &> /dev/null || sudo apt install -y certbot python3-certbot-nginx
fi

# Kiểm tra xung đột domain
if check_nginx_domain_conflict "$DOMAIN"; then
    echo -e "${YELLOW}Domain $DOMAIN đã tồn tại trong cấu hình Nginx.${NC}"
    read -p "Ghi đè? (y/n): " overwrite
    if [ "$overwrite" = "y" ]; then
        for f in $(grep -rl "server_name $DOMAIN" /etc/nginx/sites-enabled/); do
            sudo rm "$f"
            echo "Đã vô hiệu $f"
        done
    else
        echo "Hủy bỏ."
        exit 0
    fi
fi

# Tạo file cấu hình với các header bảo mật cơ bản
sudo tee /etc/nginx/sites-available/supabase > /dev/null <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$server_name\$request_uri;
}
server {
    listen 443 ssl http2;
    server_name $DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;

    location / {
        proxy_pass http://localhost:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/supabase /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx

sudo certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m "admin@$DOMAIN" || echo "Certbot gặp lỗi, hãy kiểm tra lại domain."

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN} ✅ CÀI ĐẶT HOÀN TẤT!${NC}"
echo -e "${GREEN} 🌐 Truy cập: https://$DOMAIN${NC}"
echo -e "${GREEN}========================================${NC}"