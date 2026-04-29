#!/bin/bash
# ==============================================
# SUPA-RESTORE.SH – Khôi phục Supabase từ backup
# -------------------------------------------------
# Hỗ trợ VPS trắng: không cần cài Supabase trước.
# Tự động cài Docker, tạo thư mục, khởi động và import.
# ==============================================

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

echo "======================================"
echo "  ♻️  KHÔI PHỤC HỆ THỐNG SUPABASE"
echo "======================================"

# -------------------------------------------------
# 1. Nhập file backup (local, URL, hoặc Google Drive)
# -------------------------------------------------
while true; do
    read -p "Đường dẫn file backup (.tar.gz), URL, hoặc remote rclone: " SRC
    if [[ "$SRC" =~ ^gdrive: ]]; then
        if ! command -v rclone &> /dev/null; then
            echo -e "${RED}rclone chưa cài đặt. Không thể tải từ Google Drive.${NC}"
            exit 1
        fi
        LOCAL_FILE="/tmp/restore-backup.tar.gz"
        download_from_gdrive "$SRC" "$LOCAL_FILE" || continue
        BACKUP_FILE="$LOCAL_FILE"
        break
    elif [[ "$SRC" =~ ^https?:// ]]; then
        echo "📥 Đang tải từ URL..."
        wget -O /tmp/restore-backup.tar.gz "$SRC" && BACKUP_FILE="/tmp/restore-backup.tar.gz" && break
        echo -e "${RED}Tải thất bại. Kiểm tra URL.${NC}"
    else
        if validate_backup_file "$SRC"; then
            BACKUP_FILE="$SRC"
            break
        fi
    fi
done

# -------------------------------------------------
# 2. Nhập domain (tùy chọn)
# -------------------------------------------------
read -p "Domain (Enter nếu không có): " DOMAIN
if [ -n "$DOMAIN" ]; then
    while ! validate_domain "$DOMAIN"; do
        read -p "Nhập lại domain: " DOMAIN
    done
fi

# -------------------------------------------------
# 3. Xác định thư mục cài đặt (KHÔNG cần .env sẵn)
# -------------------------------------------------
read -p "Thư mục cài Supabase (mặc định /opt/supabase-restored): " TARGET_DIR
TARGET_DIR="${TARGET_DIR:-/opt/supabase-restored}"
echo "📁 Thư mục cài đặt: $TARGET_DIR"
mkdir -p "$TARGET_DIR"
cd "$TARGET_DIR"

# -------------------------------------------------
# 4. Giải nén backup
# -------------------------------------------------
echo "📦 Giải nén backup..."
tar xzf "$BACKUP_FILE" -C "$TARGET_DIR" || { echo -e "${RED}Lỗi giải nén. File backup có thể bị hỏng.${NC}"; exit 1; }

# -------------------------------------------------
# 5. Copy cấu hình từ backup vào thư mục gốc
# -------------------------------------------------
if [ -f config/.env ] && [ -f config/docker-compose.yml ]; then
    cp config/.env .
    cp config/docker-compose.yml .
    [ -d config/volumes ] && cp -r config/volumes .
    echo "✅ Đã thiết lập cấu hình Supabase từ backup."
else
    echo -e "${RED}File backup thiếu .env hoặc docker-compose.yml. Không thể tiếp tục.${NC}"
    exit 1
fi

# -------------------------------------------------
# 6. Cài Docker nếu chưa có
# -------------------------------------------------
if ! command -v docker &> /dev/null; then
    echo "⚙️ Docker chưa được cài đặt."
    require_sudo_or_exit   # Thoát nếu không có sudo và in hướng dẫn
    wait_for_apt_lock || exit 1
    sudo apt update && sudo apt install -y docker.io docker-compose-v2
    sudo systemctl enable --now docker
    # Sau khi cài, thêm user vào nhóm docker nếu cần
    if ! groups $REAL_USER | grep -q docker; then
        echo -e "${YELLOW}⚠️ Lưu ý: Bạn cần thêm user '$REAL_USER' vào group docker để dùng Docker không cần sudo.${NC}"
        echo "   Hãy chạy: sudo usermod -aG docker $REAL_USER"
        echo "   Sau đó đăng xuất và đăng nhập lại."
    fi
fi

# -------------------------------------------------
# 7. Khởi động Supabase
# -------------------------------------------------
echo "🚀 Khởi động Supabase..."
docker compose up -d
echo "⏳ Chờ database sẵn sàng (30 giây)..."
sleep 30

# -------------------------------------------------
# 8. Import database
# -------------------------------------------------
DB_CONT=$(docker ps --format '{{.Names}}' | grep -E 'supabase.*db|db' | head -1)
if [ -z "$DB_CONT" ]; then
    echo -e "${RED}Không tìm thấy container database sau khi khởi động.${NC}"
    exit 1
fi
echo "🗄️ Import database..."
gunzip -c database/full_backup.sql.gz > /tmp/restore.sql
docker cp /tmp/restore.sql $DB_CONT:/tmp/
docker exec -t $DB_CONT psql -U postgres -f /tmp/restore.sql || {
    echo -e "${RED}Có lỗi khi import database. Kiểm tra file backup.${NC}"
    rm /tmp/restore.sql
    exit 1
}
rm /tmp/restore.sql
echo "✅ Database đã được phục hồi."

# -------------------------------------------------
# 9. Import storage
# -------------------------------------------------
if [ -f storage/storage.tar.gz ]; then
    echo "📂 Import storage..."
    STORAGE_VOL=$(docker volume ls -q | grep _storage)
    if [ -n "$STORAGE_VOL" ]; then
        docker run --rm -v $STORAGE_VOL:/mnt/storage -v "$TARGET_DIR/storage:/backup:ro" alpine \
            sh -c "cd /mnt/storage && tar xzf /backup/storage.tar.gz"
    else
        # Nếu dùng bind mount, thư mục volumes/storage đã được copy từ backup
        [ -d volumes/storage ] && tar xzf storage/storage.tar.gz -C volumes/storage
    fi
    echo "✅ Storage đã được phục hồi."
else
    echo "ℹ️ Không có dữ liệu storage để phục hồi."
fi

# -------------------------------------------------
# 10. Cài Nginx nếu có domain
# -------------------------------------------------
if [ -n "$DOMAIN" ]; then
    echo "🌐 Cài đặt Nginx và HTTPS..."
    # Kiểm tra cổng (giữ nguyên logic cũ, có kiểm tra sudo và xung đột)
    PORT80=$(check_port 80)
    PORT443=$(check_port 443)
    if [[ "$PORT80" == DOCKER* ]] || [[ "$PORT443" == DOCKER* ]]; then
        echo -e "${YELLOW}Phát hiện container Docker đang chiếm cổng 80/443.${NC}"
        read -p "Dừng container để cài Nginx? (y/n): " stop_ans
        if [ "$stop_ans" = "y" ]; then
            for cont in $(echo "$PORT80" "$PORT443" | grep -Po 'DOCKER\|\K[^|]+' | sort -u); do
                docker stop $cont && docker rm $cont
            done
        else
            echo "Bỏ qua cài Nginx."
        fi
    elif [[ "$PORT80" != "FREE" ]] || [[ "$PORT443" != "FREE" ]]; then
        echo -e "${RED}Cổng 80/443 đã bị chiếm bởi tiến trình hệ thống, không thể cài Nginx.${NC}"
    else
        # Cài Nginx nếu cần
        local need_nginx=0
        local need_certbot=0
        command -v nginx &> /dev/null || need_nginx=1
        command -v certbot &> /dev/null || need_certbot=1
        if [ $need_nginx -eq 1 ] || [ $need_certbot -eq 1 ]; then
            require_sudo_or_exit
            wait_for_apt_lock || exit 1
            sudo apt update
            [ $need_nginx -eq 1 ] && sudo apt install -y nginx
            [ $need_certbot -eq 1 ] && sudo apt install -y certbot python3-certbot-nginx
        fi

        if check_nginx_domain_conflict "$DOMAIN"; then
            echo -e "${YELLOW}Domain $DOMAIN đã có trong cấu hình Nginx.${NC}"
            read -p "Ghi đè? (y/n): " overwrite
            if [ "$overwrite" = "y" ]; then
                for f in $(grep -rl "server_name $DOMAIN" /etc/nginx/sites-enabled/); do sudo rm "$f"; done
            else
                echo "Bỏ qua Nginx."
            fi
        fi
        if [ "$overwrite" != "n" ]; then
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
        fi
    fi
fi

# -------------------------------------------------
# 11. Khởi động lại toàn bộ và hiển thị thông tin
# -------------------------------------------------
echo "🔄 Khởi động lại Supabase lần cuối..."
docker compose restart

IP=$(hostname -I | awk '{print $1}')
echo -e "${GREEN}=============================================${NC}"
echo -e "${GREEN}  🎉 KHÔI PHỤC HOÀN TẤT!${NC}"
echo -e "${GREEN}=============================================${NC}"
if [ -f .env ]; then
    STUDIO_URL="http://${IP}:8000"
    [ -n "$DOMAIN" ] && STUDIO_URL="https://${DOMAIN}"
    echo "🌐 Studio URL: $STUDIO_URL"
    USERNAME=$(grep -E '^DASHBOARD_USERNAME=' .env | cut -d '=' -f2)
    PASS=$(grep -E '^DASHBOARD_PASSWORD=' .env | cut -d '=' -f2)
    echo "👤 Tên đăng nhập: ${USERNAME:-Chưa có}"
    echo "🔑 Mật khẩu: ${PASS:-Chưa có}"
else
    echo "Không tìm thấy file .env, hãy kiểm tra thông tin đăng nhập."
fi
echo -e "${GREEN}=============================================${NC}"