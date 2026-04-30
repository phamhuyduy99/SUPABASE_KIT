supa-menu.sh
#!/bin/bash
# ==============================================
# SUPA-MENU.SH – Giao diện menu chính
# -------------------------------------------------
# Tự động tìm thư mục dự án (chỉ khi cần Freeze),
# quét trạng thái, hiển thị menu và gọi các script chức năng.
# Không yêu cầu thư mục dự án khi Restore.
# ==============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Nạp thư viện chung
source common.sh

# Cấp quyền thực thi cho các script nếu chưa
auto_chmod_sh

# Biến PROJECT_DIR sẽ được xác định khi cần (freeze/cron), ban đầu để trống.
PROJECT_DIR=""

# Hàm xác định thư mục dự án (chỉ gọi khi cần)
# Nếu PROJECT_DIR chưa có, tự động dò tìm hoặc yêu cầu người dùng nhập
ensure_project_dir() {
    if [ -z "$PROJECT_DIR" ]; then
        PROJECT_DIR=$(auto_find_supabase_dir "$SCRIPT_DIR")
        if [ -z "$PROJECT_DIR" ]; then
            # Nếu không tìm thấy, kiểm tra có phải gói backup tự hành không (backup_data/config có sẵn)
            if [ -f "$SCRIPT_DIR/backup_data/config/.env" ] && [ -f "$SCRIPT_DIR/backup_data/config/docker-compose.yml" ]; then
                echo -e "${YELLOW}📦 Phát hiện gói backup tự hành. Đang thiết lập cấu hình...${NC}"
                cp "$SCRIPT_DIR/backup_data/config/.env" "$SCRIPT_DIR/"
                cp "$SCRIPT_DIR/backup_data/config/docker-compose.yml" "$SCRIPT_DIR/"
                PROJECT_DIR="$SCRIPT_DIR"
                echo -e "${GREEN}✅ Đã sẵn sàng. Bạn có thể tiếp tục sử dụng các chức năng.${NC}"
            else
                echo -e "${YELLOW}Không tìm thấy file .env và docker-compose.yml tự động.${NC}"
                PROJECT_DIR=$(input_supabase_dir)
            fi
        fi
    fi
}

# Hàm thiết lập backup tự động
setup_auto_backup() {
    SCRIPT_PATH="$SCRIPT_DIR/supa-freeze.sh"
    CRON_LINE="0 2 * * * bash $SCRIPT_PATH --cron $PROJECT_DIR >> /var/log/supabase-backup.log 2>&1"
    (crontab -l 2>/dev/null; echo "$CRON_LINE") | sort -u | crontab -
    echo -e "${GREEN}✅ Đã thiết lập backup tự động lúc 2h sáng mỗi ngày.${NC}"
    echo "📋 Xem log tại: /var/log/supabase-backup.log"
}

# Quét và hiển thị trạng thái các chức năng trước khi vào menu (không cần PROJECT_DIR)
scan_features_status

# Cảnh báo về quyền sudo (sử dụng REAL_USER đã có trong common.sh)
if ! sudo -n true 2>/dev/null; then
    echo -e "${YELLOW}⚠️ Bạn không có quyền sudo. Một số chức năng (cài HTTPS, cài Docker) sẽ không hoạt động.${NC}"
    echo "   Để dùng đầy đủ, hãy chạy 'sudo bash supa-start.sh' hoặc nhờ quản trị cấp quyền:"
    echo "   sudo usermod -aG sudo $REAL_USER"
    read -p "Nhấn Enter để tiếp tục với quyền hạn chế..." dummy
fi

# Vòng lặp menu chính
while true; do
    clear
    echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║   SUPABASE QUẢN TRỊ TỰ ĐỘNG v3.0         ║${NC}"
    echo -e "${GREEN}╠══════════════════════════════════════════╣${NC}"
    echo -e "║ 1. 🧊 Đóng băng hệ thống (Backup)        ║"
    echo -e "║ 2. ♻️  Khôi phục hệ thống (Restore)      ║"
    echo -e "║ 3. 🌐 Cài HTTPS & domain                 ║"
    echo -e "║ 4. 📊 Kiểm tra trạng thái                ║"
    echo -e "║ 5. ⏰ Thiết lập tự động backup            ║"
    echo -e "║ 6. 🔧 Cấu hình Google Drive              ║"
    echo -e "║ 0. 🚪 Thoát                              ║"
    echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
    echo -ne "👉 Nhập lựa chọn: "
    read choice
    case $choice in
        1) log_info "Người dùng chọn: Đóng băng hệ thống"
           bash supa-freeze.sh "$PROJECT_DIR" ;;
        2) log_info "Người dùng chọn: Khôi phục hệ thống"
           bash supa-restore.sh ;;
        3) log_info "Người dùng chọn: Cài HTTPS & domain"
           bash supa-setup-nginx.sh ;;
        4) log_info "Người dùng chọn: Kiểm tra trạng thái"
           bash supa-status.sh ;;
        5) log_info "Người dùng chọn: Thiết lập tự động backup"
           setup_auto_backup ;;
        6) log_info "Người dùng chọn: Cấu hình Google Drive"
           bash supa-setup-gdrive.sh ;;
        0) log_info "Người dùng thoát menu"
           echo "Tạm biệt!"
           exit 0
           ;;
        *) log_warn "Người dùng nhập lựa chọn không hợp lệ: $choice"
           echo -e "${RED}Lựa chọn không hợp lệ.${NC}"
           sleep 1
           ;;
    esac
    echo ""
    read -p "Nhấn Enter để tiếp tục..." dummy
done