#!/bin/bash
# ==============================================
# INITIALIZE-KIT.SH – Khởi tạo Supabase Kit
# -------------------------------------------------
# Script này sẽ giúp người dùng bắt đầu nhanh chóng
# với Supabase Kit bằng cách thiết lập quyền và
# hướng dẫn các bước đầu tiên.
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
    print_status $PURPLE "      KHỞI TẠO SUPABASE KIT"
    print_status $PURPLE "==============================================="
}

print_section() {
    echo ""
    print_status $CYAN ">>> $1"
}

print_result() {
    local status=$1
    local msg=$2
    if [ "$status" = "OK" ]; then
        print_status $GREEN "✅ $msg"
    else
        print_status $RED "❌ $msg"
    fi
}

# Function to ask for user confirmation
ask_confirmation() {
    local question=$1
    read -p "$question (y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

# Main function
main() {
    print_title
    
    print_status $WHITE "Chào mừng bạn đến với Supabase Kit!"
    print_status $WHITE "Script này sẽ giúp bạn thiết lập và bắt đầu sử dụng bộ công cụ."
    echo ""
    
    # Check if we're in the right directory
    if [ ! -f "setup-permissions.sh" ] && [ ! -f "linux/supa-menu.sh" ] && [ ! -f "windows/Start-SupabaseKit.ps1" ]; then
        # Relaxing check slightly to allow running if at least some parts exist, 
        # but ideally we check for key entry points.
        # Using the reference logic:
        if [ ! -f "linux/supa-menu.sh" ] && [ ! -f "windows/Start-SupabaseKit.ps1" ]; then
             print_result "ERROR" "Không tìm thấy các thành phần chính của Supabase Kit"
             print_status $YELLOW "Vui lòng đảm bảo bạn đang chạy script này từ thư mục gốc của Supabase Kit"
             exit 1
        fi
    fi
    
    # Ask for permission to set up
    if ask_confirmation "Bạn có muốn thiết lập quyền thực thi cho các script?"; then
        print_section "THIẾT LẬP QUYỀN THỰC THI"
        
        # Run the permissions script
        if [ -f "setup-permissions.sh" ]; then
            chmod +x setup-permissions.sh
            ./setup-permissions.sh
            print_result "OK" "Đã thiết lập quyền thực thi cho các script"
        else
            # Fallback if specific setup script doesn't exist but we want to be helpful
            chmod +x linux/*.sh 2>/dev/null
            chmod +x check-completeness.sh 2>/dev/null
            chmod +x backup-config.sh 2>/dev/null
            print_result "OK" "Đã cố gắng cấp quyền thực thi cho các script hiện có"
        fi
    else
        print_status $YELLOW "Bỏ qua thiết lập quyền thực thi"
    fi
    
    # Check for required tools
    print_section "KIỂM TRA CÔNG CỤ CẦN THIẾT"
    
    required_tools=("docker" "docker-compose")
    missing_tools=()
    
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [ ${#missing_tools[@]} -eq 0 ]; then
        print_result "OK" "Tất cả công cụ cần thiết đã có sẵn"
    else
        print_status $YELLOW "⚠️  Các công cụ sau đang thiếu: ${missing_tools[*]}"
        print_status $WHITE "Vui lòng cài đặt Docker và Docker Compose trước khi sử dụng Supabase Kit"
        print_status $WHITE "Tham khảo: https://docs.docker.com/get-docker/"
    fi
    
    # Check Docker daemon
    if command -v docker &> /dev/null; then
        if ! docker info &> /dev/null; then
            print_status $YELLOW "⚠️  Docker daemon không đang chạy"
            print_status $WHITE "Vui lòng khởi động Docker Desktop/Docker Engine trước khi sử dụng Supabase Kit"
        else
            print_result "OK" "Docker daemon đang chạy"
        fi
    fi
    
    # Show usage instructions
    print_section "HƯỚNG DẪN SỬ DỤNG"
    
    case "$(uname -s)" in
        Linux*|Darwin*)
            print_status $WHITE "🔹 Bạn đang sử dụng Linux/macOS:"
            if [ -f "linux/supa-menu.sh" ]; then
                print_status $CYAN "   cd linux/ && ./supa-menu.sh"
            fi
            if [ -f "linux/supa-start.sh" ]; then
                print_status $WHITE "   Hoặc chạy trực tiếp:"
                print_status $CYAN "   ./linux/supa-start.sh"
            fi
            ;;
        CYGWIN*|MINGW*|MSYS*)
            print_status $WHITE "🔹 Bạn đang sử dụng Windows (Cygwin/MSYS2):"
            print_status $CYAN "   cd windows/ && .\\Start-SupabaseKit.ps1"
            print_status $WHITE "   (Chạy trên PowerShell với quyền Administrator)"
            ;;
        *)
            print_status $WHITE "🔹 Vui lòng xem tài liệu phù hợp với hệ điều hành của bạn:"
            print_status $CYAN "   README.md, README-WINDOWS.md, hoặc README-MACOS.md"
            ;;
    esac
    
    print_status $WHITE ""
    print_status $WHITE "🔹 Các tính năng chính của Supabase Kit:"
    print_status $CYAN "   • Backup toàn diện (supa-freeze.sh / Invoke-Freeze.ps1)"
    print_status $CYAN "   • Khôi phục hệ thống (supa-restore.sh / Invoke-Restore.ps1)"
    print_status $CYAN "   • Kiểm tra trạng thái (supa-status.sh / Invoke-Status.ps1)"
    print_status $CYAN "   • Kiểm tra môi trường (supa-check-env.sh / Invoke-CheckEnv.ps1)"
    print_status $CYAN "   • Cài đặt HTTPS & domain (supa-setup-nginx.sh)"
    print_status $WHITE ""
    print_status $WHITE "🔹 Tài liệu chi tiết:"
    print_status $CYAN "   • HUONG_DAN_SU_DUNG.md - Hướng dẫn đầy đủ bằng tiếng Việt"
    print_status $CYAN "   • README.md - Tài liệu tổng quan"
    print_status $WHITE ""
    
    if ask_confirmation "Bạn có muốn kiểm tra tính toàn vẹn của bộ kit ngay bây giờ?"; then
        if [ -f "check-completeness.sh" ]; then
            chmod +x check-completeness.sh
            ./check-completeness.sh
        else
            print_result "MISSING" "Không tìm thấy script kiểm tra tính toàn vẹn"
        fi
    fi
    
    echo ""
    print_status $GREEN "🎉 Supabase Kit đã sẵn sàng để sử dụng!"
    print_status $WHITE "Nếu gặp bất kỳ vấn đề nào, vui lòng tham khảo tài liệu hoặc liên hệ hỗ trợ."
}

# Run main function
main "$@"