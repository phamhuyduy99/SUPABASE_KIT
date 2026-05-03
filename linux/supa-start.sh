#!/bin/bash
# supabase-kit/linux/supa-start.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Phát hiện HĐH
OS_TYPE=$(uname -s)
case "$OS_TYPE" in
    Linux)
        print_info "Hệ điều hành: Linux"
        ;;
    Darwin)
        print_info "Hệ điều hành: macOS"
        ;;
    *)
        print_error "Hệ điều hành không được hỗ trợ: $OS_TYPE"
        exit 1
        ;;
esac

# Sửa lỗi xuống dòng nếu cần
if command -v sed >/dev/null 2>&1; then
    sed -i 's/\r$//' "$SCRIPT_DIR"/*.sh 2>/dev/null || true
fi

# Kiểm tra môi trường cơ bản
print_title "KIỂM TRA MÔI TRƯỜNG"
if ! check_os_version; then
    exit 1
fi
if ! check_network; then
    exit 1
fi

# Nếu có sudo (Linux) hoặc có quyền admin (macOS)
if sudo -n true 2>/dev/null || [ "$OS_TYPE" = "Darwin" ]; then
    print_success "Quyền quản trị sẵn sàng."
    bash "$SCRIPT_DIR/supa-menu.sh"
else
    print_warning "Bạn không có quyền sudo. Một số chức năng cần quyền quản trị."
    read -p "Tiếp tục với quyền hạn chế? (y/n): " ans
    if [ "$ans" = "y" ]; then
        bash "$SCRIPT_DIR/supa-menu.sh"
    else
        exit 0
    fi
fi