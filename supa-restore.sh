#!/bin/bash
# ==============================================
# SUPA-RESTORE.SH – Khôi phục Supabase từ backup
# -------------------------------------------------
# Hỗ trợ VPS trắng, phát hiện dữ liệu backup kèm sẵn.
# ==============================================

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

log_info "Bắt đầu quá trình khôi phục Supabase"

echo -e "${BOLD}${CYAN}======================================${NC}"
echo -e "${BOLD}${CYAN}  ♻️  KHÔI PHỤC HỆ THỐNG SUPABASE${NC}"
echo -e "${BOLD}${CYAN}======================================${NC}"

# -------------------------------------------------
# 1. Kiểm tra backup_data đính kèm
# -------------------------------------------------
USE_EMBEDDED="n"
if [ -d "$SCRIPT_DIR/backup_data" ]; then
    echo -e "${YELLOW}📦 Phát hiện dữ liệu backup kèm sẵn trong bộ kit.${NC}"
    read -p "👉 Bạn có muốn dùng dữ liệu này để khôi phục luôn không? (y/n): " USE_EMBEDDED
fi

if [ "$USE_EMBEDDED" = "y" ]; then
    echo "✅ Sử dụng dữ liệu backup có sẵn."
    BACKUP_DIR="$SCRIPT_DIR/backup_data"
    # Kiểm tra các thành phần cần thiết
    if [ ! -f "$BACKUP_DIR/database/full_backup.sql.gz" ] || [ ! -f "$BACKUP_DIR/config/.env" ] || [ ! -f "$BACKUP_DIR/config/docker-compose.yml" ]; then
        echo -e "${RED}❌ Dữ liệu backup không đầy đủ. Không thể tiếp tục.${NC}"
        exit 1
    fi
else
    # Flow nhập file backup như cũ
    while true; do
        read -p "Đường dẫn file backup (.tar.gz), URL, hoặc ,remote rclone: " SRC
        if [[ "$SRC" =~ ^gdrive: ]]; then
            # Đảm bảo rclone đã cài và có remote gdrive
            if ! command -v rclone &> /dev/null; then
                echo -e "${YELLOW}rclone chưa cài đặt. Đang thử cài đặt...${NC}"
                if ! ensure_rclone_gdrive; then
                    echo -e "${RED}Không thể cài rclone. Vui lòng cài thủ công hoặc chọn nguồn backup khác.${NC}"
                    continue
                fi
            fi
            # Kiểm tra remote gdrive đã có chưa, nếu chưa thì gợi ý cấu hình
            if ! rclone listremotes | grep -q "^gdrive:"; then
                echo -e "${YELLOW}Remote 'gdrive' chưa được cấu hình.${NC}"
                read -p "Bạn có muốn cấu hình ngay không? (y/n): " setup_gdrive
                if [ "$setup_gdrive" = "y" ]; then
                    # Gọi script chuyên dụng thay vì rclone config thô
                    if [ -f "$SCRIPT_DIR/supa-setup-gdrive.sh" ]; then
                        bash "$SCRIPT_DIR/supa-setup-gdrive.sh"
                    else
                        echo -e "${RED}Không tìm thấy script cấu hình Google Drive.${NC}"
                    fi
                fi
                if ! rclone listremotes | grep -q "^gdrive:"; then
                    echo -e "${RED}Chưa cấu hình Google Drive. Vui lòng thử lại sau khi cấu hình.${NC}"
                    continue
                fi
            fi
            # Tạo tên file tạm DUY NHẤT bằng PID của shell hiện tại
            LOCAL_FILE="/tmp/restore-backup-$$.tar.gz"
            # Xóa sạch nếu file/thư mục cũ cùng tên vẫn còn
            rm -rf "$LOCAL_FILE"

            # Thử tải
            if ! download_from_gdrive "$SRC" "$LOCAL_FILE"; then
                # Nếu lỗi thì gợi ý làm mới token và thử lại một lần
                if suggest_gdrive_reconnect; then
                    echo "🔄 Token đã được cập nhật, đang thử tải lại..."
                    rm -rf "$LOCAL_FILE"
                    if download_from_gdrive "$SRC" "$LOCAL_FILE"; then
                        BACKUP_FILE="$LOCAL_FILE"
                        break
                    fi
                fi
                echo -e "${RED}❌ Không thể tải file từ Google Drive. Vui lòng thử lại.${NC}"
                continue
            fi

            # Kiểm tra file tải về có thực sự là file hợp lệ không
            if [ ! -f "$LOCAL_FILE" ]; then
                echo -e "${RED}File tải về không tồn tại hoặc là thư mục.${NC}"
                log_error "Tải từ Google Drive thất bại: $LOCAL_FILE không phải là file hợp lệ"
                continue
            fi
            if [ ! -s "$LOCAL_FILE" ]; then
                echo -e "${RED}File tải về rỗng (0 byte).${NC}"
                log_error "File tải về rỗng: $LOCAL_FILE"
                continue
            fi

            BACKUP_FILE="$LOCAL_FILE"
            log_info "Tải thành công backup từ Google Drive: $SRC -> $LOCAL_FILE"
            break
        elif [[ "$SRC" =~ ^https?:// ]]; then
            echo "📥 Đang tải từ URL..."
            LOCAL_FILE="/tmp/restore-backup-$$.tar.gz"
            rm -rf "$LOCAL_FILE"
            wget -O "$LOCAL_FILE" "$SRC" && BACKUP_FILE="$LOCAL_FILE" && break
            echo -e "${RED}Tải thất bại. Kiểm tra URL.${NC}"
        else
            if validate_backup_file "$SRC"; then
                BACKUP_FILE="$SRC"
                break
            fi
        fi
    done

    # Kiểm tra sha256 nếu có
    if [ -f "${BACKUP_FILE}.sha256" ]; then
        echo "🔍 Đang kiểm tra tính toàn vẹn file backup..."
        if ! sha256sum -c "${BACKUP_FILE}.sha256" --quiet 2>/dev/null; then
            echo -e "${RED}❌ File backup bị hỏng hoặc không toàn vẹn!${NC}"
            exit 1
        fi
        echo "✅ File backup hợp lệ."
    fi

    # Giải nén và tìm backup_data
    TMP_DIR=$(mktemp -d)
    log_info "Giải nén backup vào $TMP_DIR"
    echo "📦 Giải nén backup vào $TMP_DIR..."
    tar xzf "$BACKUP_FILE" -C "$TMP_DIR" || { 
        log_error "Giải nén backup thất bại: $BACKUP_FILE"
        echo -e "${RED}Lỗi giải nén.${NC}"; exit 1; 
    }
    # Lấy thư mục con đầu tiên (tên thư mục gốc trong backup)
    EXTRACTED_DIR=$(ls -1 "$TMP_DIR" | head -1)
    BACKUP_DIR="$TMP_DIR/$EXTRACTED_DIR/backup_data"
    if [ ! -d "$BACKUP_DIR" ]; then
        log_error "Backup không chứa thư mục backup_data: $BACKUP_FILE"
        echo -e "${RED}❌ File backup không chứa backup_data.${NC}"
        rm -rf "$TMP_DIR"
        exit 1
    fi
fi

log_info "Bắt đầu khôi phục Supabase từ $BACKUP_FILE"

# -------------------------------------------------
# 2. Nhập domain (tùy chọn)
# -------------------------------------------------
read -p "Domain (Enter nếu không có): " DOMAIN
if [ -n "$DOMAIN" ]; then
    while ! validate_domain "$DOMAIN"; do
        read -p "Nhập lại domain: " DOMAIN
    done
fi

# -------------------------------------------------
# 3. Xác định thư mục cài đặt
# -------------------------------------------------
read -p "Thư mục cài Supabase (mặc định /opt/supabase-restored): " TARGET_DIR
TARGET_DIR="${TARGET_DIR:-/opt/supabase-restored}"
echo "📁 Thư mục cài đặt: $TARGET_DIR"
log_info "Thư mục cài đặt: $TARGET_DIR"
mkdir -p "$TARGET_DIR"
cd "$TARGET_DIR"

# -------------------------------------------------
# 4. Copy cấu hình từ backup_data vào thư mục cài đặt (kiểm tra chặt chẽ)
# -------------------------------------------------
echo "📋 Sao chép cấu hình..."
# Copy .env
if cp "$BACKUP_DIR/config/.env" "$TARGET_DIR/"; then
    echo "   ✅ .env đã được sao chép."
else
    echo -e "${RED}❌ Không thể sao chép .env vào $TARGET_DIR. Kiểm tra quyền ghi.${NC}"
    echo "   Bạn có thể thử tự copy bằng lệnh:"
    echo "   sudo cp $BACKUP_DIR/config/.env $TARGET_DIR/"
    exit 1
fi

# Copy docker-compose.yml
if cp "$BACKUP_DIR/config/docker-compose.yml" "$TARGET_DIR/"; then
    echo "   ✅ docker-compose.yml đã được sao chép."
else
    echo -e "${RED}❌ Không thể sao chép docker-compose.yml vào $TARGET_DIR. Kiểm tra quyền ghi.${NC}"
    echo "   Bạn có thể thử tự copy bằng lệnh:"
    echo "   sudo cp $BACKUP_DIR/config/docker-compose.yml $TARGET_DIR/"
    exit 1
fi

# Kiểm tra sự tồn tại của file docker-compose.yml sau khi copy
if [ ! -f "$TARGET_DIR/docker-compose.yml" ]; then
    echo -e "${RED}❌ File docker-compose.yml không tồn tại trong $TARGET_DIR sau khi copy.${NC}"
    echo "   Điều này có thể do hết dung lượng đĩa hoặc lỗi hệ thống."
    echo "   Vui lòng kiểm tra và thử lại, hoặc copy thủ công:"
    echo "   cp $BACKUP_DIR/config/docker-compose.yml $TARGET_DIR/"
    exit 1
fi

echo "   ✅ Xác nhận docker-compose.yml đã sẵn sàng."

# Đảm bảo tương thích với môi trường ảo hóa LXC/OpenVZ:
# Thêm security_opt và cap_add cho các service cố gắng đặt sysctl
echo "🔧 Đang tối ưu cấu hình cho môi trường ảo hóa..."
SERVICES_TO_FIX="vector imgproxy db"
for svc in $SERVICES_TO_FIX; do
    if grep -q "^  ${svc}:" "$TARGET_DIR/docker-compose.yml"; then
        # Kiểm tra xem đã có seccomp:unconfined chưa, nếu chưa thì thêm
        if ! grep -A10 "^  ${svc}:" "$TARGET_DIR/docker-compose.yml" | grep -q "seccomp:unconfined"; then
            # Thêm security_opt và cap_add vào sau dòng 'image:' của service
            sudo sed -i "/^  ${svc}:/,/^  [a-z]/{/^    image:/a\    security_opt:\n      - seccomp:unconfined\n    cap_add:\n      - SYS_ADMIN
            }" "$TARGET_DIR/docker-compose.yml"
            echo "   ✅ Đã thêm security_opt và cap_add cho service '$svc'"
        fi
    fi
done
echo "   ✅ Hoàn tất tối ưu cấu hình."

# ------------------------------------------------------------
# CHUẨN BỊ MÔI TRƯỜNG SẠCH TRƯỚC KHI KHỞI ĐỘNG (CÓ HỎI)
# ------------------------------------------------------------
echo "🧹 Đang kiểm tra container Supabase cũ..."

# 1. Kiểm tra container trong dự án hiện tại (dùng compose file)
if $DOCKER_COMPOSE_CMD -f "$TARGET_DIR/docker-compose.yml" ps -q 2>/dev/null | grep -q .; then
    echo -e "${YELLOW}⚠️ Phát hiện container Supabase đang chạy từ thư mục $TARGET_DIR.${NC}"
    read -p "👉 Bạn có muốn dừng và xóa chúng để khôi phục mới không? (y/n): " confirm_clean
    if [ "$confirm_clean" = "y" ]; then
        $DOCKER_COMPOSE_CMD -f "$TARGET_DIR/docker-compose.yml" down -v --remove-orphans 2>/dev/null || true
        echo "✅ Đã dọn dẹp container cũ trong dự án này."
    else
        echo "❌ Hủy bỏ. Bạn có thể tự xử lý container cũ rồi chạy lại."
        exit 0
    fi
fi

# 2. Kiểm tra container cũ (tên chứa "supabase" nhưng không thuộc compose trên)
ORPHAN_CONTAINERS=$(docker ps -a --filter "name=supabase" -q 2>/dev/null)
if [ -n "$ORPHAN_CONTAINERS" ]; then
    echo -e "${YELLOW}⚠️ Tìm thấy các container Supabase cũ (từ lần khôi phục trước).${NC}"
    echo "   Danh sách container sắp bị xóa:"
    docker ps -a --filter "name=supabase" --format "   .Names\t.Status" 2>/dev/null
    read -p "👉 Bạn có muốn xóa các container này không? (y/n): " confirm_orphan
    if [ "$confirm_orphan" = "y" ]; then
        docker rm -f $ORPHAN_CONTAINERS 2>/dev/null || true
        echo "✅ Đã xóa container cũ."
    else
        echo "ℹ️ Giữ nguyên container cũ."
    fi
fi

# 3. Quét và sửa sysctl (chỉ sửa file, không đụng chạm gì khác)
echo "🔍 Đang quét toàn bộ cấu hình để tìm sysctl không tương thích..."
SYSCTL_FILES=$(grep -rl "ip_unprivileged_port_start" "$TARGET_DIR" 2>/dev/null || true)
if [ -n "$SYSCTL_FILES" ]; then
    for f in $SYSCTL_FILES; do
        echo "   🔧 Đang sửa file: $f"
        if sudo sed -i '/ip_unprivileged_port_start/d' "$f" 2>/dev/null; then
            echo "   ✅ Đã xóa dòng sysctl khỏi $f"
        else
            echo -e "${YELLOW}   ⚠️ Không thể tự động sửa file $f (thiếu quyền sudo?).${NC}"
            echo "   👉 Bạn hãy tự mở file: sudo nano $f"
            echo "      Tìm và xóa dòng chứa 'ip_unprivileged_port_start', lưu lại và thoát."
            read -p "   Nhấn Enter sau khi đã sửa xong (hoặc nhập 'skip' để bỏ qua): " user_choice
            if [ "$user_choice" = "skip" ]; then
                echo "   ⏭️ Bỏ qua file này."
            fi
        fi
    done
else
    echo "   ✅ Không tìm thấy dòng sysctl trong bất kỳ file cấu hình nào."
fi

# Không bao giờ tự ý restart Docker hay xóa image. 
# Nếu thực sự cần, script sẽ hướng dẫn người dùng tự làm ở bước xử lý lỗi.

# Phục hồi volumes (ưu tiên thư mục, sau đó mới đến file nén)
if [ -d "$BACKUP_DIR/volumes" ] && [ "$(ls -A "$BACKUP_DIR/volumes" 2>/dev/null)" ]; then
    echo "📂 Phục hồi thư mục volumes..."
    cp -r "$BACKUP_DIR/volumes" "$TARGET_DIR/"
    echo "✅ Volumes đã được phục hồi (bao gồm functions, db/init, api...)."
elif [ -f "$BACKUP_DIR/config/volumes.tar.gz" ]; then
    echo "📂 Giải nén volumes từ backup..."
    tar xzf "$BACKUP_DIR/config/volumes.tar.gz" -C "$TARGET_DIR/" 2>/dev/null || echo -e "${YELLOW}⚠️ Một số file volumes không được giải nén (có thể thiếu quyền).${NC}"
else
    echo -e "${YELLOW}⚠️ Không tìm thấy dữ liệu volumes trong backup.${NC}"
fi

# ---------- HÀM THỬ KHỞI ĐỘNG (sửa lỗi mất log) ----------
LAST_DOCKER_ERR=""

try_start() {
    local err_log="/tmp/docker_start_err_$$.log"
    $DOCKER_COMPOSE_CMD -f "$TARGET_DIR/docker-compose.yml" up -d 2>"$err_log"
    local ec=$?
    if [ $ec -ne 0 ]; then
        LAST_DOCKER_ERR=$(< "$err_log")
        cat "$err_log"
        rm -f "$err_log"
        return 1
    fi
    rm -f "$err_log"
    LAST_DOCKER_ERR=""
    return 0
}

# -------------------------------------------------
# 5. Cài Docker nếu chưa có
# -------------------------------------------------
if ! command -v docker &> /dev/null; then
    echo "⚙️ Docker chưa được cài đặt."
    require_sudo_or_exit
    wait_for_apt_lock || exit 1
    sudo apt update && sudo apt install -y docker.io docker-compose-v2
    sudo systemctl enable --now docker
    if ! groups $REAL_USER | grep -q docker; then
        echo -e "${YELLOW}⚠️ Thêm user '$REAL_USER' vào group docker để dùng không cần sudo.${NC}"
        echo "   sudo usermod -aG docker $REAL_USER"
    fi
    log_info "Docker đã được cài đặt (nếu cần)"
else
    log_info "Docker đã sẵn sàng (hoặc đã được cài đặt)"
fi

# -------------------------------------------------
# 6. Khởi động Supabase
# -------------------------------------------------
echo "🚀 Khởi động Supabase..."

# Kiểm tra dung lượng đĩa trước khi khởi động (cần ít nhất 500MB trống)
if ! check_disk_space 500 "$TARGET_DIR"; then
    echo -e "${RED}❌ Không đủ dung lượng đĩa để khởi động Supabase.${NC}"
    echo "   Hãy giải phóng bớt dung lượng hoặc mở rộng ổ đĩa."
    exit 1
fi

# ---------- LẦN 1 ----------
SUPABASE_STARTED=0
if try_start; then
    echo -e "${GREEN}✅ Supabase khởi động thành công.${NC}"
    SUPABASE_STARTED=1
else
    echo -e "${YELLOW}⚠️ Khởi động lần đầu thất bại. Đang phân tích lỗi...${NC}"

    # ----- XỬ LÝ LỖI SYSCTL (mới: sử dụng privileged mode) -----
    if echo "$LAST_DOCKER_ERR" | grep -q "net.ipv4.ip_unprivileged_port_start"; then
        echo "   🔍 Phát hiện lỗi sysctl cứng đầu."
        echo "   🧹 Đang dừng mọi container liên quan đến Supabase..."
        $DOCKER_COMPOSE_CMD -f "$TARGET_DIR/docker-compose.yml" down -v --remove-orphans 2>/dev/null || true
        docker ps -a --filter "name=supabase" -q | xargs -r docker rm -f 2>/dev/null || true

        # Biện pháp tương thích: thêm privileged: true vào các service thường gặp lỗi sysctl
        echo "   🔧 Đang áp dụng biện pháp tương thích (privileged mode) cho vector, imgproxy, db..."
        SERVICES_TO_FIX="vector imgproxy db"
        for svc in $SERVICES_TO_FIX; do
            # Kiểm tra xem service đó có tồn tại trong compose file không
            if grep -q "^  ${svc}:" "$TARGET_DIR/docker-compose.yml"; then
                # Kiểm tra xem service đó đã có privileged: true chưa
                # Sử dụng awk để kiểm tra trong block của service cụ thể
                if ! awk -v svc="$svc" '
                    $0 ~ "^  " svc ":" { found=1; next }
                    found && /^  [a-zA-Z]/ { found=0 }
                    found && /privileged: true/ { exit 0 }
                    END { exit 1 }
                ' "$TARGET_DIR/docker-compose.yml"; then
                    # Thêm dòng privileged: true vào sau dòng image hoặc container_name của service
                    # Ưu tiên thêm sau image nếu có, nếu không thì sau service name block bắt đầu
                    sudo sed -i "/^  ${svc}:/,/^  [a-z]/{
                        /^    image:/ {
                            a\    privileged: true
                            b end
                        }
                        /^    container_name:/ {
                            a\    privileged: true
                            b end
                        }
                        :end
                    }" "$TARGET_DIR/docker-compose.yml"
                    echo "   ✅ Đã thêm privileged: true cho service '$svc'"
                else
                    echo "   ℹ️ Service '$svc' đã có privileged: true, bỏ qua."
                fi
            fi
        done

        echo "   🔄 Đang thử khởi động lại..."
        if try_start; then
            echo -e "${GREEN}✅ Supabase đã khởi động thành công với privileged mode.${NC}"
            SUPABASE_STARTED=1
        else
            echo -e "${RED}❌ Vẫn không thể khởi động.${NC}"
            echo "   📋 Lỗi mới:"
            echo "$LAST_DOCKER_ERR"
            echo ""
            echo -e "${YELLOW}⚠️ Lỗi này thường xảy ra trên VPS dùng công nghệ ảo hóa OpenVZ/LXC.${NC}"
            echo "   Bạn có thể thử các cách sau:"
            echo "   1. Liên hệ nhà cung cấp VPS để bật 'nesting' hoặc 'lxc.apparmor.profile=unconfined'."
            echo "   2. Cài đặt Docker Engine từ kho chính thức (không dùng docker.io)."
            echo "   3. Sử dụng VPS dùng ảo hóa KVM thay vì OpenVZ/LXC."
            SUPABASE_STARTED=0
        fi

    # ----- XỬ LÝ CÁC LỖI KHÁC -----
    elif echo "$LAST_DOCKER_ERR" | grep -q "no space left on device"; then
        echo -e "${RED}❌ Hết dung lượng ổ đĩa.${NC}"
        exit 1
    elif echo "$LAST_DOCKER_ERR" | grep -q "address already in use"; then
        echo -e "${RED}❌ Cổng bị chiếm.${NC}"
        exit 1
    elif echo "$LAST_DOCKER_ERR" | grep -q "permission denied"; then
        echo -e "${RED}❌ Lỗi quyền truy cập thư mục volumes.${NC}"
    else
        echo -e "${YELLOW}⚠️ Lỗi không xác định. Dưới đây là log chi tiết:${NC}"
        echo "$LAST_DOCKER_ERR"
    fi
fi

# -------------------------------------------------
# Xử lý khi Supabase không khởi động được
# -------------------------------------------------
if [ $SUPABASE_STARTED -eq 0 ]; then
    echo ""
    echo -e "${YELLOW}Không thể khởi động Supabase, nhưng bạn vẫn có thể phục hồi dữ liệu nếu container database đang chạy.${NC}"
    echo "Bạn có 2 lựa chọn:"
    echo "1. Tự khởi động Supabase thủ công, sau đó chạy lại script này để import database & storage."
    echo "2. Tiếp tục import database & storage NGAY BÂY GIỜ (chỉ hiệu quả nếu container database đang chạy)."
    read -p "👉 Bạn muốn tiếp tục import database & storage không? (y/n): " continue_restore
    if [ "$continue_restore" != "y" ]; then
        echo "Đã hủy. Bạn có thể chạy lại script sau khi khắc phục lỗi khởi động."
        exit 0
    fi
fi

# -------------------------------------------------
# Kiểm tra container database (nếu có)
# -------------------------------------------------
echo "⏳ Đang kiểm tra container database..."
DB_CONT=""
for i in {1..10}; do
    DB_CONT=$(docker ps --format '.Names' | grep -E 'supabase.*db|db' | head -1)
    if [ -n "$DB_CONT" ]; then
        if docker exec $DB_CONT pg_isready -U postgres &>/dev/null; then
            echo "✅ Database đã sẵn sàng."
            break
        fi
    fi
    echo -n "."; sleep 3
done
echo ""

if [ -z "$DB_CONT" ]; then
    echo -e "${RED}❌ Không tìm thấy container database đang chạy.${NC}"
    echo "   Bạn cần khởi động Supabase trước khi import dữ liệu."
    echo "   Hãy thử chạy lệnh sau:"
    echo "   cd $TARGET_DIR && sudo $DOCKER_COMPOSE_CMD -f docker-compose.yml up -d"
    echo "   Sau đó chạy lại script này để import database & storage."
    exit 1
fi

# -------------------------------------------------
# 7. Import database
# -------------------------------------------------
echo "🗄️ Import database..."
gunzip -c "$BACKUP_DIR/database/full_backup.sql.gz" > /tmp/restore.sql
docker cp /tmp/restore.sql $DB_CONT:/tmp/
docker exec -t $DB_CONT psql -U postgres -f /tmp/restore.sql || { 
    log_error "Import database thất bại"
    rm /tmp/restore.sql; exit 1; 
}
rm /tmp/restore.sql
log_info "Import database thành công"

# -------------------------------------------------
# 8. Import storage
# -------------------------------------------------
if [ -f "$BACKUP_DIR/storage/storage.tar.gz" ]; then
    echo "📂 Import storage..."
    STORAGE_VOL=$(docker volume ls -q | grep _storage)
    if [ -n "$STORAGE_VOL" ]; then
        docker run --rm -v $STORAGE_VOL:/mnt/storage -v "$BACKUP_DIR/storage:/backup:ro" alpine \
            sh -c "cd /mnt/storage && tar xzf /backup/storage.tar.gz"
    else
        [ -d volumes/storage ] && tar xzf "$BACKUP_DIR/storage/storage.tar.gz" -C volumes/storage
    fi
    echo "✅ Storage đã phục hồi."
    log_info "Import storage thành công"
else
    echo "ℹ️ Không có dữ liệu storage."
fi

# -------------------------------------------------
# 9. Cài Nginx nếu có domain (giữ nguyên logic)
# -------------------------------------------------
if [ -n "$DOMAIN" ]; then
    echo "🌐 Cài đặt Nginx và HTTPS..."
    PORT80=$(check_port 80)
    PORT443=$(check_port 443)
    if [[ "$PORT80" == DOCKER* ]] || [[ "$PORT443" == DOCKER* ]]; then
        echo -e "${YELLOW}Phát hiện container Docker chiếm cổng.${NC}"
        read -p "Dừng để cài Nginx? (y/n): " stop_ans
        if [ "$stop_ans" = "y" ]; then
            for cont in $(echo "$PORT80" "$PORT443" | grep -Po 'DOCKER\|\K[^|]+' | sort -u); do docker stop $cont && docker rm $cont; done
        else
            echo "Bỏ qua Nginx."
        fi
    elif [[ "$PORT80" != "FREE" ]] || [[ "$PORT443" != "FREE" ]]; then
        echo -e "${RED}Cổng 80/443 bị chiếm.${NC}"
    else
        need_nginx=0; need_certbot=0
        command -v nginx &> /dev/null || need_nginx=1
        command -v certbot &> /dev/null || need_certbot=1
        if [ $need_nginx -eq 1 ] || [ $need_certbot -eq 1 ]; then
            require_sudo_or_exit
            wait_for_apt_lock || exit 1
            sudo apt update
            [ $need_nginx -eq 1 ] && sudo apt install -y nginx
            [ $need_certbot -eq 1 ] && sudo apt install -y certbot python3-certbot-nginx
        fi
        if check_nginx_domain_conflict "$DOMAIN"; then
            read -p "Domain $DOMAIN đã tồn tại, ghi đè? (y/n): " overwrite
            [ "$overwrite" = "y" ] && for f in $(grep -rl "server_name $DOMAIN" /etc/nginx/sites-enabled/); do sudo rm "$f"; done
        fi
        if [ "$overwrite" != "n" ]; then
            sudo tee /etc/nginx/sites-available/supabase > /dev/null <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$server_name\$request_uri;
}
server {
    listen 443 ssl http2;
    server_name $DOMAIN;
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    ssl_session_cache shared:SSL:10m;
    location / {
        proxy_pass http://localhost:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
            sudo ln -sf /etc/nginx/sites-available/supabase /etc/nginx/sites-enabled/
            sudo nginx -t && sudo systemctl reload nginx
            sudo certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m "admin@$DOMAIN" || echo "Certbot lỗi."
        fi
    fi
fi

# -------------------------------------------------
# 10. Khởi động lại và hiển thị thông tin
# -------------------------------------------------
$DOCKER_COMPOSE_CMD -f "$TARGET_DIR/docker-compose.yml" restart || {
    echo -e "${RED}❌ Khởi động lại Supabase thất bại.${NC}"
    echo "   Hãy kiểm tra file docker-compose.yml tại $TARGET_DIR và thử lại."
    exit 1
}
IP=$(hostname -I | awk '{print $1}')
log_info "Khôi phục hoàn tất tại $TARGET_DIR"
echo -e "${GREEN}=============================================${NC}"
echo -e "${GREEN}  🎉 KHÔI PHỤC HOÀN TẤT!${NC}"
echo -e "${GREEN}=============================================${NC}"
if [ -f .env ]; then
    STUDIO_URL="http://${IP}:8000"
    [ -n "$DOMAIN" ] && STUDIO_URL="https://${DOMAIN}"
    echo "🌐 Studio URL: $STUDIO_URL"
    USERNAME=$(grep -E '^DASHBOARD_USERNAME=' .env | cut -d '=' -f2)
    echo "👤 Tên đăng nhập: ${USERNAME:-Chưa có}"
    echo "🔑 Mật khẩu: (xem trong file $TARGET_DIR/.env, biến DASHBOARD_PASSWORD)"
fi
echo -e "${GREEN}=============================================${NC}"

# Dọn dẹp thư mục tạm nếu dùng file backup ngoài
# Chỉ xóa khi TMP_DIR được tạo ra (USE_EMBEDDED != "y") và an toàn (nằm trong /tmp)
if [ "$USE_EMBEDDED" != "y" ] && [ -n "$TMP_DIR" ] && [[ "$TMP_DIR" == /tmp/* ]]; then
    rm -rf "$TMP_DIR"
fi