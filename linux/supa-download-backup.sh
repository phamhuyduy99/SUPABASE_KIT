#!/bin/bash
# supabase-kit/linux/supa-download-backup.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

print_title "TẢI FILE BACKUP TỪ VPS VỀ MÁY LOCAL"

# Nhập thông tin VPS
read -p "Nhập địa chỉ VPS (user@ip): " REMOTE
if [ -z "$REMOTE" ]; then
    print_error "Bạn phải nhập địa chỉ VPS."
    exit 1
fi

# Nhập đường dẫn thư mục backup trên VPS (mặc định thường là thư mục dự án hoặc ~/supabase_self_host_backup)
read -p "Đường dẫn thư mục chứa backup trên VPS (ví dụ: /opt/supabase/backup): " REMOTE_DIR
if [ -z "$REMOTE_DIR" ]; then
    REMOTE_DIR="/opt/supabase/backup"
    print_info "Sử dụng đường dẫn mặc định: $REMOTE_DIR"
fi

# Nhập thư mục lưu trên máy local
read -p "Thư mục lưu trên máy local (mặc định: ~/Downloads): " LOCAL_DIR
LOCAL_DIR="${LOCAL_DIR:-$HOME/Downloads}"

# Kiểm tra kết nối SSH
print_info "Đang kiểm tra kết nối SSH tới $REMOTE..."
if ! ssh -o ConnectTimeout=10 -o BatchMode=yes "$REMOTE" echo "OK" 2>/dev/null; then
    print_error "Không thể kết nối SSH đến $REMOTE."
    print_info "Hãy đảm bảo bạn đã cấu hình SSH key hoặc nhập đúng mật khẩu."
    exit 1
fi
print_success "Kết nối SSH thành công."

# Tìm file backup mới nhất trên VPS
print_info "Đang tìm file backup mới nhất trong $REMOTE_DIR..."
LATEST_BACKUP=$(ssh "$REMOTE" "ls -t $REMOTE_DIR/supabase-backup-*.tar.gz 2>/dev/null | head -1")
if [ -z "$LATEST_BACKUP" ]; then
    print_error "Không tìm thấy file backup nào trong $REMOTE_DIR."
    exit 1
fi

BACKUP_NAME=$(basename "$LATEST_BACKUP")
print_info "File backup mới nhất: $BACKUP_NAME"

# Tải về
print_info "Đang tải $BACKUP_NAME về $LOCAL_DIR ..."
scp "$REMOTE:$LATEST_BACKUP" "$LOCAL_DIR/"
if [ $? -eq 0 ]; then
    print_success "Đã tải thành công: $LOCAL_DIR/$BACKUP_NAME"
    
    # Hỏi người dùng có muốn kiểm tra checksum không
    if [ -f "$LOCAL_DIR/$BACKUP_NAME.sha256" ]; then
        print_info "Tìm thấy file checksum, đang kiểm tra tính toàn vẹn..."
        (
            cd "$LOCAL_DIR" &&
            sha256sum -c "$BACKUP_NAME.sha256" --quiet
        )
        if [ $? -eq 0 ]; then
            print_success "Checksum hợp lệ. File không bị hỏng."
        else
            print_warning "Checksum không khớp. File có thể bị hỏng trong quá trình truyền."
        fi
    else
        print_warning "Không tìm thấy file checksum (.sha256). Không thể xác minh tính toàn vẹn."
    fi
else
    print_error "Tải thất bại."
    exit 1
fi