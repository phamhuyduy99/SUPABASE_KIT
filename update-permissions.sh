#!/bin/bash
# ==============================================
# UPDATE-PERMISSIONS.SH – Cập nhật quyền thực thi khi cần
# -------------------------------------------------
# Script này sẽ cập nhật quyền thực thi cho tất cả các script
# trong trường hợp cần thiết sau khi có cập nhật.
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
    print_status $PURPLE "  CẬP NHẬT QUYỀN THỰC THI SUPABASE KIT"
    print_status $PURPLE "==============================================="
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

# Function to make_executable
make_executable() {
    local file_path=$1
    if [ -f "$file_path" ]; then
        chmod +x "$file_path"
        if [ -x "$file_path" ]; then
            print_result "OK" "$file_path: Đã cập nhật quyền thực thi"
        else
            print_result "ERROR" "$file_path: Không thể cập nhật quyền thực thi"
        fi
    else
        print_result "MISSING" "$file_path: Không tồn tại"
    fi
}

# Main function
main() {
    print_title
    
    print_status $YELLOW "Cập nhật quyền thực thi cho tất cả các script trong Supabase Kit..."
    echo ""
    
    # Linux scripts
    print_status $CYAN ">>> CẬP NHẬT SCRIPT LINUX"
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
        make_executable "$script"
    done
    
    # Root scripts
    print_status $CYAN ">>> CẬP NHẬT SCRIPT GỐC"
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
        "supa-freeze.sh"
        "supa-restore.sh"
    )
    
    for script in "${root_scripts[@]}"; do
        make_executable "$script"
    done
    
    # Verification
    print_status $CYAN ">>> KIỂM TRA XÁC NHẬN"
    
    essential_scripts=(
        "linux/supa-menu.sh"
        "linux/supa-freeze.sh"
        "linux/supa-restore.sh"
        "supa-start.sh"
        "initialize-kit.sh"
    )
    
    all_good=true
    for script in "${essential_scripts[@]}"; do
        if [ ! -x "$script" ]; then
            print_result "ERROR" "$script: Vẫn chưa có quyền thực thi!"
            all_good=false
        fi
    done
    
    if [ "$all_good" = true ]; then
        print_result "OK" "Tất cả script quan trọng đã có quyền thực thi"
        print_status $GREEN ""
        print_status $GREEN "🎉 Cập nhật quyền thực thi thành công!"
        print_status $WHITE "Bạn có thể bắt đầu sử dụng Supabase Kit ngay bây giờ."
    else
        print_status $RED ""
        print_status $RED "❌ Có lỗi trong quá trình cập nhật quyền thực thi!"
        print_status $WHITE "Bạn có thể cần chạy script này với quyền sudo:"
        print_status $CYAN "sudo $0"
    fi
}

# Run main function
main "$@"