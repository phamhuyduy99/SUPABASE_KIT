#!/bin/bash
# supabase-kit/linux/supa-freeze-enhanced.sh
# Enhanced version with pre-check and improved error handling
# Maintains all original complex logic while adding improvements

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

print_title "SUPABASE FREEZE (BACKUP) - PHIÊN BẢN NÂNG CAO"

# Run environment check before proceeding
print_info "Đang chạy kiểm tra môi trường trước khi backup..."
if ! bash "$SCRIPT_DIR/supa-check-env.sh" >/tmp/env_check_$$.log 2>&1; then
    print_warning "Kiểm tra môi trường có cảnh báo (xem /tmp/env_check_$$.log)"
    read -p "Tiếp tục với cảnh báo? (y/N): " confirm
    if [[ "$confirm" != "y" ]]; then
        print_info "Hủy tạo backup."
        rm -f /tmp/env_check_$$.log
        exit 0
    fi
else
    print_success "Kiểm tra môi trường thành công!"
fi
rm -f /tmp/env_check_$$.log

# Original backup logic with improvements
SOURCE_DIR="${1:-.}"
BACKUP_DIR="${2:-./backup_$(date +%Y%m%d_%H%M%S)}"

print_info "Đang chuẩn bị tạo bản backup..."
print_info "Thư mục nguồn: $SOURCE_DIR"
print_info "Thư mục backup: $BACKUP_DIR"

# Kiểm tra quyền truy cập
if [[ ! -r "$SOURCE_DIR" ]]; then
    print_error "Không có quyền đọc thư mục nguồn: $SOURCE_DIR"
    exit 1
fi

if [[ -d "$BACKUP_DIR" ]]; then
    print_warning "Thư mục backup đã tồn tại: $BACKUP_DIR"
    read -p "Tiếp tục và ghi đè? (y/n): " confirm
    if [[ "$confirm" != "y" ]]; then
        print_info "Hủy tạo backup."
        exit 0
    fi
else
    mkdir -p "$BACKUP_DIR"
fi

# Tạo backup với các cải tiến
print_info "Bắt đầu quá trình backup..."

# Sao chép các file cấu hình cơ bản
cp "$SOURCE_DIR/.env" "$BACKUP_DIR/" 2>/dev/null && print_success ".env đã được sao chép" || print_warning ".env không tồn tại"
cp "$SOURCE_DIR/docker-compose.yml" "$BACKUP_DIR/" 2>/dev/null && print_success "docker-compose.yml đã được sao chép" || print_warning "docker-compose.yml không tồn tại"
cp "$SOURCE_DIR/Dockerfile" "$BACKUP_DIR/" 2>/dev/null && print_success "Dockerfile đã được sao chép" || print_info "Dockerfile không tồn tại"

# Sao chép các thư mục cấu hình quan trọng
cp -r "$SOURCE_DIR/database" "$BACKUP_DIR/" 2>/dev/null && print_success "Thư mục database đã được sao chép" || print_info "Không tìm thấy thư mục database"
cp -r "$SOURCE_DIR/config" "$BACKUP_DIR/" 2>/dev/null && print_success "Thư mục config đã được sao chép" || print_info "Không tìm thấy thư mục config"
cp -r "$SOURCE_DIR/migrations" "$BACKUP_DIR/" 2>/dev/null && print_success "Thư mục migrations đã được sao chép" || print_info "Không tìm thấy thư mục migrations"

# Backup dữ liệu Postgres nếu container đang chạy
if docker ps | grep -q postgres; then
    print_info "Đang sao lưu dữ liệu PostgreSQL..."
    
    # Tạo thư mục tạm để chứa dữ liệu dump
    TEMP_DUMP_DIR="/tmp/pg_dump_$$"
    mkdir -p "$TEMP_DUMP_DIR"
    
    # Dump dữ liệu vào thư mục tạm
    if docker exec $(docker ps -q -f name=postgres) pg_dump -U supabase_admin -d supabase_db -Fc > "$TEMP_DUMP_DIR/postgres_backup.sql" 2>/dev/null; then
        # Di chuyển file dump vào thư mục backup
        mv "$TEMP_DUMP_DIR/postgres_backup.sql" "$BACKUP_DIR/"
        print_success "Dữ liệu PostgreSQL đã được sao lưu."
        
        # Xóa thư mục tạm
        rm -rf "$TEMP_DUMP_DIR"
    else
        print_error "Lỗi khi sao lưu PostgreSQL"
        rm -rf "$TEMP_DUMP_DIR"
        exit 1
    fi
else
    print_info "Container PostgreSQL không đang chạy, bỏ qua backup dữ liệu."
fi

# Backup dữ liệu Storage nếu có
if docker ps | grep -q storage; then
    print_info "Đang sao lưu dữ liệu Storage..."
    STORAGE_BACKUP_DIR="$BACKUP_DIR/storage-data"
    mkdir -p "$STORAGE_BACKUP_DIR"
    
    if docker cp $(docker ps -q -f name=storage):/var/lib/storage-api "$STORAGE_BACKUP_DIR/" 2>/dev/null; then
        print_success "Dữ liệu Storage đã được sao lưu."
    else
        print_warning "Không thể sao lưu dữ liệu Storage"
    fi
else
    print_info "Container Storage không đang chạy, bỏ qua backup dữ liệu."
fi

# Tạo tệp thông tin backup
{
    echo "Backup Date: $(date)"
    echo "Source Directory: $SOURCE_DIR"
    echo "System Info: $(uname -srm)"
    echo "Supabase Version: $(docker images supabase/postgres --format "table {{.Tag}}" 2>/dev/null | head -n 1 || echo 'Unknown')"
} > "$BACKUP_DIR/backup-info.txt"

# Tạo file checksum để xác minh sau này
find "$BACKUP_DIR" -type f -exec sha256sum {} \; > "$BACKUP_DIR/checksums.sha256"

print_success "Tạo backup thành công!"
print_info "Đường dẫn backup: $BACKUP_DIR"
print_success "Thông tin backup đã được lưu vào backup-info.txt"
print_info "Checksums đã được tạo để xác minh tính toàn vẹn."

# Hỏi người dùng có muốn nén lại không
read -p "Bạn có muốn nén thư mục backup lại không? (y/N): " compress_choice
if [[ "$compress_choice" == "y" ]]; then
    BACKUP_TAR_FILE="${BACKUP_DIR}.tar.gz"
    print_info "Đang nén thư mục backup..."
    tar -czf "$BACKUP_TAR_FILE" -C "$(dirname "$BACKUP_DIR")" "$(basename "$BACKUP_DIR")"
    if [[ $? -eq 0 ]]; then
        print_success "Backup đã được nén thành công: $BACKUP_TAR_FILE"
        
        # Tính toán kích thước
        SIZE=$(du -h "$BACKUP_TAR_FILE" | cut -f1)
        print_info "Kích thước file nén: $SIZE"
        
        # Hỏi có muốn xóa thư mục gốc sau khi nén không
        read -p "Bạn có muốn xóa thư mục gốc sau khi nén không? (y/N): " remove_choice
        if [[ "$remove_choice" == "y" ]]; then
            rm -rf "$BACKUP_DIR"
            print_info "Thư mục gốc đã được xóa."
        fi
    else
        print_error "Lỗi khi nén thư mục backup."
    fi
fi