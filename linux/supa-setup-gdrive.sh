#!/bin/bash
# supabase-kit/linux/supa-setup-gdrive.sh
# Script để thiết lập đồng bộ hóa backup với Google Drive

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

print_title "THIẾT LẬP GOOGLE DRIVE CHO BACKUP SUPABASE"

# Kiểm tra xem rclone đã được cài đặt chưa
if ! command -v rclone &>/dev/null; then
    print_info "Rclone chưa được cài đặt. Đang tiến hành cài đặt..."
    
    # Cài đặt rclone
    if command -v curl &>/dev/null; then
        curl https://rclone.org/install.sh | sudo bash
    elif command -v wget &>/dev/null; then
        wget -qO- https://rclone.org/install.sh | sudo bash
    else
        print_error "Không tìm thấy curl hoặc wget để cài đặt rclone."
        print_info "Vui lòng cài đặt rclone thủ công theo hướng dẫn tại: https://rclone.org/install/"
        exit 1
    fi
    
    print_success "Rclone đã được cài đặt."
else
    print_success "Rclone đã được cài đặt."
fi

# Kiểm tra cấu hình rclone hiện có
if rclone listremotes | grep -q "gdrive"; then
    print_warning "Đã tồn tại remote 'gdrive' trong rclone."
    read -p "Bạn có muốn cấu hình lại không? (y/N): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        print_info "Đang mở cấu hình rclone..."
        rclone config
    else
        print_info "Giữ nguyên cấu hình hiện tại."
    fi
else
    print_info "Đang bắt đầu cấu hình Google Drive với rclone..."
    print_info "Chọn các tùy chọn sau trong quá trình cấu hình:"
    echo "  - Type: drive"
    echo "  - Client Id và Secret: (để trống)"
    echo "  - Scope: 1 (Full Drive)"
    echo "  - Service Account: n"
    echo "  - Edit advanced config: n"
    echo "  - Remote config: (chấp nhận mặc định)"
    echo "  - Root Folder: (chấp nhận mặc định)"
    echo ""
    
    read -p "Ấn Enter để tiếp tục đến bước xác thực với Google..."
    rclone config
fi

# Kiểm tra lại remote sau khi cấu hình
if rclone listremotes | grep -q "gdrive"; then
    print_success "Remote 'gdrive' đã được cấu hình."
    
    # Kiểm tra kết nối
    print_info "Đang kiểm tra kết nối đến Google Drive..."
    if rclone ls gdrive: --max-depth 1 | head -n 5; then
        print_success "Kết nối đến Google Drive thành công!"
        
        # Tạo thư mục cho backup Supabase
        print_info "Đang tạo thư mục 'Supabase Backups' trên Google Drive..."
        rclone mkdir gdrive:"Supabase Backups" 2>/dev/null || true
        print_success "Thư mục 'Supabase Backups' đã được tạo (nếu chưa tồn tại)."
        
        # Hiển thị cách sử dụng
        print_title "HƯỚNG DẪN SỬ DỤNG"
        echo "1. Để sao lưu thư mục backup lên Google Drive:"
        echo "   rclone copy /path/to/backup gdrive:'Supabase Backups/' --progress"
        echo ""
        echo "2. Để khôi phục từ Google Drive:"
        echo "   rclone copy gdrive:'Supabase Backups/backup_folder' /path/to/local/ --progress"
        echo ""
        echo "3. Để đồng bộ thư mục backup với Google Drive (upload các thay đổi):"
        echo "   rclone sync /path/to/backup gdrive:'Supabase Backups/latest-backup' --progress"
        echo ""
        print_info "Bạn có thể tạo script tự động backup định kỳ bằng cron kết hợp với lệnh rclone."
        
    else
        print_error "Không thể truy cập Google Drive. Vui lòng kiểm tra lại xác thực."
        exit 1
    fi
else
    print_error "Không tìm thấy remote 'gdrive'. Cấu hình thất bại."
    exit 1
fi

print_success "Thiết lập Google Drive hoàn tất!"