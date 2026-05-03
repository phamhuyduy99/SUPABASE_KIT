#!/bin/bash
# Script để sao lưu cấu hình của Supabase Kit

BACKUP_NAME="supabase-kit-backup-$(date +%Y%m%d_%H%M%S).tar.gz"

echo "==========================================="
echo "SAO LƯU CẤU HÌNH SUPABASE KIT"
echo "==========================================="
echo "Tên file backup: $BACKUP_NAME"
echo ""

read -p "Bạn có muốn tiếp tục? (y/N): " confirm
if [[ "$confirm" =~ ^[Yy]$ ]]; then
    tar -czf "$BACKUP_NAME" \
        --exclude='*.tar.gz' \
        --exclude='*.zip' \
        linux/ windows/ docs/ \
        README.md README-WINDOWS.md README-MACOS.md \
        setup-permissions.sh initialize-kit.sh check-completeness.sh backup-config.sh
    
    if [ $? -eq 0 ]; then
        echo "✓ Backup đã được tạo thành công: $BACKUP_NAME"
        echo "Dung lượng file: $(du -h "$BACKUP_NAME" | cut -f1)"
    else
        echo "✗ Lỗi khi tạo backup"
        exit 1
    fi
else
    echo "Hủy bỏ thao tác backup."
fi