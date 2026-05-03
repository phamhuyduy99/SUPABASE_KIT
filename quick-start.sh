#!/bin/bash
# ==============================================
# QUICK-START.SH – Hướng dẫn bắt đầu nhanh
# -------------------------------------------------
# Script này cung cấp hướng dẫn nhanh chóng để 
# người dùng bắt đầu sử dụng Supabase Kit ngay lập tức.
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
    print_status $PURPLE "==============================================="
    print_status $PURPLE "      HƯỚNG DẪN BẮT ĐẦU NHANH SUPABASE KIT"
    print_status $PURPLE "==============================================="
}

print_step() {
    local step_num=$1
    local step_desc=$2
    print_status $YELLOW "🔹 Bước $step_num: $step_desc"
}

print_note() {
    local note=$1
    print_status $CYAN "💡 $note"
}

# Main function
main() {
    print_title
    
    print_status $GREEN "Chào mừng bạn đến với Supabase Kit - Bộ công cụ quản trị Supabase toàn diện!"
    echo ""
    
    print_status $WHITE "Supabase Kit giúp bạn dễ dàng:"
    print_status $WHITE "• Backup toàn diện hệ thống Supabase"
    print_status $WHITE "• Khôi phục hệ thống từ bản backup"
    print_status $WHITE "• Kiểm tra trạng thái và môi trường hệ thống"
    print_status $WHITE "• Cấu hình HTTPS, domain và nhiều tiện ích khác"
    echo ""
    
    print_status $YELLOW "🎯 CÁC BƯỚC BẮT ĐẦU NHANH:"
    echo ""
    
    print_step 1 "Kiểm tra hệ thống"
    print_status $WHITE "   Đảm bảo Docker và Docker Compose đã được cài đặt:"
    print_status $CYAN "   docker --version && docker-compose --version"
    print_note "Nếu chưa cài đặt, hãy truy cập https://docs.docker.com/get-docker/"
    echo ""
    
    print_step 2 "Thiết lập quyền thực thi"
    print_status $WHITE "   Cấp quyền thực thi cho các script:"
    print_status $CYAN "   chmod +x setup-permissions.sh && ./setup-permissions.sh"
    print_note "Việc này chỉ cần làm một lần sau khi tải về hoặc clone"
    echo ""
    
    print_step 3 "Chạy chương trình"
    case "$(uname -s)" in
        Linux*|Darwin*)
            print_status $WHITE "   Trên Linux/macOS:"
            print_status $CYAN "   cd linux/ && ./supa-menu.sh"
            print_status $WHITE "   Hoặc chạy script tự động nhận diện hệ điều hành:"
            print_status $CYAN "   ./supa-start.sh"
            ;;
        CYGWIN*|MINGW*|MSYS*)
            print_status $WHITE "   Trên Windows (PowerShell với quyền Admin):"
            print_status $CYAN "   cd windows/ && .\\Start-SupabaseKit.ps1"
            ;;
        *)
            print_status $WHITE "   Xác định hệ điều hành không chính xác, xem tài liệu:"
            print_status $CYAN "   cat README.md"
            ;;
    esac
    print_note "Menu chính cung cấp giao diện dễ sử dụng cho tất cả tính năng"
    echo ""
    
    print_step 4 "Thực hiện các tác vụ cần thiết"
    print_status $WHITE "   • Chọn '1. Đóng băng hệ thống (Backup)' để sao lưu"
    print_status $WHITE "   • Chọn '2. Khôi phục hệ thống (Restore)' để khôi phục"
    print_status $WHITE "   • Chọn '3. Kiểm tra trạng thái' để giám sát"
    print_status $WHITE "   • Chọn '4. Cài HTTPS & domain' để cấu hình HTTPS"
    print_status $WHITE "   • Chọn '7. Kiểm tra tương thích VPS' để kiểm tra môi trường"
    echo ""
    
    print_status $YELLOW "🔥 TÍNH NĂNG NỔI BẬT:"
    print_status $WHITE "   • 25 chiến lược xử lý lỗi sysctl cho VPS LXC/OpenVZ"
    print_status $WHITE "   • 10 phương pháp import database khác nhau"
    print_status $WHITE "   • Tự động xử lý cấu hình, database và storage"
    print_status $WHITE "   • Giao diện màu sắc, thân thiện với người dùng"
    print_status $WHITE "   • Hỗ trợ đầy đủ trên Linux, Windows và macOS"
    echo ""
    
    print_status $YELLOW "📚 TÀI LIỆU THAM KHẢO:"
    print_status $WHITE "   • HUONG_DAN_SU_DUNG.md - Hướng dẫn chi tiết bằng tiếng Việt"
    print_status $WHITE "   • README.md - Tài liệu tổng quan"
    print_status $WHITE "   • README-WINDOWS.md - Tài liệu cho Windows"
    print_status $WHITE "   • README-MACOS.md - Tài liệu cho macOS"
    echo ""
    
    print_status $GREEN "💡 MẸO: Nếu gặp lỗi, hãy chạy chức năng 'Kiểm tra tương thích VPS' đầu tiên"
    print_status $GREEN "    để xác định nguyên nhân và cách khắc phục phù hợp."
    echo ""
    
    print_status $GREEN "🎉 Chúc bạn sử dụng Supabase Kit hiệu quả!"
}

# Run main function
main "$@"