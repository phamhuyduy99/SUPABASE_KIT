#!/bin/bash
# supabase-kit/linux/supa-restore-enhanced.sh
# Enhanced version with pre-check and improved error handling
# Maintains all original complex logic while adding improvements

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

print_title "SUPABASE RESTORE (KHÔI PHỤC) - PHIÊN BẢN NÂNG CAO"

# Kiểm tra tham số đầu vào
BACKUP_DIR="$1"
TARGET_DIR="${2:-.}"

if [[ -z "$BACKUP_DIR" ]]; then
    print_error "Bạn phải cung cấp đường dẫn thư mục backup!"
    echo "Cú pháp: $0 <đường_dẫn_backup> [đường_dẫn_đích]"
    exit 1
fi

print_info "Đang chuẩn bị khôi phục từ backup..."
print_info "Thư mục backup: $BACKUP_DIR"
print_info "Thư mục đích: $TARGET_DIR"

# Kiểm tra thư mục backup tồn tại
if [[ ! -d "$BACKUP_DIR" ]]; then
    # Nếu backup là file nén, giải nén trước
    if [[ -f "$BACKUP_DIR" && "$BACKUP_DIR" == *.tar.gz ]]; then
        print_info "Phát hiện file nén, đang giải nén..."
        EXTRACT_DIR=$(dirname "$BACKUP_DIR")/extracted_$(date +%Y%m%d_%H%M%S)
        mkdir -p "$EXTRACT_DIR"
        
        if tar -xzf "$BACKUP_DIR" -C "$EXTRACT_DIR"; then
            # Lấy thư mục con đầu tiên trong thư mục giải nén
            EXTRACTED_SUBDIR=$(find "$EXTRACT_DIR" -mindepth 1 -maxdepth 1 -type d | head -n 1)
            if [[ -n "$EXTRACTED_SUBDIR" ]]; then
                BACKUP_DIR="$EXTRACTED_SUBDIR"
                print_success "Đã giải nén thành công: $BACKUP_DIR"
            else
                print_error "Không tìm thấy thư mục sau khi giải nén."
                exit 1
            fi
        else
            print_error "Lỗi khi giải nén file backup."
            exit 1
        fi
    else
        print_error "Thư mục backup không tồn tại: $BACKUP_DIR"
        exit 1
    fi
fi

# Kiểm tra quyền ghi
if [[ ! -w "$TARGET_DIR" ]]; then
    print_error "Không có quyền ghi vào thư mục đích: $TARGET_DIR"
    exit 1
fi

# Hiển thị thông tin backup nếu tồn tại
if [[ -f "$BACKUP_DIR/backup-info.txt" ]]; then
    print_info "Thông tin backup:"
    cat "$BACKUP_DIR/backup-info.txt"
    echo
fi

# Run environment check before proceeding
print_info "Đang chạy kiểm tra môi trường trước khi khôi phục..."
if ! bash "$SCRIPT_DIR/supa-check-env.sh" >/tmp/env_check_$$.log 2>&1; then
    print_warning "Kiểm tra môi trường có cảnh báo (xem /tmp/env_check_$$.log)"
    read -p "Tiếp tục với cảnh báo? (y/N): " confirm
    if [[ "$confirm" != "y" ]]; then
        print_info "Hủy khôi phục."
        rm -f /tmp/env_check_$$.log
        exit 0
    fi
else
    print_success "Kiểm tra môi trường thành công!"
fi
rm -f /tmp/env_check_$$.log

# Xác nhận khôi phục
print_warning "Việc khôi phục sẽ ghi đè các file hiện có!"
read -p "Bạn có chắc chắn muốn khôi phục? (y/n): " confirm
if [[ "$confirm" != "y" ]]; then
    print_info "Hủy khôi phục."
    exit 0
fi

# Kiểm tra và xác minh tính toàn vẹn của backup nếu có checksum
if [[ -f "$BACKUP_DIR/checksums.sha256" ]]; then
    print_info "Đang xác minh tính toàn vẹn của backup..."
    pushd "$BACKUP_DIR" >/dev/null
    if sha256sum -c --status checksums.sha256 2>/dev/null; then
        print_success "Xác minh tính toàn vẹn thành công."
    else
        print_warning "Cảnh báo: Không thể xác minh tính toàn vẹn của backup."
        read -p "Tiếp tục khôi phục? (y/N): " confirm_verify
        if [[ "$confirm_verify" != "y" ]]; then
            print_info "Hủy khôi phục."
            popd >/dev/null
            exit 0
        fi
    fi
    popd >/dev/null
fi

# Tạo thư mục đích nếu chưa tồn tại
mkdir -p "$TARGET_DIR"

# Dừng các container cũ nếu đang chạy
if [[ -f "$TARGET_DIR/docker-compose.yml" ]]; then
    print_info "Đang dừng các container cũ..."
    cd "$TARGET_DIR"
    docker compose down 2>/dev/null || true
    cd - >/dev/null
fi

# Sao chép các file cấu hình
cp "$BACKUP_DIR/.env" "$TARGET_DIR/" 2>/dev/null && print_success ".env đã được khôi phục." || print_warning "Không tìm thấy .env trong backup"
cp "$BACKUP_DIR/docker-compose.yml" "$TARGET_DIR/" 2>/dev/null && print_success "docker-compose.yml đã được khôi phục." || print_warning "Không tìm thấy docker-compose.yml trong backup"
cp "$BACKUP_DIR/Dockerfile" "$TARGET_DIR/" 2>/dev/null && print_success "Dockerfile đã được khôi phục." || print_info "Không tìm thấy Dockerfile trong backup"

# Sao chép các thư mục cấu hình
cp -r "$BACKUP_DIR/database" "$TARGET_DIR/" 2>/dev/null && print_success "Thư mục database đã được khôi phục." || print_info "Không tìm thấy thư mục database trong backup"
cp -r "$BACKUP_DIR/config" "$TARGET_DIR/" 2>/dev/null && print_success "Thư mục config đã được khôi phục." || print_info "Không tìm thấy thư mục config trong backup"
cp -r "$BACKUP_DIR/migrations" "$TARGET_DIR/" 2>/dev/null && print_success "Thư mục migrations đã được khôi phục." || print_info "Không tìm thấy thư mục migrations trong backup"

# Khôi phục dữ liệu Postgres nếu có
if [[ -f "$BACKUP_DIR/postgres_backup.sql" ]]; then
    print_info "Đang khôi phục dữ liệu PostgreSQL..."
    
    # Đảm bảo thư mục mục tiêu có docker-compose.yml
    if [[ -f "$TARGET_DIR/docker-compose.yml" ]]; then
        cd "$TARGET_DIR"
        
        # Khởi động lại dịch vụ postgres (nếu có trong docker-compose.yml)
        if grep -q "postgres" docker-compose.yml; then
            print_info "Đang khởi động lại dịch vụ PostgreSQL..."
            docker compose up -d postgres 2>/dev/null &
            sleep 10
            
            # Kiểm tra nếu postgres đã chạy
            if docker ps | grep -q postgres; then
                print_info "Đang thực hiện khôi phục dữ liệu..."
                
                # Thực hiện khôi phục dữ liệu
                if cat "$BACKUP_DIR/postgres_backup.sql" | docker exec -i $(docker ps -q -f name=postgres) pg_restore -U supabase_admin -d supabase_db -c --if-exists 2>/dev/null; then
                    print_success "Dữ liệu PostgreSQL đã được khôi phục thành công."
                else
                    print_error "Lỗi khi khôi phục dữ liệu PostgreSQL"
                    cd - >/dev/null
                    exit 1
                fi
            else
                print_error "Dịch vụ PostgreSQL không khởi động được, không thể khôi phục dữ liệu."
                cd - >/dev/null
                exit 1
            fi
        else
            print_info "Docker compose không chứa dịch vụ postgres, bỏ qua khôi phục dữ liệu."
        fi
        
        cd - >/dev/null
    else
        print_warning "Không tìm thấy docker-compose.yml, không thể khôi phục dữ liệu PostgreSQL."
    fi
fi

# Khôi phục dữ liệu Storage nếu có
if [[ -d "$BACKUP_DIR/storage-data" ]]; then
    STORAGE_CONTAINER=$(docker ps -q -f name=storage)
    if [[ -n "$STORAGE_CONTAINER" ]]; then
        print_info "Đang khôi phục dữ liệu Storage..."
        
        # Sao chép dữ liệu vào container storage
        if docker cp "$BACKUP_DIR/storage-data/." "$STORAGE_CONTAINER:/var/lib/storage-api" 2>/dev/null; then
            print_success "Dữ liệu Storage đã được khôi phục."
        else
            print_warning "Không thể khôi phục dữ liệu Storage"
        fi
    else
        print_info "Không tìm thấy container storage đang chạy, bỏ qua khôi phục dữ liệu."
    fi
fi

print_success "Khôi phục hoàn tất!"
print_info "Đường dẫn thư mục đích: $TARGET_DIR"

# Đề xuất khởi động lại dịch vụ
print_info "Để khởi động dịch vụ, hãy chạy:"
echo "  cd $TARGET_DIR"
echo "  docker compose up -d"