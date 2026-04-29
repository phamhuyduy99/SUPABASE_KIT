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
            echo -e "${YELLOW}Không tìm thấy file .env và docker-compose.yml tự động.${NC}"
            PROJECT_DIR=$(input_supabase_dir)
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
        1)
            # Backup cần thư mục dự án hiện tại
            ensure_project_dir
            bash supa-freeze.sh "$PROJECT_DIR"
            ;;
        2)
            # Restore không cần thư mục dự án, script tự xử lý
            bash supa-restore.sh
            ;;
        3)
            bash supa-setup-nginx.sh
            ;;
        4)
            bash supa-status.sh
            ;;
        5)
            # Cài cron backup cũng cần thư mục dự án
            ensure_project_dir
            setup_auto_backup
            ;;
        6)
            bash supa-setup-gdrive.sh
            ;;
        0)
            echo "Tạm biệt!"
            exit 0
            ;;
        *)
            echo -e "${RED}Lựa chọn không hợp lệ.${NC}"
            sleep 1
            ;;
    esac
    echo ""
    read -p "Nhấn Enter để tiếp tục..." dummy
done