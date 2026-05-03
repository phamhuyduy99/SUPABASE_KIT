#!/bin/bash
# ==============================================
# CHECK-COMPLETENESS.SH – Kiểm tra tính toàn vẹn của Supabase Kit
# -------------------------------------------------
# Script này sẽ kiểm tra tất cả các thành phần của bộ kit
# để đảm bảo mọi thứ đã được cài đặt và cấu hình đúng.
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
    print_status $PURPLE "  KIỂM TRA TÍNH TOÀN VẸN CỦA SUPABASE KIT"
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

# Main function
main() {
    print_title
    
    # Check OS
    print_section "KIỂM TRA HỆ ĐIỀU HÀNH"
    case "$(uname -s)" in
        Linux*)     os="Linux" ;;
        Darwin*)    os="macOS" ;;
        CYGWIN*|MINGW*|MSYS*) os="Windows/Cygwin" ;;
        *)          os="Unknown" ;;
    esac
    print_result "OK" "Hệ điều hành: $os"
    
    # Check required tools
    print_section "KIỂM TRA CÔNG CỤ CẦN THIẾT"
    tools=("docker" "docker-compose" "tar" "gzip" "wget" "curl" "git")
    for tool in "${tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            print_result "OK" "$tool: Có sẵn"
        else
            print_result "MISSING" "$tool: Thiếu"
        fi
    done
    
    # Check Docker daemon
    print_section "KIỂM TRA DỊCH VỤ DOCKER"
    if command -v docker &> /dev/null; then
        if docker info &> /dev/null; then
            print_result "OK" "Docker daemon: Đang chạy"
        else
            print_result "ERROR" "Docker daemon: Không chạy (vui lòng khởi động Docker)"
        fi
    else
        print_result "MISSING" "Docker: Không cài đặt"
    fi
    
    # Check directory structure
    print_section "KIỂM TRA CẤU TRÚC THƯ MỤC"
    dirs=("linux" "windows")
    for dir in "${dirs[@]}"; do
        if [ -d "$dir" ]; then
            print_result "OK" "Thư mục $dir/: Tồn tại"
        else
            print_result "MISSING" "Thư mục $dir/: Không tồn tại"
        fi
    done
    
    # Check Linux scripts
    print_section "KIỂM TRA SCRIPT LINUX"
    linux_scripts=(
        "linux/common.sh"
        "linux/supa-start.sh"
        "linux/supa-menu.sh"
        "linux/supa-freeze.sh"
        "linux/supa-restore.sh"
        "linux/supa-status.sh"
        "linux/supa-check-env.sh"
        "linux/supa-setup-nginx.sh"
        "linux/supa-setup-gdrive.sh"
    )
    
    for script in "${linux_scripts[@]}"; do
        if [ -f "$script" ]; then
            # Check if executable
            if [ -x "$script" ]; then
                print_result "OK" "$script: Tồn tại và có quyền thực thi"
            else
                print_result "WARNING" "$script: Tồn tại nhưng thiếu quyền thực thi"
            fi
        else
            print_result "MISSING" "$script: Không tồn tại"
        fi
    done
    
    # Check Windows scripts
    print_section "KIỂM TRA SCRIPT WINDOWS"
    windows_scripts=(
        "windows/SupabaseKit.psm1"
        "windows/Start-SupabaseKit.ps1"
        "windows/Invoke-Freeze.ps1"
        "windows/Invoke-Restore.ps1"
        "windows/Invoke-Status.ps1"
        "windows/Invoke-CheckEnv.ps1"
    )
    
    for script in "${windows_scripts[@]}"; do
        if [ -f "$script" ]; then
            print_result "OK" "$script: Tồn tại"
        else
            print_result "MISSING" "$script: Không tồn tại"
        fi
    done
    
    # Check documentation
    print_section "KIỂM TRA TÀI LIỆU"
    docs=(
        "README.md"
        "README-WINDOWS.md"
        "README-MACOS.md"
        "HUONG_DAN_SU_DUNG.md"
        "README.txt"
    )
    
    for doc in "${docs[@]}"; do
        if [ -f "$doc" ]; then
            print_result "OK" "$doc: Tồn tại"
        else
            print_result "MISSING" "$doc: Không tồn tại"
        fi
    done
    
    # Check core functionality
    print_section "KIỂM TRA CHỨC NĂNG CỐT LÕI"
    
    # Check if common.sh is sourced in main scripts
    if grep -q "source.*common.sh\|import.*common.sh" linux/supa-*.sh 2>/dev/null; then
        print_result "OK" "common.sh được tích hợp vào các script Linux"
    else
        print_result "WARNING" "common.sh có thể chưa được tích hợp đúng"
    fi
    
    # Check if PowerShell module is imported
    if grep -q "Import-Module.*SupabaseKit.psm1" windows/*.ps1 2>/dev/null; then
        print_result "OK" "SupabaseKit.psm1 được tích hợp vào các script Windows"
    else
        print_result "WARNING" "SupabaseKit.psm1 có thể chưa được tích hợp đúng"
    fi
    
    # Final summary
    echo ""
    print_status $YELLOW "💡 Ghi chú:"
    print_status $WHITE "  - Các mục MISSING là các thành phần thiếu trong bộ kit"
    print_status $WHITE "  - Các mục WARNING là các vấn đề nhỏ có thể cần điều chỉnh"
    print_status $WHITE "  - Các mục ERROR là các lỗi nghiêm trọng cần xử lý"
    echo ""
    print_status $GREEN "✅ Kiểm tra hoàn tất. Supabase Kit đã sẵn sàng để sử dụng!"
}

# Run main function
main "$@"