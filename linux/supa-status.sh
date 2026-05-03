#!/bin/bash
# supabase-kit/linux/supa-status.sh
# Script để kiểm tra trạng thái hệ thống Supabase

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

print_title "SUPABASE STATUS (KIỂM TRA TRẠNG THÁI)"

print_info "Đang kiểm tra các thành phần hệ thống..."

# Kiểm tra hệ điều hành
print_info "Hệ điều hành: $(uname -srm)"

# Kiểm tra phiên bản Docker
if command -v docker &>/dev/null; then
    print_success "Docker version: $(docker --version)"
else
    print_error "Docker chưa được cài đặt!"
fi

# Kiểm tra Docker Compose
if command -v docker compose &>/dev/null; then
    print_success "Docker Compose đã được cài đặt."
elif command -v docker-compose &>/dev/null; then
    print_success "Docker Compose (dạng plugin) đã được cài đặt."
else
    print_error "Docker Compose chưa được cài đặt!"
fi

# Kiểm tra các dịch vụ hệ thống
print_info "Kiểm tra các dịch vụ đang chạy..."
if docker ps -q &>/dev/null && [ "$(docker ps -q | wc -l)" -gt 0 ]; then
    running_containers=$(docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | tail -n +2)
    if [ -n "$running_containers" ]; then
        print_success "Các container đang chạy:"
        echo "$running_containers" | while read -r line; do
            echo "  $line"
        done
    else
        print_info "Hiện không có container nào đang chạy."
    fi
else
    print_info "Docker daemon có thể chưa chạy hoặc không có container nào."
fi

# Kiểm tra trạng thái Supabase cụ thể
check_supabase_status

# Kiểm tra thư mục hiện tại có phải là dự án Supabase không
print_info "Kiểm tra thư mục hiện tại..."
current_dir=$(pwd)
if check_supabase_dir "$current_dir"; then
    print_success "Thư mục hiện tại là dự án Supabase hợp lệ."
    
    # Kiểm tra trạng thái compose trong thư mục này
    if [[ -f "./docker-compose.yml" ]]; then
        print_info "Docker Compose services:"
        docker compose ps 2>/dev/null || echo "Không thể truy cập docker compose (có thể chưa chạy hoặc không có quyền)"
    fi
else
    print_warning "Thư mục hiện tại không phải là dự án Supabase hợp lệ."
fi

print_info "Kiểm tra hoàn tất!"