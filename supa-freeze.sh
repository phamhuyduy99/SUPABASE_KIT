#!/bin/bash
# ==============================================
# SUPA-FREEZE.SH – Sao lưu toàn bộ Supabase + bộ kit
# -------------------------------------------------
# Tạo file backup .tar.gz chứa:
#   - Toàn bộ script của bộ kit (tự chạy sau giải nén)
#   - Dữ liệu backup (database, storage, cấu hình) trong backup_data/
# Tích hợp upload Google Drive nếu cần,
# kiểm tra dung lượng ổ đĩa trước khi backup,
# xử lý trường hợp thiếu sudo khi cần cài rsync.
# Bỏ qua thư mục db/data khi backup volumes để tránh lỗi permission.
# Tự động hướng dẫn thiết lập SSH key cho đồng bộ.
# ==============================================

# KHÔNG dùng set -e để tránh script dừng đột ngột khi có lỗi nhỏ
# set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# ---------- MÀU SẮC ----------
# Định nghĩa màu nếu chưa có từ common.sh để đảm bảo hiển thị đúng
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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

log_info "Bắt đầu backup Supabase tại $PROJECT_DIR"
echo -e "${BOLD}${CYAN}======================================${NC}"
echo -e "${BOLD}${CYAN}  🧊 ĐÓNG BĂNG HỆ THỐNG SUPABASE${NC}"
echo -e "${BOLD}${CYAN}======================================${NC}"
echo -e "Thư mục dự án: ${MAGENTA}$PROJECT_DIR${NC}"

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
log_info "Container database: $DB_CONT"
echo "📌 Container database: $DB_CONT"

# ------------------------------------------------------------
# 2. Hỏi thông tin đồng bộ từ xa (nếu muốn)
# ------------------------------------------------------------
read -p "Nhập user@IP của VPS dự phòng (Enter nếu không đồng bộ): " REMOTE
if [ -n "$REMOTE" ] && ! command -v rsync &> /dev/null; then
    echo "📦 Cần cài đặt rsync để đồng bộ."
    if ! sudo -n true 2>/dev/null; then
        echo -e "${YELLOW}Bạn không có quyền sudo, không thể tự động cài rsync.${NC}"
        echo "   Bạn có thể nhờ quản trị viên cài giúp: sudo apt install -y rsync"
        echo "   Hoặc bỏ qua đồng bộ từ xa lần này."
        read -p "Nhấn Enter để tiếp tục (sẽ bỏ qua đồng bộ)..." dummy
        REMOTE=""
    else
        wait_for_apt_lock || exit 1
        sudo apt install -y rsync
        echo ""   # Thêm dòng này để tách biệt output
    fi
fi

# ------------------------------------------------------------
# 3. Hỏi upload lên Google Drive (nếu muốn) – logic mới
# ------------------------------------------------------------
UPLOAD_DRIVE="n"
if command -v rclone &> /dev/null && rclone listremotes | grep -q "^gdrive:"; then
    read -p "📤 Upload backup lên Google Drive? (y/n): " UPLOAD_DRIVE
else
    if [[ "$1" != "--cron" ]]; then
        echo -e "${YELLOW}📤 Bạn có muốn upload backup lên Google Drive không?${NC}"
        echo "   (Yêu cầu cấu hình rclone một lần duy nhất)"
        read -p "   Lựa chọn (y/n): " UPLOAD_DRIVE
        if [ "$UPLOAD_DRIVE" = "y" ]; then
            if ! command -v rclone &> /dev/null; then
                ensure_rclone_gdrive || UPLOAD_DRIVE="n"
            fi
            if [ "$UPLOAD_DRIVE" = "y" ] && ! rclone listremotes | grep -q "^gdrive:"; then
                echo -e "${YELLOW}⚠️ Remote 'gdrive' chưa được cấu hình.${NC}"
                read -p "Bạn có muốn chạy trình cấu hình Google Drive ngay bây giờ không? (y/n): " setup_gdrive
                if [ "$setup_gdrive" = "y" ]; then
                    bash "$SCRIPT_DIR/supa-setup-gdrive.sh"
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
# 4. Chuẩn bị thư mục gốc cho backup (sẽ trở thành bộ kit)
# ------------------------------------------------------------
PACK_NAME="supabase-backup-$(date +%Y%m%d_%H%M%S)"
BACKUP_FILE="$PROJECT_DIR/${PACK_NAME}.tar.gz"
TMP_ROOT=$(mktemp -d)

# Thêm trap cleanup để dọn dẹp thư mục tạm khi thoát hoặc bị ngắt
trap 'echo -e "${YELLOW}🧹 Dọn dẹp thư mục tạm...${NC}"; rm -rf "$TMP_ROOT"' EXIT INT TERM

PACK_DIR="$TMP_ROOT/$PACK_NAME"
mkdir -p "$PACK_DIR/backup_data"/{config,database,storage,volumes}

echo -e "📁 Chuẩn bị gói backup tự hành: ${MAGENTA}$PACK_NAME${NC}"

# ------------------------------------------------------------
# 5. Copy toàn bộ script của kit vào gốc gói backup
# ------------------------------------------------------------
cp "$SCRIPT_DIR"/supa-*.sh "$PACK_DIR/" 2>/dev/null
cp "$SCRIPT_DIR"/common.sh "$PACK_DIR/" 2>/dev/null
[ -f "$SCRIPT_DIR/README.txt" ] && cp "$SCRIPT_DIR/README.txt" "$PACK_DIR/"

# ------------------------------------------------------------
# 6. Sao lưu cấu hình (bỏ qua db/data để tránh lỗi permission)
# ------------------------------------------------------------
echo -e "${BOLD}1/4 Sao lưu cấu hình...${NC}"
cp "$PROJECT_DIR/.env" "$PACK_DIR/backup_data/config/" || { echo -e "${RED}❌ Không thể copy .env.${NC}"; exit 1; }
cp "$PROJECT_DIR/docker-compose.yml" "$PACK_DIR/backup_data/config/"

if [ -d "$PROJECT_DIR/volumes" ]; then
    echo -e "${BOLD}   Đang sao lưu thư mục volumes (bỏ qua db/data và logs)...${NC}"
    VOL_ERR_LOG="/tmp/vol_copy_err_$$.log"
    # Copy tất cả thư mục con (trừ db và logs)
    find "$PROJECT_DIR/volumes" -mindepth 1 -maxdepth 1 ! -name 'db' ! -name 'logs' -exec cp -r {} "$PACK_DIR/backup_data/volumes/" \; 2>"$VOL_ERR_LOG"
    # Xử lý riêng db/init nếu có
    if [ -d "$PROJECT_DIR/volumes/db/init" ]; then
        mkdir -p "$PACK_DIR/backup_data/volumes/db"
        cp -r "$PROJECT_DIR/volumes/db/init" "$PACK_DIR/backup_data/volumes/db/" 2>>"$VOL_ERR_LOG"
    fi
    if [ -s "$VOL_ERR_LOG" ]; then
        echo -e "${YELLOW}⚠️ Một số file không thể sao lưu (chi tiết trong $VOL_ERR_LOG):${NC}"
        cat "$VOL_ERR_LOG"
    else
        echo -e "${GREEN}   ✅ Volumes đã được sao lưu đầy đủ.${NC}"
    fi
    rm -f "$VOL_ERR_LOG"
else
    echo -e "${YELLOW}⚠️ Không tìm thấy thư mục volumes. Bỏ qua.${NC}"
fi

# ------------------------------------------------------------
# 7. Sao lưu database (thêm pipefail để bắt lỗi trong pipeline)
# ------------------------------------------------------------
echo -e "${BOLD}2/4 Sao lưu database...${NC}"
set -o pipefail
if docker exec -t $DB_CONT pg_dumpall -U postgres -c | gzip > "$PACK_DIR/backup_data/database/full_backup.sql.gz"; then
    echo -e "   -> Database đã được dump thành công."
else
    echo -e "${RED}❌ Có lỗi khi dump database (kiểm tra kết nối hoặc dung lượng).${NC}"
    # Trap sẽ xử lý việc xóa TMP_ROOT, nhưng exit ngay để tránh các bước sau
    exit 1
fi
set +o pipefail

# ------------------------------------------------------------
# 8. Sao lưu storage
# ------------------------------------------------------------
echo -e "${BOLD}3/4 Sao lưu storage...${NC}"
STORAGE_VOL=$(docker volume ls -q | grep _storage)
if [ -n "$STORAGE_VOL" ]; then
    docker run --rm -v $STORAGE_VOL:/mnt/storage:ro -v "$PACK_DIR/backup_data/storage:/backup" alpine \
    sh -c "cd /mnt/storage && tar czf /backup/storage.tar.gz ."
    echo "   -> Storage (Docker volume) đã được backup."
else
    if [ -d "$PROJECT_DIR/volumes/storage" ]; then
        tar czf "$PACK_DIR/backup_data/storage/storage.tar.gz" -C "$PROJECT_DIR/volumes/storage" .
        echo "   -> Storage (bind mount) đã được backup."
    else
        echo -e "${YELLOW}⚠️ Không tìm thấy volume hoặc thư mục storage. Bỏ qua.${NC}"
    fi
fi

# ------------------------------------------------------------
# 9. Nén toàn bộ thư mục PACK_NAME thành file .tar.gz
# ------------------------------------------------------------
echo -e "${BOLD}4/4 Đóng gói...${NC}"
cd "$TMP_ROOT"
tar czf "$BACKUP_FILE" "$PACK_NAME"
rm -rf "$TMP_ROOT"
echo -e "${GREEN}✅ Backup thành công: $BACKUP_FILE${NC}"
log_info "Backup thành công: $BACKUP_FILE"

# ------------------------------------------------------------
# 10. Đồng bộ sang VPS dự phòng (tự động hóa SSH key, hướng dẫn chi tiết)
# ------------------------------------------------------------
if [ -n "$REMOTE" ]; then
    echo -e "${CYAN}☁️ Đồng bộ sang $REMOTE...${NC}"

    # ---------- Tạo SSH key nếu chưa có ----------
    if [ ! -f ~/.ssh/id_rsa ]; then
        echo -e "${YELLOW}🔑 Chưa có SSH key. Đang tạo cặp key mới...${NC}"
        mkdir -p ~/.ssh
        chmod 700 ~/.ssh
        ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N "" -q
        echo -e "${GREEN}✅ Đã tạo SSH key tại ~/.ssh/id_rsa${NC}"
    fi

    # ---------- Yêu cầu copy public key sang VPS đích ----------
    echo -e "${CYAN}👉 Để đồng bộ không cần mật khẩu, bạn cần copy public key sang VPS đích.${NC}"
    echo "   Có 2 cách:"
    echo "   1. (Tự động) Để script này tự copy giúp bạn (sẽ hỏi mật khẩu VPS đích MỘT LẦN)."
    echo "   2. (Thủ công) Bạn tự copy bằng lệnh hoặc thêm vào file authorized_keys."
    echo ""
    read -p "   Bạn muốn script tự copy giúp không? (y/n): " auto_copy_ssh
    if [ "$auto_copy_ssh" = "y" ]; then
        echo -e "${CYAN}   Đang copy public key sang $REMOTE...${NC}"
        echo "   Bạn hãy nhập MẬT KHẨU của VPS đích khi được hỏi."
        if command -v ssh-copy-id >/dev/null 2>&1; then
            if ssh-copy-id -i ~/.ssh/id_rsa.pub "$REMOTE" 2>/dev/null; then
                echo -e "${GREEN}   ✅ Copy thành công! Từ lần sau sẽ không cần mật khẩu nữa.${NC}"
            else
                echo -e "${YELLOW}   ⚠️ Không thể copy tự động (có thể do chưa có ssh-copy-id hoặc sai mật khẩu).${NC}"
                echo "   Bạn hãy làm thủ công theo hướng dẫn bên dưới..."
            fi
        else
            echo -e "${YELLOW}   ⚠️ ssh-copy-id không khả dụng trên hệ thống này.${NC}"
            echo "   Bạn hãy làm thủ công theo hướng dẫn bên dưới..."
        fi
    fi

    # ---------- Kiểm tra kết nối SSH và tạo thư mục từ xa ----------
    echo -e "${CYAN}   Kiểm tra kết nối SSH tới $REMOTE...${NC}"
    if ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 "${REMOTE}" 'mkdir -p ~/backups && echo "OK"' >/dev/null 2>&1; then
        echo -e "${GREEN}   ✅ Kết nối SSH thành công, đã tạo thư mục ~/backups trên VPS đích.${NC}"
        SSH_OK=1
    else
        echo -e "${YELLOW}   ⚠️ Không thể kết nối SSH tới $REMOTE.${NC}"
        echo "   Rất có thể public key của bạn chưa được copy sang VPS đích."
        echo "   Hãy thực hiện MỘT TRONG CÁC CÁCH SAU:"
        echo ""
        echo "   CÁCH 1 (đơn giản nhất): Chạy lệnh này trên máy hiện tại:"
        echo "     ssh-copy-id -i ~/.ssh/id_rsa.pub $REMOTE"
        echo "     (Bạn sẽ được hỏi mật khẩu của VPS đích một lần)"
        echo ""
        echo "   CÁCH 2: Tự thêm public key thủ công:"
        echo "     1. Copy nội dung public key của bạn (giữa hai dòng ===):"
        echo "        ========================================"
        cat ~/.ssh/id_rsa.pub 2>/dev/null || echo "        (Không tìm thấy public key)"
        echo "        ========================================"
        echo "     2. SSH vào VPS đích (bằng mật khẩu):"
        echo "        ssh $REMOTE"
        echo "     3. Mở file authorized_keys:"
        echo "        nano ~/.ssh/authorized_keys"
        echo "     4. Dán nội dung public key ở trên vào cuối file, lưu và thoát."
        echo "     5. Thoát SSH và thử lại đồng bộ."
        echo ""
        echo "   Sau khi thực hiện xong, bạn có thể chạy lại chức năng Backup để đồng bộ."
        SSH_OK=0
    fi

    # ---------- Thực hiện rsync nếu kết nối OK ----------
    if [ $SSH_OK -eq 1 ]; then
        echo -e "${CYAN}   Đang đồng bộ file backup...${NC}"
        if rsync -avz -e "ssh -o StrictHostKeyChecking=accept-new" "$BACKUP_FILE" "${REMOTE}:~/backups/"; then
            echo -e "${GREEN}✅ Đồng bộ thành công! File backup đã ở VPS đích: ~/backups/$(basename "$BACKUP_FILE")${NC}"
            log_info "Đồng bộ thành công tới $REMOTE"
        else
            echo -e "${RED}❌ Đồng bộ thất bại dù SSH đã kết nối được.${NC}"
            echo "   Kiểm tra dung lượng ổ đĩa và quyền ghi trên VPS đích."
            log_error "Đồng bộ thất bại tới $REMOTE dù SSH đã kết nối"
        fi
    else
        echo -e "${YELLOW}   Bỏ qua đồng bộ vì chưa kết nối được SSH.${NC}"
        echo "   Bạn vẫn có thể chạy lại chức năng Backup sau khi đã thiết lập SSH key."
        log_warn "Bỏ qua đồng bộ vì chưa kết nối được SSH"
    fi
fi

# ------------------------------------------------------------
# 11. Upload lên Google Drive (nếu được chọn và đã có remote)
# ------------------------------------------------------------
if [ "$UPLOAD_DRIVE" = "y" ] && rclone listremotes | grep -q "^gdrive:"; then
    echo "📤 Upload lên Google Drive..."
    upload_to_gdrive "$BACKUP_FILE"
    log_info "Upload Google Drive thành công: $BACKUP_FILE"
fi

# ------------------------------------------------------------
# 12. Hỏi cài cron tự động (trừ khi chạy với --cron)
# ------------------------------------------------------------
if [[ "$1" != "--cron" ]]; then
    read -p "⏰ Bạn có muốn tự động backup hàng ngày lúc 2h sáng? (y/n): " ans
    if [ "$ans" = "y" ]; then
        SCRIPT_PATH="$SCRIPT_DIR/supa-freeze.sh"
        # Đảm bảo đường dẫn tuyệt đối cho cron
        if [[ "$SCRIPT_PATH" != /* ]]; then
            SCRIPT_PATH="$(cd "$SCRIPT_DIR" && pwd)/supa-freeze.sh"
        fi
        CRON_LINE="0 2 * * * $SCRIPT_PATH --cron $PROJECT_DIR"
        (crontab -l 2>/dev/null; echo "$CRON_LINE") | sort -u | crontab -
        echo -e "${GREEN}✅ Cron job đã được thêm. Hệ thống sẽ tự động backup lúc 2h sáng mỗi ngày.${NC}"
        log_info "Đã thêm cron job backup hàng ngày"
    fi
fi

# ------------------------------------------------------------
# 13. Sinh checksum
# ------------------------------------------------------------
if [ -f "$BACKUP_FILE" ]; then
    sha256sum "$BACKUP_FILE" > "${BACKUP_FILE}.sha256"
    echo -e "📋 Checksum đã được tạo: ${BACKUP_FILE}.sha256"
fi