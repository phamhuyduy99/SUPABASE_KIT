#!/bin/bash
# ==============================================
# SUPA-MENU.SH – Giao diện menu chính
# -------------------------------------------------
# Tự động tìm thư mục dự án, quét trạng thái,
# hiển thị menu và gọi các script chức năng.
# ==============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Nạp thư viện chung
source common.sh

# Cấp quyền thực thi cho các script nếu chưa
auto_chmod_sh

# Xác định thư mục dự án Supabase (nơi có .env và docker-compose.yml)
PROJECT_DIR=$(auto_find_supabase_dir "$SCRIPT_DIR")
if [ -z "$PROJECT_DIR" ]; then
    echo -e "${YELLOW}Không tìm thấy file .env và docker-compose.yml tự động.${NC}"
    PROJECT_DIR=$(input_supabase_dir)
fi

# Quét và hiển thị trạng thái các chức năng trước khi vào menu
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
        1) bash supa-freeze.sh "$PROJECT_DIR" ;;
		2) bash supa-restore.sh ;;
        3) bash supa-setup-nginx.sh ;;
        4) bash supa-status.sh ;;
        5) bash supa-freeze.sh --cron "$PROJECT_DIR" ;;
        6) bash supa-setup-gdrive.sh ;;
        0) echo "Tạm biệt!"; exit 0 ;;
        *) echo -e "${RED}Lựa chọn không hợp lệ.${NC}"; sleep 1 ;;
    esac
    echo ""
    read -p "Nhấn Enter để tiếp tục..." dummy
done