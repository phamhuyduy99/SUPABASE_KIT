#!/bin/bash
# ==============================================
# SUPA-FREEZE.SH – Sao lưu toàn bộ Supabase
# -------------------------------------------------
# Tích hợp upload Google Drive nếu cần,
# kiểm tra dung lượng ổ đĩa trước khi backup,
# xử lý trường hợp thiếu sudo khi cần cài rsync.
# ==============================================

# KHÔNG dùng set -e để tránh script dừng đột ngột khi có lỗi nhỏ
# set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Xác định PROJECT_DIR: ưu tiên tham số, sau đó tự dò, cuối cùng hỏi người dùng
if [ -n "$1" ] && [ "$1" != "--cron" ]; then
    PROJECT_DIR="$1"
elif validate_supabase_dir "$SCRIPT_DIR"; then
    PROJECT_DIR="$SCRIPT_DIR"
else
    PROJECT_DIR=$(auto_find_supabase_dir "$SCRIPT_DIR")
    if [ -z "$PROJECT_DIR" ]; then
        echo -e "${YELLOW}Không tìm thấy thư mục dự án tự động.${NC}"
        PROJECT_DIR=$(input_supabase_dir)
    fi
fi

echo "======================================"
echo "  🧊 ĐÓNG BĂNG HỆ THỐNG SUPABASE"
echo "======================================"
echo "Thư mục dự án: $PROJECT_DIR"

# ------------------------------------------------------------
# 0. Kiểm tra dung lượng đĩa trước khi backup (cần ~500MB)
# ------------------------------------------------------------
if ! check_disk_space 500 "$PROJECT_DIR"; then
    exit 1
fi

# ------------------------------------------------------------
# 1. Kiểm tra container database đang chạy
# ------------------------------------------------------------
DB_CONT=$(docker ps --format '{{.Names}}' | grep -E 'supabase.*db|db' | head -1)
if [ -z "$DB_CONT" ]; then
    echo -e "${RED}❌ Không tìm thấy container database đang chạy.${NC}"
    echo "Vui lòng khởi động Supabase trước khi backup."
    exit 1
fi
echo "📌 Container database: $DB_CONT"

# ------------------------------------------------------------
# 2. Hỏi thông tin đồng bộ từ xa (nếu muốn)
# ------------------------------------------------------------
read -p "Nhập user@IP của VPS dự phòng (Enter nếu không đồng bộ): " REMOTE
if [ -n "$REMOTE" ] && ! command -v rsync &> /dev/null; then
    echo "📦 Cần cài đặt rsync để đồng bộ."
    # Kiểm tra sudo: nếu không có sudo, không thể cài, thông báo và bỏ qua đồng bộ
    if ! sudo -n true 2>/dev/null; then
        echo -e "${YELLOW}Bạn không có quyền sudo, không thể tự động cài rsync.${NC}"
        echo "   Bạn có thể nhờ quản trị viên cài giúp: sudo apt install -y rsync"
        echo "   Hoặc bỏ qua đồng bộ từ xa lần này."
        read -p "Nhấn Enter để tiếp tục (sẽ bỏ qua đồng bộ)..." dummy
        REMOTE=""   # Đặt lại để không đồng bộ
    else
        wait_for_apt_lock || exit 1
        sudo apt install -y rsync
    fi
fi

# ------------------------------------------------------------
# 3. Hỏi upload lên Google Drive (nếu muốn) – logic mới
# ------------------------------------------------------------
UPLOAD_DRIVE="n"
# Nếu rclone đã có và có remote gdrive, hỏi trực tiếp
if command -v rclone &> /dev/null && rclone listremotes | grep -q "^gdrive:"; then
    read -p "📤 Upload backup lên Google Drive? (y/n): " UPLOAD_DRIVE
else
    # Nếu chưa có rclone hoặc remote, hỏi có muốn cấu hình không
    if [[ "$1" != "--cron" ]]; then
        echo -e "${YELLOW}📤 Bạn có muốn upload backup lên Google Drive không?${NC}"
        echo "   (Yêu cầu cấu hình rclone một lần duy nhất)"
        read -p "   Lựa chọn (y/n): " UPLOAD_DRIVE
        if [ "$UPLOAD_DRIVE" = "y" ]; then
            # Nếu chưa có rclone, cài đặt
            if ! command -v rclone &> /dev/null; then
                ensure_rclone_gdrive || UPLOAD_DRIVE="n"
            fi
            # Nếu đã có rclone nhưng chưa có remote gdrive, gợi ý cấu hình
            if [ "$UPLOAD_DRIVE" = "y" ] && ! rclone listremotes | grep -q "^gdrive:"; then
                echo -e "${YELLOW}⚠️ Remote 'gdrive' chưa được cấu hình.${NC}"
                read -p "Bạn có muốn chạy trình cấu hình Google Drive ngay bây giờ không? (y/n): " setup_gdrive
                if [ "$setup_gdrive" = "y" ]; then
                    bash "$SCRIPT_DIR/supa-setup-gdrive.sh"
                    # Sau khi cấu hình xong, kiểm tra lại xem đã có remote chưa
                    if rclone listremotes | grep -q "^gdrive:"; then
                        echo -e "${GREEN}✅ Đã cấu hình Google Drive thành công.${NC}"
                    else
                        echo -e "${RED}❌ Cấu hình không thành công, sẽ bỏ qua upload.${NC}"
                        UPLOAD_DRIVE="n"
                    fi
                else
                    echo "Bỏ qua upload Google Drive."
                    UPLOAD_DRIVE="n"
                fi
            fi
        fi
    fi
fi

# ------------------------------------------------------------
# 4. Chuẩn bị thư mục tạm và đặt tên file backup
# ------------------------------------------------------------
BACKUP_FILE="$PROJECT_DIR/supabase-backup-$(date +%Y%m%d_%H%M%S).tar.gz"
TMP=$(mktemp -d)
mkdir -p $TMP/{config,database,storage,scripts}
echo "📁 Bắt đầu sao lưu..."

# ------------------------------------------------------------
# 5. Sao lưu cấu hình
# ------------------------------------------------------------
echo "1/4 Sao lưu cấu hình..."
cp "$PROJECT_DIR/.env" "$TMP/config/" || { echo -e "${RED}❌ Không thể copy .env. Kiểm tra quyền đọc.${NC}"; exit 1; }
cp "$PROJECT_DIR/docker-compose.yml" "$TMP/config/"
[ -d "$PROJECT_DIR/volumes" ] && cp -r "$PROJECT_DIR/volumes" "$TMP/config/"

# ------------------------------------------------------------
# 6. Sao lưu database (pg_dumpall để bao gồm cả roles)
# ------------------------------------------------------------
echo "2/4 Sao lưu database..."
if docker exec -t $DB_CONT pg_dumpall -U postgres -c | gzip > "$TMP/database/full_backup.sql.gz"; then
    echo "   -> Database đã được dump thành công."
else
    echo -e "${RED}❌ Có lỗi khi dump database. Kiểm tra kết nối.${NC}"
    rm -rf "$TMP"
    exit 1
fi

# ------------------------------------------------------------
# 7. Sao lưu storage
# ------------------------------------------------------------
echo "3/4 Sao lưu storage..."
STORAGE_VOL=$(docker volume ls -q | grep _storage)
if [ -n "$STORAGE_VOL" ]; then
    docker run --rm -v $STORAGE_VOL:/mnt/storage:ro -v $TMP/storage:/backup alpine \
        sh -c "cd /mnt/storage && tar czf /backup/storage.tar.gz ."
    echo "   -> Storage (Docker volume) đã được backup."
else
    # Thử bind mount
    if [ -d "$PROJECT_DIR/volumes/storage" ]; then
        tar czf "$TMP/storage/storage.tar.gz" -C "$PROJECT_DIR/volumes/storage" .
        echo "   -> Storage (bind mount) đã được backup."
    else
        echo -e "${YELLOW}⚠️ Không tìm thấy volume hoặc thư mục storage. Bỏ qua.${NC}"
    fi
fi

# ------------------------------------------------------------
# 8. Tự copy script kit vào backup (để sau này restore có thể dùng lại)
# ------------------------------------------------------------
cp "$SCRIPT_DIR"/supa-*.sh "$TMP/scripts/" 2>/dev/null
cp "$SCRIPT_DIR"/common.sh "$TMP/scripts/" 2>/dev/null
[ -f "$SCRIPT_DIR/README.txt" ] && cp "$SCRIPT_DIR/README.txt" "$TMP/scripts/"

# ------------------------------------------------------------
# 9. Đóng gói thành file .tar.gz
# ------------------------------------------------------------
echo "4/4 Đóng gói..."
tar czf "$BACKUP_FILE" -C "$TMP" .
rm -rf "$TMP"
echo -e "${GREEN}✅ Backup thành công: $BACKUP_FILE${NC}"

# ------------------------------------------------------------
# 10. Đồng bộ sang VPS dự phòng (nếu có)
# ------------------------------------------------------------
if [ -n "$REMOTE" ]; then
    echo "☁️ Đồng bộ sang $REMOTE..."
    rsync -avz -e "ssh -o StrictHostKeyChecking=no" "$BACKUP_FILE" "${REMOTE}:/home/ubuntu/backups/" || \
        echo -e "${RED}❌ Đồng bộ thất bại. Kiểm tra SSH key và kết nối.${NC}"
fi

# ------------------------------------------------------------
# 11. Upload lên Google Drive (nếu được chọn và đã có remote)
# ------------------------------------------------------------
if [ "$UPLOAD_DRIVE" = "y" ] && rclone listremotes | grep -q "^gdrive:"; then
    echo "📤 Upload lên Google Drive..."
    upload_to_gdrive "$BACKUP_FILE"
fi

# ------------------------------------------------------------
# 12. Hỏi cài cron tự động (trừ khi chạy với --cron)
# ------------------------------------------------------------
if [[ "$1" != "--cron" ]]; then
    read -p "⏰ Bạn có muốn tự động backup hàng ngày lúc 2h sáng? (y/n): " ans
    if [ "$ans" = "y" ]; then
        SCRIPT_PATH=$(realpath "$0")
        CRON_LINE="0 2 * * * $SCRIPT_PATH --cron $PROJECT_DIR"
        (crontab -l 2>/dev/null; echo "$CRON_LINE") | sort -u | crontab -
        echo -e "${GREEN}✅ Cron job đã được thêm. Hệ thống sẽ tự động backup lúc 2h sáng mỗi ngày.${NC}"
    fi
fi