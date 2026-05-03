#!/bin/bash
# ==============================================
# ENHANCED-FEATURES-GUIDE.SH – Hướng dẫn các tính năng nâng cao
# -------------------------------------------------
# Script này giải thích các tính năng nâng cao của 
# Supabase Kit như 25 chiến lược xử lý sysctl,
# 10 phương pháp import database, và các tính năng khác.
# ==============================================

# ANSI Color Codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local color=$1
    local msg=$2
    echo -e "${color}${msg}${NC}"
}

print_title() {
    echo ""
    print_status $PURPLE "=================================================="
    print_status $PURPLE "       HƯỚNG DẪN CÁC TÍNH NĂNG NÂNG CAO"
    print_status $PURPLE "         SUPABASE KIT TOÀN DIỆN"
    print_status $PURPLE "=================================================="
}

print_section() {
    echo ""
    print_status $CYAN "###############################################################################"
    print_status $CYAN "# $1"
    print_status $CYAN "###############################################################################"
}

print_feature() {
    local num=$1
    local name=$2
    local desc=$3
    print_status $YELLOW "🔹 $num. $name"
    print_status $WHITE "   $desc"
}

print_note() {
    local note=$1
    print_status $GREEN "💡 $note"
}

# Main function
main() {
    print_title
    
    print_status $WHITE "Supabase Kit không chỉ là một bộ công cụ đơn thuần mà là một hệ sinh thái hoàn chỉnh"
    print_status $WHITE "với các tính năng nâng cao giúp người dùng xử lý các tình huống phức tạp một cách dễ dàng."
    echo ""
    
    print_section "I. 25 CHIẾN LƯỢC XỬ LÝ LỖI SYSCTL (CHO VPS LXC/OpenVZ)"
    
    print_feature "1" "Xóa dòng sysctl" "Tự động xóa các dòng liên quan đến ip_unprivileged_port_start khỏi docker-compose.yml"
    print_feature "2" "Thêm privileged: true" "Thêm quyền privileged cho các container như vector, imgproxy, db"
    print_feature "3" "Thêm security_opt và cap_add" "Thêm cấu hình bảo mật để container có quyền truy cập đặc biệt"
    print_feature "4" "Cấu hình Docker daemon" "Cấu hình daemon.json để tăng giới hạn kết nối"
    print_feature "5" "Hạ cấp containerd" "Hạ cấp phiên bản containerd nếu gặp vấn đề tương thích"
    print_feature "6" "Đổi tag image" "Thử sử dụng các phiên bản image cũ hơn để tăng tính tương thích"
    print_feature "7" "Runtime khác" "Hướng dẫn sử dụng các runtime khác như sysbox-runc"
    print_feature "8" "Tắt AppArmor/SELinux" "Tạm thời tắt các cơ chế bảo mật hạn chế quyền container"
    print_feature "9" "Yêu cầu nhà cung cấp bật nesting" "Hướng dẫn yêu cầu nhà cung cấp VPS bật tính năng hỗ trợ container"
    print_feature "10" "Chuyển sang VPS KVM" "Khuyến nghị sử dụng VPS với công nghệ ảo hóa KVM tương thích hoàn toàn"
    print_feature "11" "Thêm sysctls thủ công" "Thêm cấu hình sysctl theo cách tương thích hơn"
    print_feature "12" "Biến môi trường bỏ qua sysctl" "Sử dụng biến môi trường để bỏ qua lỗi sysctl"
    print_feature "13" "Khởi động riêng từng service" "Khởi động từng dịch vụ riêng biệt thay vì toàn bộ hệ thống"
    print_feature "14" "Dọn dẹp volumes/networks" "Xóa toàn bộ volumes và networks cũ để tránh xung đột"
    print_feature "15" "Docker Compose V1" "Thử sử dụng phiên bản Docker Compose V1 nếu V2 gặp lỗi"
    print_feature "16" "Khởi động với --compatibility" "Sử dụng cờ tương thích để tăng khả năng tương thích"
    print_feature "17" "Cập nhật Docker" "Cập nhật Docker lên phiên bản mới nhất"
    print_feature "18" "Khởi động lại dịch vụ Docker" "Khởi động lại hoàn toàn dịch vụ Docker"
    print_feature "19" "File docker-compose tối thiểu" "Tạo và sử dụng file compose tối thiểu chỉ chứa các dịch vụ cần thiết"
    print_feature "20" "Đề xuất Supabase Cloud" "Đề xuất chuyển sang phiên bản cloud nếu VPS không tương thích"
    print_feature "21" "Vô hiệu hóa toàn bộ sysctl" "Loại bỏ hoàn toàn các cấu hình sysctl gây lỗi"
    print_feature "22" "Khởi động với --no-deps --no-healthcheck" "Khởi động mà không kiểm tra phụ thuộc và healthcheck"
    print_feature "23" "Docker run trực tiếp" "Sử dụng lệnh docker run trực tiếp thay vì docker-compose"
    print_feature "24" "Sửa AppArmor profile" "Hướng dẫn sửa profile AppArmor để cho phép container hoạt động"
    print_feature "25" "Docker trong Docker hoặc VM" "Sử dụng Docker trong Docker hoặc máy ảo KVM bên trong VPS hiện tại"
    
    echo ""
    print_note "Tất cả 25 chiến lược này được thực hiện tự động trong Supabase Kit khi gặp lỗi sysctl!"
    
    print_section "II. 10 PHƯƠNG PHÁP IMPORT DATABASE"
    
    print_feature "1" "Import trực tiếp từ SQL dump" "Sử dụng psql để import trực tiếp file SQL dump"
    print_feature "2" "Import từng phần" "Chia nhỏ file SQL và import từng phần để tránh lỗi bộ nhớ"
    print_feature "3" "Sử dụng pg_restore" "Sử dụng công cụ chuyên dụng pg_restore nếu có"
    print_feature "4" "Import từng schema riêng biệt" "Phân tích và import từng schema riêng biệt để dễ kiểm soát"
    print_feature "5" "Tối ưu tùy chọn import" "Sử dụng các tùy chọn tối ưu để tăng tốc độ import"
    print_feature "6" "Import thủ công với hướng dẫn" "Cung cấp hướng dẫn chi tiết để người dùng import thủ công"
    print_feature "7" "Phân tích lỗi và đề xuất" "Phân tích lỗi cụ thể và đề xuất phương pháp thay thế phù hợp"
    print_feature "8" "Công cụ chuyên dụng" "Hướng dẫn sử dụng các công cụ chuyên dụng cho database lớn"
    print_feature "9" "Kiểm tra tính toàn vẹn sau import" "Kiểm tra dữ liệu sau khi import để đảm bảo chính xác"
    print_feature "10" "Ghi log chi tiết" "Ghi lại toàn bộ quá trình import để dễ dàng debug nếu có lỗi"
    
    echo ""
    print_note "Supabase Kit sẽ thử lần lượt các phương pháp này cho đến khi thành công!"
    
    print_section "III. TÍNH NĂNG ĐẶC BIỆT KHÁC"
    
    print_feature "A" "Tự động phát hiện hệ điều hành" "Tự động xác định hệ điều hành và cung cấp giao diện phù hợp"
    print_feature "B" "Tích hợp Google Drive" "Hỗ trợ backup và restore từ Google Drive thông qua rclone"
    print_feature "C" "Tự động hóa backup định kỳ" "Hỗ trợ thiết lập lịch backup tự động hàng ngày"
    print_feature "D" "Đồng bộ SSH sang VPS dự phòng" "Hỗ trợ đồng bộ file backup sang VPS dự phòng"
    print_feature "E" "Tạo checksum SHA256" "Tự động tạo file checksum để kiểm tra tính toàn vẹn dữ liệu"
    print_feature "F" "Giao diện người dùng màu sắc" "Giao diện trực quan với màu sắc giúp dễ sử dụng"
    print_feature "G" "Hỗ trợ đa nền tảng" "Hoạt động trên Linux, Windows và macOS với chức năng tương đương"
    print_feature "H" "Tự động kiểm tra môi trường" "Tự động kiểm tra hệ thống trước khi thực hiện tác vụ"
    print_feature "I" "Cấu hình HTTPS & domain" "Tự động cấu hình Nginx và cấp chứng chỉ SSL"
    print_feature "J" "Xử lý lỗi thông minh" "Cung cấp hướng dẫn cụ thể khi gặp lỗi thay vì chỉ hiện lỗi kỹ thuật"
    
    print_section "IV. CÁCH HOẠT ĐỘNG CỦA SUPABASE KIT"
    
    print_status $WHITE "1. Phát hiện hệ điều hành và môi trường"
    print_status $WHITE "2. Tự động điều chỉnh giao diện và chức năng phù hợp"
    print_status $WHITE "3. Kiểm tra các yêu cầu hệ thống"
    print_status $WHITE "4. Cung cấp menu dễ sử dụng với hướng dẫn tiếng Việt"
    print_status $WHITE "5. Khi thực hiện tác vụ, tự động:"
    print_status $WHITE "   - Kiểm tra điều kiện tiên quyết"
    print_status $WHITE "   - Thực hiện các bước cần thiết"
    print_status $WHITE "   - Áp dụng các chiến lược dự phòng nếu gặp lỗi"
    print_status $WHITE "   - Cung cấp thông báo trạng thái rõ ràng"
    print_status $WHITE "   - Lưu log hoạt động để debug nếu cần"
    
    echo ""
    print_status $GREEN "🎉 Supabase Kit là công cụ mạnh mẽ giúp bạn quản lý hệ thống Supabase dễ dàng"
    print_status $GREEN "   dù bạn là người mới bắt đầu hay chuyên gia có kinh nghiệm!"
    
    echo ""
    print_status $CYAN "💡 Gợi ý: Luôn chạy chức năng 'Kiểm tra môi trường' trước khi thực hiện backup/restore"
    print_status $CYAN "   để đảm bảo hệ thống sẵn sàng và tránh các lỗi không cần thiết."
}

# Run main function
main "$@"