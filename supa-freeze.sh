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
        echo -e "${BOLD_YELLOW}Không tìm thấy thư mục dự án tự động.${NC}"
        PROJECT_DIR=$(input_supabase_dir)
    fi
fi

log_info "Bắt đầu backup Supabase tại $PROJECT_DIR"
echo -e "${BOLD_BLUE}======================================${NC}"
echo -e "${BOLD_BLUE}  🧊 ĐÓNG BĂNG HỆ THỐNG SUPABASE${NC}"
echo -e "${BOLD_BLUE}======================================${NC}"
echo -e "Thư mục dự án: ${BOLD_CYAN}$PROJECT_DIR${NC}"

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
    echo -e "${BOLD_RED}❌ Không tìm thấy container database đang chạy.${NC}"
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
        echo -e "${BOLD_YELLOW}Bạn không có quyền sudo, không thể tự động cài rsync.${NC}"
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
        echo -e "${BOLD_YELLOW}📤 Bạn có muốn upload backup lên Google Drive không?${NC}"
        echo "   (Yêu cầu cấu hình rclone một lần duy nhất)"
        read -p "   Lựa chọn (y/n): " UPLOAD_DRIVE
        if [ "$UPLOAD_DRIVE" = "y" ]; then
            if ! command -v rclone &> /dev/null; then
                ensure_rclone_gdrive || UPLOAD_DRIVE="n"
            fi
            if [ "$UPLOAD_DRIVE" = "y" ] && ! rclone listremotes | grep -q "^gdrive:"; then
                echo -e "${BOLD_YELLOW}⚠️ Remote 'gdrive' chưa được cấu hình.${NC}"
                read -p "Bạn có muốn chạy trình cấu hình Google Drive ngay bây giờ không? (y/n): " setup_gdrive
                if [ "$setup_gdrive" = "y" ]; then
                    bash "$SCRIPT_DIR/supa-setup-gdrive.sh"
                    if rclone listremotes | grep -q "^gdrive:"; then
                        echo -e "${BOLD_GREEN}✅ Đã cấu hình Google Drive thành công.${NC}"
                    else
                        echo -e "${BOLD_RED}❌ Cấu hình không thành công, sẽ bỏ qua upload.${NC}"
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
trap 'echo -e "${BOLD_YELLOW}🧹 Dọn dẹp thư mục tạm...${NC}"; rm -rf "$TMP_ROOT"' EXIT INT TERM

PACK_DIR="$TMP_ROOT/$PACK_NAME"
mkdir -p "$PACK_DIR/backup_data"/{config,database,storage,volumes}

echo -e "📁 Chuẩn bị gói backup tự hành: ${BOLD_MAGENTA}$PACK_NAME${NC}"

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
if ! cp "$PROJECT_DIR/.env" "$PACK_DIR/backup_data/config/"; then
    echo -e "${BOLD_RED}❌ Không thể copy .env.${NC}"
    exit 1
fi
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
        echo -e "${BOLD_YELLOW}⚠️ Một số file không thể sao lưu (chi tiết trong $VOL_ERR_LOG):${NC}"
        cat "$VOL_ERR_LOG"
    else
        echo -e "${BOLD_GREEN}   ✅ Volumes đã được sao lưu đầy đủ.${NC}"
    fi
    rm -f "$VOL_ERR_LOG"
else
    echo -e "${BOLD_YELLOW}⚠️ Không tìm thấy thư mục volumes. Bỏ qua.${NC}"
fi

# ------------------------------------------------------------
# 7. Backup database
# ------------------------------------------------------------
echo "📦 Đang backup database..."
BACKUP_DB_FILE="$BACKUP_DATA_DIR/database/full_backup.sql.gz"
mkdir -p "$(dirname "$BACKUP_DB_FILE")"
if ! docker exec "$DB_CONT" pg_dumpall -U postgres | gzip > "$BACKUP_DB_FILE"; then
    echo -e "${BOLD_RED}❌ Có lỗi khi dump database...${NC}"
    echo "   Vui lòng kiểm tra trạng thái container và thử lại."
    rm -rf "$BACKUP_DATA_DIR"
    exit 1
fi
echo -e "${BOLD_GREEN}✅ Database đã được backup.${NC}"

# ------------------------------------------------------------
# 8. Backup storage
# ------------------------------------------------------------
echo "📦 Đang backup storage..."
BACKUP_STORAGE_FILE="$BACKUP_DATA_DIR/storage/storage.tar.gz"
mkdir -p "$(dirname "$BACKUP_STORAGE_FILE")"
STORAGE_VOL=$(docker volume ls -q | grep _storage)
if [ -n "$STORAGE_VOL" ]; then
    docker run --rm -v $STORAGE_VOL:/mnt/storage:ro -v "$BACKUP_DATA_DIR/storage:/backup" alpine \
    sh -c "cd /mnt/storage && tar czf /backup/storage.tar.gz ."
    echo "   -> Storage (Docker volume) đã được backup."
else
    if [ -d "$PROJECT_DIR/volumes/storage" ]; then
        tar czf "$BACKUP_STORAGE_FILE" -C "$PROJECT_DIR/volumes/storage" .
        echo "   -> Storage (bind mount) đã được backup."
    else
        echo -e "${BOLD_YELLOW}⚠️ Không tìm thấy volume hoặc thư mục storage. Bỏ qua.${NC}"
    fi
fi

# ------------------------------------------------------------
# 9. Tạo file .tar.gz hoàn chỉnh
# ------------------------------------------------------------
echo "📦 Đang tạo file backup hoàn chỉnh..."
cd "$SCRIPT_DIR"
if tar czf "$BACKUP_FILE" --exclude='backup_data.tar.gz' --exclude='.git' *; then
    echo -e "${BOLD_GREEN}✅ Backup thành công: ${BACKUP_FILE}${NC}"
    log_info "Backup hoàn tất: $BACKUP_FILE"
else
    echo -e "${BOLD_RED}❌ Tạo file backup thất bại.${NC}"
    exit 1
fi

# ------------------------------------------------------------
# 10. Đồng bộ sang VPS dự phòng (tạo package & gửi cả thư mục)
# ------------------------------------------------------------
if [ -n "$REMOTE" ]; then
    echo -e "${BOLD_CYAN}☁️ Đồng bộ sang $REMOTE...${NC}"

    SSH_OK=0
    REMOTE_HOME=""

    # ---------- Tạo SSH key nếu chưa có ----------
    if [ ! -f ~/.ssh/id_rsa ]; then
        echo -e "${BOLD_YELLOW}🔑 Chưa có SSH key. Đang tạo mới...${NC}"
        ssh-keygen -t rsa -b 4096 -f "$HOME/.ssh/id_rsa" -N ""
        echo -e "${BOLD_GREEN}✅ Đã tạo SSH key mới.${NC}"
        echo -e "${PURPLE}📋 Hướng dẫn thủ công:${NC}"
        echo "   1. Copy nội dung public key sau đây:"
        echo "      $(cat "$HOME/.ssh/id_rsa.pub")"
        echo "   2. Dán vào file ~/.ssh/authorized_keys trên VPS đích."
        echo "   3. Đảm bảo quyền truy cập đúng: chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys"
    fi

    # ---------- Yêu cầu copy public key sang VPS đích ----------
    echo -e "${BOLD_CYAN}👉 Để đồng bộ không cần mật khẩu, bạn cần copy public key sang VPS đích.${NC}"
    echo "   Có 2 cách:"
    echo "   1. (Tự động) Để script này tự copy giúp bạn (sẽ hỏi mật khẩu VPS đích MỘT LẦN)."
    echo "   2. (Thủ công) Bạn tự copy bằng lệnh hoặc thêm vào file authorized_keys."
    echo ""
    read -p "   Bạn muốn script tự copy giúp không? (y/n): " auto_copy_ssh

    if [ "$auto_copy_ssh" = "y" ]; then
        echo -e "${BOLD_CYAN}   Đang copy public key sang $REMOTE...${NC}"
        
        solve_ssh_sync_problem() {
            local strategy=1
            local success=0
            
            while [ $strategy -le 10 ]; do
                if [ "$strategy" -eq 1 ]; then
                    # Chiến lược 1: Tự động tạo SSH key nếu chưa có
                    echo "   🔧 Chiến lược 1/10: Kiểm tra và tạo SSH key nếu cần..."
                    if [ ! -f ~/.ssh/id_rsa ] || [ ! -f ~/.ssh/id_rsa.pub ]; then
                        echo "   ⚠️ SSH key chưa tồn tại."
                        read -p "   👉 Bạn có muốn tạo SSH key mới không? (y/n): " create_key
                        if [ "$create_key" = "y" ]; then
                            ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N "" -C "$REAL_USER@$(hostname)"
                            if [ -f ~/.ssh/id_rsa ] && [ -f ~/.ssh/id_rsa.pub ]; then
                                echo "   ✅ Đã tạo SSH key thành công."
                            else
                                echo "   ❌ Tạo SSH key thất bại."
                            fi
                        fi
                    else
                        echo "   ✅ SSH key đã tồn tại."
                    fi
                elif [ "$strategy" -eq 2 ]; then
                    # Chiến lược 2: Thử copy public key bằng ssh-copy-id với retry
                    echo "   🔧 Chiến lược 2/10: Thử copy public key với retry..."
                    try_count=0
                    max_retries=3
                    while [ $try_count -lt $max_retries ]; do
                        if command -v ssh-copy-id >/dev/null 2>&1; then
                            echo "   🔄 Lần thử thứ $((try_count + 1))..."
                            if ssh-copy-id -i ~/.ssh/id_rsa.pub "$REMOTE" 2>/tmp/ssh_copy_err_$$; then
                                echo "   ✅ Copy thành công!"
                                success=1
                                break 2
                            else
                                try_count=$((try_count + 1))
                                if [ $try_count -lt $max_retries ]; then
                                    echo "   ⚠️ Lần thử $try_count thất bại."
                                    sleep 5
                                fi
                            fi
                        else
                            echo "   ❌ ssh-copy-id không khả dụng."
                            break
                        fi
                    done
                    if [ $success -eq 0 ]; then
                        echo "   ❌ Đã thử $max_retries lần nhưng vẫn thất bại."
                    fi
                elif [ "$strategy" -eq 3 ]; then
                    # Chiến lược 3: Hướng dẫn copy thủ công
                    echo "   🔧 Chiến lược 3/10: Hướng dẫn copy thủ công..."
                    echo "   📋 Public key của bạn:"
                    cat ~/.ssh/id_rsa.pub 2>/dev/null
                    echo ""
                    echo "   📝 Các bước thêm thủ công:"
                    echo "   1. SSH vào VPS đích: ssh $REMOTE"
                    echo "   2. Tạo thư mục .ssh nếu chưa có: mkdir -p ~/.ssh"
                    echo "   3. Thêm public key vào authorized_keys:"
                    echo "      echo 'public_key_của_bạn' >> ~/.ssh/authorized_keys"
                    echo "   4. Đặt quyền đúng: chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys"
                    read -p "   👉 Bạn đã thêm public key thủ công chưa? (y/n): " manual_done
                    if [ "$manual_done" = "y" ]; then
                        echo "   🔄 Đang kiểm tra kết nối SSH..."
                        if ssh -o ConnectTimeout=10 -o BatchMode=yes "$REMOTE" exit 2>/dev/null; then
                            echo "   ✅ Kết nối SSH thành công!"
                            success=1
                            break
                        else
                            echo -e "${BOLD_RED}   ❌ Kết nối SSH vẫn thất bại.${NC}"
                        fi
                    fi
                elif [ "$strategy" -eq 4 ]; then
                    # Chiến lược 4: Kiểm tra kết nối SSH trước khi đồng bộ
                    echo "   🔧 Chiến lược 4/10: Kiểm tra kết nối SSH..."
                    echo "   🔄 Đang kiểm tra kết nối đến $REMOTE (timeout 10s)..."
                    if ssh -o ConnectTimeout=10 -o BatchMode=yes "$REMOTE" exit 2>/dev/null; then
                        echo "   ✅ Kết nối SSH hoạt động bình thường."
                    else
                        echo "   ⚠️ Không thể kết nối SSH đến $REMOTE."
                        echo "   📝 Vui lòng kiểm tra:"
                        echo "   - IP/hostname và username có đúng không"
                        echo "   - Port SSH (mặc định 22) có mở không"
                        echo "   - Firewall có chặn kết nối không"
                        echo "   - Mật khẩu có chính xác không (nếu dùng mật khẩu)"
                        return 1
                    fi
                elif [ "$strategy" -eq 5 ]; then
                    # Chiến lược 5: Thử dùng scp thay vì rsync nếu rsync lỗi
                    echo "   🔧 Chiến lược 5/10: Chuẩn bị sử dụng scp thay thế..."
                    echo "   ℹ️ Trong trường hợp rsync gặp lỗi, script sẽ tự động sử dụng scp."
                    echo "   ✅ Đã cấu hình sẵn phương án dự phòng scp."
                    # Lưu ý: Phần này sẽ được áp dụng khi thực hiện đồng bộ file sau này
                elif [ "$strategy" -eq 6 ]; then
                    # Chiến lược 6: Kiểm tra thư mục đích có tồn tại không
                    echo "   🔧 Chiến lược 6/10: Kiểm tra thư mục đích trên VPS đích..."
                    echo "   🔄 Đang kiểm tra thư mục home trên $REMOTE..."
                    if ssh -o ConnectTimeout=10 "$REMOTE" "[ -d /home/$REAL_USER ] || [ -d /root ]"; then
                        echo "   ✅ Thư mục home tồn tại trên VPS đích."
                    else
                        echo "   ⚠️ Thư mục home không tồn tại, đang tạo..."
                        if ssh -o ConnectTimeout=10 "$REMOTE" "sudo mkdir -p /home/$REAL_USER && sudo chown $REAL_USER:$REAL_USER /home/$REAL_USER"; then
                            echo "   ✅ Đã tạo thư mục home thành công."
                        else
                            echo "   ❌ Không thể tạo thư mục home trên VPS đích."
                            echo "   📝 Vui lòng liên hệ quản trị viên VPS đích để tạo thư mục home."
                            return 1
                        fi
                    fi
                elif [ "$strategy" -eq 7 ]; then
                    # Chiến lược 7: Xử lý lỗi permission thư mục home
                    echo "   🔧 Chiến lược 7/10: Kiểm tra quyền thư mục home..."
                    echo "   🔄 Đang kiểm tra quyền trên VPS đích..."
                    if ssh -o ConnectTimeout=10 "$REMOTE" "[ -w /home/$REAL_USER ]"; then
                        echo "   ✅ Có quyền ghi vào thư mục home."
                    else
                        echo "   ⚠️ Không có quyền ghi vào thư mục home."
                        echo "   📝 Vui lòng chạy lệnh sau trên VPS đích:"
                        echo "   sudo chown -R $REAL_USER:$REAL_USER /home/$REAL_USER"
                        echo "   sudo chmod 700 /home/$REAL_USER"
                        read -p "   👉 Bạn đã sửa quyền thư mục chưa? (y/n): " perm_fixed
                        if [ "$perm_fixed" != "y" ]; then
                            return 1
                        fi
                    fi
                elif [ "$strategy" -eq 8 ]; then
                    # Chiến lược 8: Kiểm tra dung lượng đĩa trên VPS đích
                    echo "   🔧 Chiến lược 8/10: Kiểm tra dung lượng đĩa trên VPS đích..."
                    echo "   🔄 Đang kiểm tra dung lượng trên $REMOTE..."
                    remote_space=$(ssh -o ConnectTimeout=10 "$REMOTE" "df -m /home | tail -1 | awk '{print \$4}'" 2>/dev/null)
                    if [ -n "$remote_space" ] && [ "$remote_space" -gt 1000 ]; then
                        echo "   ✅ Đủ dung lượng trên VPS đích ($remote_space MB trống)."
                    else
                        echo "   ⚠️ Dung lượng trên VPS đích có thể không đủ."
                        echo "   📝 Vui lòng đảm bảo có ít nhất 1GB dung lượng trống trên VPS đích."
                        read -p "   👉 Bạn đã giải phóng dung lượng chưa? (y/n): " space_freed
                        if [ "$space_freed" != "y" ]; then
                            return 1
                        fi
                    fi
                elif [ "$strategy" -eq 9 ]; then
                    # Chiến lược 9: Cho phép nhập lại IP/user nếu nhập sai
                    echo "   🔧 Chiến lược 9/10: Nhập lại thông tin kết nối..."
                    echo "   📝 Thông tin kết nối hiện tại: $REMOTE"
                    read -p "   👉 Bạn có muốn nhập lại IP/username không? (y/n): " reenter_remote
                    if [ "$reenter_remote" = "y" ]; then
                        read -p "   Nhập lại địa chỉ VPS đích (user@ip): " new_remote
                        if [ -n "$new_remote" ]; then
                            REMOTE="$new_remote"
                            echo "   ✅ Đã cập nhật địa chỉ VPS đích: $REMOTE"
                            # Quay lại chiến lược 4 để kiểm tra kết nối mới
                            strategy=3
                            continue
                        fi
                    fi
                elif [ "$strategy" -eq 10 ]; then
                    # Chiến lược 10: Hướng dẫn sử dụng rsync thủ công
                    echo "   🔧 Chiến lược 10/10: Hướng dẫn rsync thủ công..."
                    echo "   📝 Nếu tự động vẫn thất bại, bạn có thể dùng rsync thủ công:"
                    echo "   1. Đảm bảo SSH key đã được thiết lập"
                    echo "   2. Chạy lệnh rsync sau:"
                    echo "      rsync -avz -e 'ssh -o StrictHostKeyChecking=accept-new' \\"
                    echo "          --rsync-path='cd ~ && rsync' \\"
                    echo "          ./ $REMOTE:~/supabase-backup-package/"
                    echo "   3. Lệnh trên sẽ đồng bộ toàn bộ thư mục hiện tại sang VPS đích"
                    echo ""
                    echo "   💡 Mẹo: Nếu gặp lỗi getcwd, hãy thêm --rsync-path='cd ~ && rsync'"
                    return 1
                fi
                
                strategy=$((strategy + 1))
            done
            
            if [ $success -eq 1 ]; then
                echo -e "${BOLD_GREEN}   ✅ Copy thành công! Từ lần sau sẽ không cần mật khẩu nữa.${NC}"
                return 0
            else
                echo -e "${BOLD_RED}   ❌ Đã thử tất cả 10 chiến lược nhưng vẫn không thể thiết lập SSH.${NC}"
                return 1
            fi
        }
        
        # Thực thi giải quyết vấn đề đồng bộ SSH
        if ! solve_ssh_sync_problem; then
            echo "   👉 Bạn có thể thử tự copy bằng lệnh thủ công hoặc liên hệ quản trị VPS đích."
            echo "   📋 Public key của bạn (copy toàn bộ dòng bên dưới):"
            cat ~/.ssh/id_rsa.pub 2>/dev/null
            echo ""
            echo "   🔧 Các bước thêm thủ công:"
            echo "     1. SSH vào VPS đích bằng mật khẩu (nếu được): ssh $REMOTE"
            echo "     2. Tạo thư mục .ssh nếu chưa có: mkdir -p ~/.ssh && chmod 700 ~/.ssh"
            echo "     3. Mở file authorized_keys: nano ~/.ssh/authorized_keys"
            echo "     4. Dán dòng public key ở trên vào cuối file, lưu và thoát."
            echo "     5. Đặt quyền: chmod 600 ~/.ssh/authorized_keys"
            echo "     6. Thoát SSH và thử lại đồng bộ."
        fi
    fi

    # ---------- Chẩn đoán lỗi SSH chi tiết ----------
    echo -e "${BOLD_CYAN}   Đang kiểm tra kết nối SSH tới $REMOTE...${NC}"
    SSH_ERROR=$(ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -v "${REMOTE}" 'echo "OK"' 2>&1)
    SSH_EXIT_CODE=$?

    if [ $SSH_EXIT_CODE -eq 0 ]; then
        # Kết nối thành công, kiểm tra thư mục home
        REMOTE_HOME=$(ssh -o StrictHostKeyChecking=accept-new "${REMOTE}" 'echo $HOME' 2>/dev/null)
        if [ -n "$REMOTE_HOME" ] && ssh -o StrictHostKeyChecking=accept-new "${REMOTE}" "test -d '$REMOTE_HOME'" 2>/dev/null; then
            echo -e "${BOLD_GREEN}   ✅ Kết nối SSH thành công, thư mục home xác định được: $REMOTE_HOME${NC}"
            SSH_OK=1
        else
            echo -e "${BOLD_RED}   ❌ Kết nối SSH được nhưng thư mục home không tồn tại hoặc không thể truy cập.${NC}"
            echo "   Hãy SSH vào VPS đích và kiểm tra: ssh $REMOTE"
            SSH_OK=0
        fi
    else
        # Kết nối thất bại, phân tích lỗi
        echo -e "${BOLD_RED}   ❌ Không thể kết nối SSH tới $REMOTE.${NC}"
        echo ""
        # Phân tích thông báo lỗi phổ biến
        if echo "$SSH_ERROR" | grep -q "Connection refused"; then
            echo "   🔍 Lỗi: Connection refused (Kết nối bị từ chối)"
            echo "   Nguyên nhân: Dịch vụ SSH trên VPS đích không chạy hoặc cổng 22 bị chặn."
            echo "   Cách khắc phục:"
            echo "   - Kiểm tra xem VPS đích có đang bật không."
            echo "   - Đảm bảo dịch vụ SSH đang chạy: sudo systemctl status sshd"
            echo "   - Kiểm tra firewall: sudo ufw allow 22"
        elif echo "$SSH_ERROR" | grep -q "Connection timed out"; then
            echo "   🔍 Lỗi: Connection timed out (Quá thời gian kết nối)"
            echo "   Nguyên nhân: IP của VPS đích không đúng, hoặc firewall đang chặn."
            echo "   Cách khắc phục:"
            echo "   - Kiểm tra lại địa chỉ IP: $REMOTE"
            echo "   - Đảm bảo VPS đích cho phép kết nối từ IP của bạn."
        elif echo "$SSH_ERROR" | grep -q "Permission denied"; then
            echo "   🔍 Lỗi: Permission denied (Quyền truy cập bị từ chối)"
            echo "   Nguyên nhân: Public key chưa được copy sang VPS đích, hoặc sai mật khẩu,"
            echo "   hoặc VPS đích không cho phép xác thực bằng mật khẩu."
            echo "   Cách khắc phục:"
            echo "   - Chạy lệnh sau để copy public key (nếu VPS đích cho phép mật khẩu):"
            echo "     ssh-copy-id -i ~/.ssh/id_rsa.pub $REMOTE"
            echo "   - Nếu không, bạn phải tự thêm public key vào file authorized_keys trên VPS đích."
            echo ""
            echo "   📋 Public key của bạn (copy toàn bộ dòng bên dưới):"
            cat ~/.ssh/id_rsa.pub 2>/dev/null
            echo ""
            echo "   👉 Các bước thêm thủ công:"
            echo "     1. SSH vào VPS đích bằng mật khẩu (nếu được): ssh $REMOTE"
            echo "     2. Tạo thư mục .ssh nếu chưa có: mkdir -p ~/.ssh && chmod 700 ~/.ssh"
            echo "     3. Mở file authorized_keys: nano ~/.ssh/authorized_keys"
            echo "     4. Dán dòng public key ở trên vào cuối file, lưu và thoát."
            echo "     5. Đặt quyền: chmod 600 ~/.ssh/authorized_keys"
            echo "     6. Thoát SSH và thử lại đồng bộ."
        elif echo "$SSH_ERROR" | grep -q "No route to host"; then
            echo "   🔍 Lỗi: No route to host (Không tìm thấy đường tới máy chủ)"
            echo "   Nguyên nhân: IP sai hoặc VPS đích không tồn tại."
            echo "   Cách khắc phục: Kiểm tra lại địa chỉ IP."
        elif echo "$SSH_ERROR" | grep -q "Host key verification failed"; then
            echo "   🔍 Lỗi: Host key verification failed (Khóa máy chủ không khớp)"
            echo "   Nguyên nhân: Key của VPS đích đã thay đổi (có thể do cài lại OS)."
            echo "   Cách khắc phục:"
            echo "   - Chạy lệnh sau để xóa key cũ:"
            echo "     ssh-keygen -R ${REMOTE##*@}"
        elif echo "$SSH_ERROR" | grep -q "Could not resolve hostname"; then
            echo "   🔍 Lỗi: Could not resolve hostname (Không phân giải được tên miền)"
            echo "   Nguyên nhân: Tên miền không đúng hoặc DNS không hoạt động."
            echo "   Cách khắc phục: Kiểm tra lại tên miền hoặc dùng địa chỉ IP."
        else
            echo "   🔍 Lỗi không xác định. Dưới đây là thông tin chi tiết để bạn nhờ hỗ trợ:"
            echo "   $SSH_ERROR" | tail -5
        fi
        echo ""
        echo "   📂 File backup vẫn được lưu tại: $BACKUP_FILE"
        echo "   Bạn có thể tự copy file này sang VPS đích sau khi khắc phục lỗi SSH."
        SSH_OK=0
    fi

    # ---------- Tạo package và gửi nếu kết nối OK ----------
    if [ $SSH_OK -eq 1 ]; then
        echo -e "${BOLD_CYAN}   Đang đóng gói và đồng bộ...${NC}"

        # Tạo thư mục package trên VPS nguồn
        PACKAGE_DIR="$PROJECT_DIR/$(basename "$BACKUP_FILE" .tar.gz)-package"
        mkdir -p "$PACKAGE_DIR"

        # Copy file backup vào package
        cp "$BACKUP_FILE" "$PACKAGE_DIR/"

        # Tạo script giải nén trong package
        cat > "$PACKAGE_DIR/supa-extract-backup.sh" <<'EXTRACTEOF'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKUP_FILE="$(ls -t "$SCRIPT_DIR"/supabase-backup-*.tar.gz 2>/dev/null | head -1)"
if [ -z "$BACKUP_FILE" ]; then
    echo "❌ Không tìm thấy file backup .tar.gz trong thư mục hiện tại."
    exit 1
fi
echo "📦 Đang giải nén: $(basename "$BACKUP_FILE")"
tar xzf "$BACKUP_FILE" -C "$SCRIPT_DIR"
echo "✅ Đã giải nén vào: $SCRIPT_DIR/$(basename "$BACKUP_FILE" .tar.gz)"
echo "👉 cd $(basename "$BACKUP_FILE" .tar.gz) && sudo bash supa-start.sh"
EXTRACTEOF
        chmod +x "$PACKAGE_DIR/supa-extract-backup.sh"

        # Gửi cả thư mục package sang VPS đích
        DEST_PARENT="${REMOTE_HOME}/supabase_self_host_backup"
        ssh -o StrictHostKeyChecking=accept-new "${REMOTE}" "mkdir -p '$DEST_PARENT'" 2>/dev/null

        if scp -o StrictHostKeyChecking=accept-new -r "$PACKAGE_DIR" "${REMOTE}:${DEST_PARENT}/"; then
            echo -e "${BOLD_GREEN}✅ Đồng bộ thành công! Thư mục trên VPS đích: ${DEST_PARENT}/$(basename "$PACKAGE_DIR")${NC}"
            echo -e "   📜 Script giải nén: ${DEST_PARENT}/$(basename "$PACKAGE_DIR")/supa-extract-backup.sh"
        else
            echo -e "${BOLD_RED}❌ Đồng bộ thất bại.${NC}"
            log_info "Đồng bộ sang VPS dự phòng thất bại"
            echo "   Bạn có thể thử tự copy thư mục bằng lệnh scp:"
            echo "   scp -r $PACKAGE_DIR ${REMOTE}:${DEST_PARENT}/"
        fi

        # Dọn dẹp package trên VPS nguồn (backup gốc vẫn giữ nguyên)
        rm -rf "$PACKAGE_DIR"
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
        CRON_LINE="0 2 * * * $SCRIPT_PATH --cron $PROJECT_DIR >> /var/log/supabase-backup.log 2>&1"
        (crontab -l 2>/dev/null; echo "$CRON_LINE") | sort -u | crontab -
        echo -e "${BOLD_GREEN}✅ Cron job đã được thêm. Hệ thống sẽ tự động backup lúc 2h sáng mỗi ngày.${NC}"
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