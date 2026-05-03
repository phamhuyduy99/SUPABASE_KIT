#!/bin/bash
# ==============================================
# SETUP-PERMISSIONS.SH – Thiết lập quyền thực thi cho các script
# -------------------------------------------------
# Script này sẽ cấp quyền thực thi cho tất cả các file
# script cần thiết trong bộ Supabase Kit.
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
    print_status $PURPLE "  THIẾT LẬP QUYỀN THỰC THI CHO SUPABASE KIT"
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
    
    print_section "CẤP QUYỀN THỰC THI CHO CÁC SCRIPT LINUX"
    
    # Linux scripts that need executable permission
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
        "linux/supa-freeze-enhanced.sh"
        "linux/supa-restore-enhanced.sh"
    )
    
    for script in "${linux_scripts[@]}"; do
        if [ -f "$script" ]; then
            chmod +x "$script"
            if [ -x "$script" ]; then
                print_result "OK" "$script: Đã cấp quyền thực thi"
            else
                print_result "ERROR" "$script: Không thể cấp quyền thực thi"
            fi
        else
            print_result "MISSING" "$script: Không tồn tại"
        fi
    done
    
    print_section "CẬP NHẬT README VÀ CÁC SCRIPT GỐC"
    
    # Root scripts that need executable permission
    root_scripts=(
        "supa-start.sh"
        "check-completeness.sh"
        "setup-permissions.sh"
        "update-permissions.sh"
        "initialize-kit.sh"
        "quick-start.sh"
        "backup-config.sh"
        "enhanced-features-guide.sh"
        "common.sh"
        "supa-menu.sh"
        "supa-status.sh"
        "supa-check-env.sh"
        "supa-setup-nginx.sh"
        "supa-setup-gdrive.sh"
    )
    
    for script in "${root_scripts[@]}"; do
        if [ -f "$script" ]; then
            chmod +x "$script"
            if [ -x "$script" ]; then
                print_result "OK" "$script: Đã cấp quyền thực thi"
            else
                print_result "ERROR" "$script: Không thể cấp quyền thực thi"
            fi
        else
            print_result "MISSING" "$script: Không tồn tại"
        fi
    done
    
    print_section "KIỂM TRA CẤU HÌNH"
    
    # Verify the changes
    if [ -x "linux/supa-freeze.sh" ] && [ -x "linux/supa-restore.sh" ]; then
        print_result "OK" "Các script chính đã có quyền thực thi"
    else
        print_result "ERROR" "Có vấn đề với quyền thực thi của các script chính"
    fi
    
    if [ -x "supa-start.sh" ]; then
        print_result "OK" "Script khởi động chính đã có quyền thực thi"
    else
        print_result "ERROR" "Script khởi động chính không có quyền thực thi"
    fi
    
    # Summary
    echo ""
    print_status $YELLOW "💡 Ghi chú:"
    print_status $WHITE "  - Tất cả các script Bash cần có quyền thực thi để chạy trực tiếp"
    print_status $WHITE "  - Trên Windows, quyền thực thi được quản lý qua chính sách PowerShell"
    print_status $WHITE "  - Script này có thể cần chạy với sudo nếu gặp lỗi quyền"
    echo ""
    print_status $GREEN "✅ Thiết lập quyền thực thi hoàn tất!"
    echo ""
    print_status $CYAN "💡 Để chạy Supabase Kit:"
    print_status $WHITE "  - Linux/macOS: cd linux/ && ./supa-menu.sh"
    print_status $WHITE "  - Hoặc: ./supa-start.sh để tự động phát hiện hệ điều hành"
}

# Run main function
main "$@"