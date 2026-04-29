#!/bin/bash
# ==============================================
# SUPA-SETUP-GDRIVE.SH – Cấu hình Google Drive cho rclone
# -------------------------------------------------
# Hỗ trợ kiểm tra kết nối hiện tại, làm mới token
# nếu đã tồn tại remote nhưng không hoạt động.
# CHO PHÉP ĐỔI TÀI KHOẢN: nếu remote đã có, hỏi người dùng
# có muốn cấu hình lại (ghi đè) không.
# ==============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

echo "======================================"
echo "  🔧 CẤU HÌNH GOOGLE DRIVE (RCLONE)"
echo "======================================"
echo ""
echo "Quá trình này cần bạn có một tài khoản Google và một máy tính có trình duyệt web."
echo "Bạn có thể thay đổi tài khoản bất cứ lúc nào bằng cách chạy lại chức năng này."
echo ""

# Kiểm tra rclone đã cài chưa (nếu chưa sẽ được cài tự động nếu có sudo)
if ! command -v rclone &> /dev/null; then
    ensure_rclone_gdrive || exit 1
fi

# ------------------------------------------------------------
# KIỂM TRA REMOTE GDRIVE ĐÃ TỒN TẠI CHƯA
# ------------------------------------------------------------
RECONFIGURE="n"
if rclone listremotes | grep -q "^gdrive:"; then
    echo -e "${GREEN}✅ Remote 'gdrive' hiện đã được cấu hình.${NC}"
    echo ""
    # Kiểm tra kết nối hiện tại
    if check_gdrive_connection; then
        echo -e "${GREEN}   Kết nối hiện tại đang hoạt động tốt.${NC}"
    else
        echo -e "${YELLOW}   Kết nối hiện tại không hoạt động (có thể token hết hạn).${NC}"
    fi
    echo ""
    echo "Bạn có muốn:"
    echo "  1. Giữ nguyên cấu hình hiện tại"
    echo "  2. Làm mới token (nếu kết nối hỏng)"
    echo "  3. Đổi sang tài khoản Google Drive khác (cấu hình lại từ đầu)"
    read -p "👉 Nhập lựa chọn (1/2/3): " reconfigure_choice

    case $reconfigure_choice in
        2)
            echo "🔄 Đang làm mới token..."
            suggest_gdrive_reconnect && exit 0 || exit 1
            ;;
        3)
            RECONFIGURE="y"
            echo "🔧 Sẽ xóa cấu hình cũ và tạo mới..."
            # Xóa remote gdrive khỏi config
            rclone config delete gdrive --non-interactive 2>/dev/null || true
            # Xóa cả section trong file config nếu còn sót
            sed -i '/^\[gdrive\]/,/^$/d' ~/.config/rclone/rclone.conf 2>/dev/null || true
            ;;
        *)
            echo "Giữ nguyên cấu hình hiện tại."
            exit 0
            ;;
    esac
fi

# ------------------------------------------------------------
# BẮT ĐẦU CẤU HÌNH MỚI
# ------------------------------------------------------------
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

    # Ghi file cấu hình rclone tạm thời một cách an toàn
    cat > /tmp/rclone_gdrive.conf <<'EOF'
[gdrive]
type = drive
scope = drive
EOF
    printf 'token = %s\n' "$token" >> /tmp/rclone_gdrive.conf

    echo -e "\n🔍 Đang xác thực token với Google Drive. Vui lòng đợi trong giây lát..."
    if rclone --config /tmp/rclone_gdrive.conf lsd gdrive: >/dev/null 2>&1; then
        mkdir -p ~/.config/rclone
        cat /tmp/rclone_gdrive.conf >> ~/.config/rclone/rclone.conf
        chmod 600 ~/.config/rclone/rclone.conf
        rm /tmp/rclone_gdrive.conf
        echo -e "${GREEN}✅ Cấu hình Google Drive thành công!${NC}"
        return 0
    else
        echo -e "${RED}❌ Token không hợp lệ hoặc đã hết hạn. Vui lòng thử lại.${NC}"
        echo "   Lưu ý: Bạn phải copy TOÀN BỘ đoạn JSON (bao gồm cả dấu { }),"
        echo "   và đảm bảo token vừa được tạo trong vòng 1 giờ."
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

# Đảm bảo thư mục supabase-backups tồn tại trên Drive mới
rclone mkdir gdrive:supabase-backups 2>/dev/null || true

echo ""
echo "🎉 Từ bây giờ bạn có thể chọn upload backup lên Google Drive khi Đóng băng hệ thống."
echo "   File backup sẽ được lưu trong thư mục 'supabase-backups' trên Google Drive của bạn."
echo "   Để khôi phục từ file đó, hãy dùng chức năng Restore trong menu và nhập:"
echo "   gdrive:supabase-backups/tên-file-backup.tar.gz"