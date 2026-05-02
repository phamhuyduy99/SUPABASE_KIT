#!/bin/bash
# ==============================================
# SUPA-START.SH – Điểm vào duy nhất cho người dùng
# -------------------------------------------------
# Sửa lỗi xuống dòng Windows, kiểm tra môi trường
# (OS, mạng), và khởi chạy menu.
# Khi không có sudo, hiển thị trạng thái và gợi ý.
# ==============================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Nạp thư viện chung (chứa tất cả hàm dùng chung)
source common.sh

echo -e "${BOLD_CYAN}🔧 Sửa lỗi định dạng file (CRLF -> LF)...${NC}"
sed -i 's/\r$//' *.sh 2>/dev/null

# Lấy tên người dùng thực (ưu tiên SUDO_USER khi chạy sudo)
if [ -n "$SUDO_USER" ]; then
    CURRENT_USER="$SUDO_USER"
else
    CURRENT_USER="${USER:-$(whoami)}"
fi

log_info "Khởi động Supabase Kit bởi $CURRENT_USER"
echo -e "${BOLD_BLUE}🚀 Khởi động Supabase Kit..."

# ===== KIỂM TRA MÔI TRƯỜNG CƠ BẢN =====
echo -e "${BOLD_CYAN}🔍 Đang kiểm tra môi trường...${NC}"
# Kiểm tra phiên bản OS
if ! check_os_version; then
    exit 1
fi
# Kiểm tra kết nối mạng
if ! check_network; then
    exit 1
fi

# Nếu có quyền sudo, chạy thẳng menu (với sudo để giữ quyền)
if sudo -n true 2>/dev/null; then
    echo "✅ Bạn có quyền sudo. Đang vào menu..."
    sudo bash supa-menu.sh
else
    echo -e "${BOLD_YELLOW}⚠️ Bạn đang chạy script mà không có quyền sudo.${NC}"
    echo "   Một số chức năng quan trọng sẽ không hoạt động:"
    echo "   - Cài đặt Docker, Nginx, Certbot"
    echo "   - Đồng bộ backup sang VPS khác"
    echo "   - Thiết lập cron job tự động"
    echo ""
    echo "Bạn có hai lựa chọn:"
    echo "1. Tiếp tục vào menu (các chức năng không cần sudo vẫn dùng được)."
    echo "2. Thoát và yêu cầu quản trị cấp quyền sudo."
    echo ""
    echo "📌 Để được cấp quyền sudo, nhờ người có quyền root chạy:"
    echo "   sudo usermod -aG sudo $CURRENT_USER"
    echo "   Sau đó đăng xuất và đăng nhập lại."
    echo ""
    read -p "👉 Bạn muốn tiếp tục không? (y/n): " continue_choice
    if [ "$continue_choice" = "y" ]; then
        bash supa-menu.sh
    else
        echo -e "${BOLD_GREEN}Tạm biệt.${NC}"
        exit 0
    fi
fi