#!/bin/bash
# ==============================================
# SUPA-SETUP-GDRIVE.SH – Cấu hình Google Drive cho rclone
# -------------------------------------------------
# Hỗ trợ kiểm tra kết nối hiện tại, làm mới token
# nếu đã tồn tại remote nhưng không hoạt động.
# Hướng dẫn copy token chi tiết, tránh nhầm lẫn.
# ==============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

echo "======================================"
echo "  🔧 CẤU HÌNH GOOGLE DRIVE (RCLONE)"
echo "======================================"
echo ""
echo "Quá trình này cần bạn có một tài khoản Google và một máy tính có trình duyệt web."
echo "Bạn chỉ cần làm MỘT LẦN duy nhất."
echo ""

# Kiểm tra rclone đã cài chưa
if ! command -v rclone &> /dev/null; then
    echo -e "${YELLOW}rclone chưa cài đặt. Đang tiến hành cài...${NC}"
    ensure_rclone_gdrive || exit 1
fi

# Kiểm tra xem remote gdrive đã tồn tại chưa
if rclone listremotes | grep -q "^gdrive:"; then
    if check_gdrive_connection; then
        echo -e "${GREEN}✅ Remote 'gdrive' đã được cấu hình và hoạt động tốt.${NC}"
        exit 0
    else
        echo -e "${YELLOW}⚠️ Remote 'gdrive' đã tồn tại nhưng không kết nối được. Có thể token đã hết hạn.${NC}"
        read -p "Bạn có muốn chạy 'rclone config reconnect gdrive:' để làm mới token không? (y/n): " reconnect_choice
        if [ "$reconnect_choice" = "y" ]; then
            rclone config reconnect gdrive:
            if check_gdrive_connection; then
                echo -e "${GREEN}✅ Token đã được làm mới thành công.${NC}"
                exit 0
            else
                echo -e "${RED}❌ Vẫn không thành công. Bạn có thể cần cấu hình lại từ đầu.${NC}"
            fi
        fi
    fi
fi

# Nếu chưa, bắt đầu cấu hình mới
echo "📌 Bây giờ chúng ta sẽ tạo kết nối đến Google Drive."
echo ""
echo "1. Trên máy tính cá nhân của bạn (Windows/Mac/Linux), hãy tải rclone từ:"
echo "   https://rclone.org/downloads/"
echo "   Sau đó giải nén và mở terminal (CMD/Terminal) tại thư mục chứa rclone.exe (hoặc rclone)."
echo ""
echo "2. Chạy lệnh sau trên máy cá nhân:"
echo "   rclone authorize \"drive\""
echo ""
echo "   Trình duyệt sẽ mở ra, yêu cầu bạn đăng nhập Google và cấp quyền."
echo "   Sau khi cho phép, terminal sẽ hiện ra một đoạn JSON (bắt đầu bằng dấu { )."
echo "   Hãy COPY TOÀN BỘ đoạn JSON đó, BAO GỒM CẢ DẤU NGOẶC NHỌN { }."
echo "   Ví dụ: {\"access_token\":\"...\",\"token_type\":\"Bearer\",\"refresh_token\":\"...\",\"expiry\":\"...\"}"
echo ""
echo "3. Quay lại đây và DÁN TOÀN BỘ đoạn JSON vào khi được yêu cầu, sau đó nhấn Enter."
echo ""

# Hàm tạo remote từ token người dùng cung cấp
configure_gdrive_with_token() {
    read -p "👉 Dán đoạn JSON token của bạn vào đây: " token
    if [ -z "$token" ]; then
        echo -e "${RED}Token không được để trống.${NC}"
        return 1
    fi

    cat > /tmp/rclone_gdrive.conf <<EOF
[gdrive]
type = drive
scope = drive
token = $token
EOF

    # Thông báo rõ ràng trước khi xác thực
    echo -e "\n🔍 Đang xác thực token với Google Drive. Vui lòng đợi trong giây lát..."
    if rclone --config /tmp/rclone_gdrive.conf lsd gdrive: >/dev/null 2>&1; then
        mkdir -p ~/.config/rclone
        cat /tmp/rclone_gdrive.conf >> ~/.config/rclone/rclone.conf
        chmod 600 ~/.config/rclone/rclone.conf  # Bảo vệ token
        rm /tmp/rclone_gdrive.conf
        echo -e "${GREEN}✅ Cấu hình Google Drive thành công!${NC}"
        return 0
    else
        echo -e "${RED}❌ Token không hợp lệ hoặc đã hết hạn. Vui lòng thử lại.${NC}"
        rm /tmp/rclone_gdrive.conf
        return 1
    fi
}

# Cho phép thử lại nếu token sai
while true; do
    if configure_gdrive_with_token; then
        break
    else
        read -p "Bạn có muốn thử lại không? (y/n): " retry
        if [ "$retry" != "y" ]; then
            echo "Đã hủy cấu hình Google Drive."
            exit 1
        fi
    fi
done

echo ""
echo "🎉 Từ bây giờ bạn có thể chọn upload backup lên Google Drive khi Đóng băng hệ thống."
echo "   File backup sẽ được lưu trong thư mục 'supabase-backups' trên Google Drive của bạn."
echo "   Để khôi phục từ file đó, hãy dùng chức năng Restore trong menu và nhập:"
echo "   gdrive:supabase-backups/tên-file-backup.tar.gz"