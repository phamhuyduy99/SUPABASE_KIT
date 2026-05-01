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
    docker ps -a --filter "name=supabase" --format "   {{.Names}}\t{{.Status}}" 2>/dev/null
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

# ---------- HÀM THÊM PRIVILEGED MODE ----------
add_privileged() {
    local svc=$1
    local compose_file="$TARGET_DIR/docker-compose.yml"
    
    # Kiểm tra xem service đã có privileged: true chưa
    # Logic awk: tìm service, kiểm tra xem có dòng privileged: true không trước khi gặp service khác
    if awk -v svc="$svc" '
        $0 ~ "^  " svc ":" { found=1; next }
        found && /^  [a-zA-Z]/ { found=0 }
        found && /^    privileged: true/ { exit 0 }
        END { if (found) exit 1; else exit 0 }
    ' "$compose_file"; then
        # Chưa có, tiến hành thêm vào sau dòng image: (đầu tiên của service)
        local tmp_file
        tmp_file=$(mktemp)
        awk -v svc="$svc" '
            BEGIN { in_svc=0; added=0 }
            $0 ~ "^  " svc ":" { in_svc=1; print; next }
            in_svc && /^  [a-zA-Z]/ { in_svc=0 }
            in_svc && !added && /^    image:/ { print; print "    privileged: true"; added=1; next }
            { print }
        ' "$compose_file" | sudo tee "$tmp_file" > /dev/null
        sudo mv "$tmp_file" "$compose_file"
        echo "   ✅ Đã thêm 'privileged: true' cho service '$svc'"
        return 0
    else
        echo "   ℹ️ Service '$svc' đã có 'privileged: true', bỏ qua."
        return 1
    fi
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

    # ----- XỬ LÝ LỖI SYSCTL (10 CHIẾN LƯỢC TOÀN DIỆN) -----
    if echo "$LAST_DOCKER_ERR" | grep -q "net.ipv4.ip_unprivileged_port_start"; then
        echo "   🔍 Phát hiện lỗi sysctl do môi trường ảo hóa LXC/OpenVZ."
        echo "   🧹 Đang dừng mọi container liên quan đến Supabase..."
        $DOCKER_COMPOSE_CMD -f "$TARGET_DIR/docker-compose.yml" down -v --remove-orphans 2>/dev/null || true
        docker ps -a --filter "name=supabase" -q | xargs -r docker rm -f 2>/dev/null || true

        # Tự động sao lưu file docker-compose.yml gốc trước khi sửa đổi
        if [ ! -f "$TARGET_DIR/docker-compose.yml.original" ]; then
            cp "$TARGET_DIR/docker-compose.yml" "$TARGET_DIR/docker-compose.yml.original"
            echo "   💾 Đã sao lưu file gốc: $TARGET_DIR/docker-compose.yml.original"
        fi

        # ====== CÁC HÀM CHIẾN LƯỢC CHO VẤN ĐỀ SYSCTL ======
        
        # Nhóm A – Tự động hoàn toàn (1-5)
        sysctl_01_delete_line() {
            echo "      Xóa dòng sysctl trong docker-compose.yml..."
            if grep -q "sysctls:" "$TARGET_DIR/docker-compose.yml"; then
                local tmp_file=$(mktemp)
                awk '
                    !/^[[:space:]]*sysctls:/ && !/^[[:space:]]*-[[:space:]]*net\.ipv4\.ip_unprivileged_port_start/
                ' "$TARGET_DIR/docker-compose.yml" > "$tmp_file"
                sudo mv "$tmp_file" "$TARGET_DIR/docker-compose.yml"
                echo "      ✅ Đã xóa cấu hình sysctl."
                return 0
            else
                echo "      ℹ️ Không tìm thấy cấu hình sysctl."
                return 1
            fi
        }
        
        sysctl_02_add_privileged() {
            echo "      Thêm privileged: true cho vector, imgproxy, db..."
            local modified=0
            SERVICES_TO_FIX="vector imgproxy db"
            for svc in $SERVICES_TO_FIX; do
                if grep -q "^  ${svc}:" "$TARGET_DIR/docker-compose.yml"; then
                    if ! awk -v svc="$svc" '
                        $0 ~ "^  " svc ":" { found=1; next }
                        found && /^  [a-zA-Z]/ { found=0 }
                        found && /^    privileged: true/ { exit 0 }
                        END { exit 1 }
                    ' "$TARGET_DIR/docker-compose.yml"; then
                        local tmp_file=$(mktemp)
                        awk -v svc="$svc" '
                            BEGIN { in_svc=0; added=0 }
                            $0 ~ "^  " svc ":" { in_svc=1; print; next }
                            in_svc && /^  [a-zA-Z]/ { in_svc=0 }
                            in_svc && !added && /^    image:/ { print; print "    privileged: true"; added=1; next }
                            { print }
                        ' "$TARGET_DIR/docker-compose.yml" | sudo tee "$tmp_file" > /dev/null
                        sudo mv "$tmp_file" "$TARGET_DIR/docker-compose.yml"
                        modified=1
                    fi
                fi
            done
            if [ $modified -eq 1 ]; then
                echo "      ✅ Đã thêm privileged: true."
                return 0
            else
                echo "      ℹ️ Tất cả service đã có privileged: true."
                return 1
            fi
        }
        
        sysctl_03_add_security_opt() {
            echo "      Thêm security_opt và cap_add..."
            local modified=0
            SERVICES_TO_FIX="vector imgproxy db"
            for svc in $SERVICES_TO_FIX; do
                if grep -q "^  ${svc}:" "$TARGET_DIR/docker-compose.yml"; then
                    if ! awk -v svc="$svc" '
                        $0 ~ "^  " svc ":" { found=1; next }
                        found && /^  [a-zA-Z]/ { found=0 }
                        found && (/^    security_opt:/ || /^    cap_add:/) { exit 0 }
                        END { exit 1 }
                    ' "$TARGET_DIR/docker-compose.yml"; then
                        local tmp_file=$(mktemp)
                        awk -v svc="$svc" '
                            BEGIN { in_svc=0; added=0 }
                            $0 ~ "^  " svc ":" { in_svc=1; print; next }
                            in_svc && /^  [a-zA-Z]/ { in_svc=0 }
                            in_svc && !added && /^    image:/ { 
                                print; 
                                print "    security_opt:"
                                print "      - seccomp:unconfined"
                                print "    cap_add:"
                                print "      - SYS_ADMIN"
                                added=1; next 
                            }
                            { print }
                        ' "$TARGET_DIR/docker-compose.yml" | sudo tee "$tmp_file" > /dev/null
                        sudo mv "$tmp_file" "$TARGET_DIR/docker-compose.yml"
                        modified=1
                        echo "      ✅ Đã thêm security_opt và cap_add cho service '$svc'"
                    else
                        echo "      ℹ️ Service '$svc' đã có security_opt hoặc cap_add, bỏ qua."
                    fi
                fi
            done
            if [ $modified -eq 1 ]; then
                return 0
            else
                return 1
            fi
        }
        
        sysctl_04_docker_run_sysctl() {
            echo "      Thử dùng --sysctl trong lệnh docker run..."
            # Lưu ý: Đây là chiến lược phức tạp, thường không khả thi với docker-compose
            echo "      ℹ️ Chiến lược này yêu cầu chuyển từ docker-compose sang docker run thủ công."
            echo "      ℹ️ Không được khuyến khích cho Supabase do độ phức tạp cao."
            return 1
        }
        
        sysctl_05_clean_cache() {
            echo "      Xóa cache container/image cũ..."
            docker system prune -af >/dev/null 2>&1
            docker volume prune -f >/dev/null 2>&1
            echo "      ✅ Đã dọn dẹp cache Docker."
            return 0
        }
        
        # Nhóm B – Bán tự động (hỏi y/n) (6-10)
        sysctl_06_docker_daemon() {
            echo "      Cấu hình Docker daemon để bỏ qua sysctl..."
            if ask_user_confirmation "Bạn có muốn cấu hình Docker daemon không? (sẽ khởi động lại Docker)" "n"; then
                echo "      Đang cấu hình Docker..."
                if [ ! -f /etc/docker/daemon.json ]; then
                    echo '{}' | sudo tee /etc/docker/daemon.json > /dev/null
                fi
                sudo python3 -c "
import json
config = {}
try:
    with open('/etc/docker/daemon.json') as f:
        config = json.load(f)
except:
    pass
config['default-ulimits'] = {'nofile': {'Hard': 65536, 'Name': 'nofile', 'Soft': 65536}}
with open('/etc/docker/daemon.json', 'w') as f:
    json.dump(config, f, indent=4)
"
                echo "      ✅ Đã cấu hình Docker."
                echo "      🔄 Đang khởi động lại Docker..."
                sudo systemctl restart docker
                sleep 5
                return 0
            else
                return 1
            fi
        }
        
        sysctl_07_downgrade_containerd() {
            echo "      Hạ cấp containerd về 1.7.28-1..."
            CONTAINERD_VERSION=$(containerd --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' || echo "0.0.0")
            MIN_BUGGY_VERSION="1.7.28"
            if dpkg --compare-versions "$CONTAINERD_VERSION" ge "$MIN_BUGGY_VERSION"; then
                if ask_user_confirmation "Bạn có muốn hạ cấp containerd xuống 1.7.28-1 không?" "n"; then
                    echo "      Đang hạ cấp containerd..."
                    if sudo apt update && sudo apt install -y --allow-downgrades containerd.io=1.7.28-1~ubuntu.22.04~noble 2>/dev/null; then
                        echo "      ✅ Hạ cấp thành công."
                        sudo apt-mark hold containerd.io 2>/dev/null
                        return 0
                    else
                        echo "      ❌ Hạ cấp thất bại."
                        return 1
                    fi
                else
                    return 1
                fi
            else
                echo "      ℹ️ Phiên bản containerd hiện tại không gây lỗi."
                return 1
            fi
        }
        
        sysctl_08_change_runtime() {
            echo "      Thử thay đổi runtime Docker..."
            show_manual_guide "Thay đổi runtime Docker" \
                "Cài đặt runtime mong muốn (sysbox, nvidia-container-runtime, v.v.)" \
                "Thêm dòng 'runtime: runtime_name' vào từng service trong docker-compose.yml" \
                "Khởi động lại Docker và thử lại"
            return 1
        }
        
        sysctl_09_disable_apparmor() {
            echo "      Vô hiệu hóa AppArmor trên host..."
            if command -v aa-status >/dev/null 2>&1 && aa-status --enabled 2>/dev/null; then
                if ask_user_confirmation "Bạn có muốn tạm thời vô hiệu hóa AppArmor không?" "n"; then
                    sudo systemctl stop apparmor
                    echo "      ✅ Đã vô hiệu hóa AppArmor."
                    return 0
                else
                    return 1
                fi
            else
                echo "      ℹ️ AppArmor không hoạt động hoặc không tồn tại."
                return 1
            fi
        }
        
        sysctl_10_disable_selinux() {
            echo "      Tắt SELinux trên host..."
            if [ -f /etc/selinux/config ] && grep -q "SELINUX=enforcing" /etc/selinux/config; then
                if ask_user_confirmation "Bạn có muốn chuyển SELinux sang permissive không?" "n"; then
                    sudo setenforce 0
                    echo "      ✅ Đã chuyển SELinux sang permissive."
                    return 0
                else
                    return 1
                fi
            else
                echo "      ℹ️ SELinux không ở chế độ enforcing."
                return 1
            fi
        }
        
        # Nhóm C – Nâng cao (thay đổi hệ thống) (11-15)
        sysctl_11_change_docker() {
            echo "      Sử dụng phiên bản Docker khác..."
            show_manual_guide "Chuyển từ docker.io sang docker-ce" \
                "Gỡ cài đặt docker.io: sudo apt remove docker.io" \
                "Cài đặt Docker CE theo hướng dẫn chính thức: https://docs.docker.com/engine/install/ubuntu/" \
                "Khởi động lại dịch vụ Docker"
            return 1
        }
        
        sysctl_12_kernel_params() {
            echo "      Thay đổi kernel parameters..."
            if ask_user_confirmation "Bạn có muốn thử thay đổi kernel parameters không?" "n"; then
                echo "      Đang áp dụng kernel parameters..."
                sudo sysctl -w net.ipv4.ip_unprivileged_port_start=0
                echo "      net.ipv4.ip_unprivileged_port_start=0" | sudo tee -a /etc/sysctl.conf
                echo "      ✅ Đã áp dụng kernel parameters."
                return 0
            else
                return 1
            fi
        }
        
        sysctl_13_custom_image() {
            echo "      Sử dụng image Supabase tự build..."
            show_manual_guide "Sử dụng image Supabase tùy chỉnh" \
                "Build image Supabase từ source code với các patch cần thiết" \
                "Đẩy image lên registry riêng" \
                "Thay đổi tag image trong docker-compose.yml"
            return 1
        }
        
        sysctl_14_net_host() {
            echo "      Chạy container với --net=host..."
            local modified=0
            SERVICES_TO_FIX="vector imgproxy db kong api auth realtime storage"
            for svc in $SERVICES_TO_FIX; do
                if grep -q "^  ${svc}:" "$TARGET_DIR/docker-compose.yml"; then
                    if ! awk -v svc="$svc" '
                        $0 ~ "^  " svc ":" { found=1; next }
                        found && /^  [a-zA-Z]/ { found=0 }
                        found && /^    network_mode: host/ { exit 0 }
                        END { exit 1 }
                    ' "$TARGET_DIR/docker-compose.yml"; then
                        local tmp_file=$(mktemp)
                        awk -v svc="$svc" '
                            BEGIN { in_svc=0; added=0 }
                            $0 ~ "^  " svc ":" { in_svc=1; print; next }
                            in_svc && /^  [a-zA-Z]/ { in_svc=0 }
                            in_svc && !added && /^    image:/ { print; print "    network_mode: host"; added=1; next }
                            { print }
                        ' "$TARGET_DIR/docker-compose.yml" | sudo tee "$tmp_file" > /dev/null
                        sudo mv "$tmp_file" "$TARGET_DIR/docker-compose.yml"
                        modified=1
                    fi
                fi
            done
            if [ $modified -eq 1 ]; then
                echo "      ✅ Đã thêm network_mode: host."
                return 0
            else
                echo "      ℹ️ Tất cả service đã có network_mode: host."
                return 1
            fi
        }
        
        sysctl_15_use_podman() {
            echo "      Sử dụng podman thay cho Docker..."
            show_manual_guide "Chuyển từ Docker sang Podman" \
                "Cài đặt Podman: sudo apt install podman" \
                "Chuyển đổi docker-compose.yml sang podman-compose" \
                "Chạy lại hệ thống với podman-compose up -d"
            return 1
        }
        
        # Nhóm D – Hướng dẫn thủ công (16-20)
        sysctl_16_manual_privileged() {
            echo "      Hướng dẫn tự thêm privileged: true thủ công..."
            show_manual_guide "Thêm privileged: true thủ công" \
                "Mở file: sudo nano $TARGET_DIR/docker-compose.yml" \
                "Tìm service 'vector' (dòng bắt đầu bằng '  vector:')" \
                "Thêm dòng '    privileged: true' (4 dấu cách) vào sau dòng 'image:'" \
                "Làm tương tự cho 'imgproxy' và 'db'" \
                "Lưu file và thoát, sau đó chạy lại script"
            return 1
        }
        
        sysctl_17_manual_daemon() {
            echo "      Hướng dẫn sửa file daemon.json thủ công..."
            show_manual_guide "Cấu hình Docker daemon thủ công" \
                "Tạo file /etc/docker/daemon.json nếu chưa có" \
                "Thêm nội dung: {\"default-ulimits\": {\"nofile\": {\"Hard\": 65536, \"Name\": \"nofile\", \"Soft\": 65536}}}" \
                "Lưu file và chạy: sudo systemctl restart docker" \
                "Chạy lại script restore"
            return 1
        }
        
        sysctl_18_manual_docker() {
            echo "      Hướng dẫn cài đặt Docker từ kho chính thức..."
            show_manual_guide "Cài Docker từ repository chính thức" \
                "Gỡ Docker hiện tại: sudo apt remove docker.io docker-compose-v2" \
                "Cài Docker CE: curl -fsSL https://get.docker.com | sh" \
                "Thêm user vào group docker: sudo usermod -aG docker $REAL_USER" \
                "Đăng nhập lại và chạy script"
            return 1
        }
        
        sysctl_19_request_nesting() {
            echo "      Yêu cầu nhà cung cấp VPS bật nesting=1..."
            show_manual_guide "Liên hệ nhà cung cấp VPS bật nesting" \
                "Hostinger: Liên hệ support yêu cầu 'enable nesting'" \
                "Namecheap: Yêu cầu 'LXC nesting enabled'" \
                "OVH: Sử dụng template 'Docker' thay vì 'Ubuntu'" \
                "Sau khi xác nhận, chạy lại script này"
            return 1
        }
        
        sysctl_20_switch_kvm() {
            echo "      Chuyển sang VPS dùng KVM..."
            show_manual_guide "Di chuyển sang VPS KVM" \
                "Tạo VPS mới dùng KVM tại nhà cung cấp uy tín (DigitalOcean, Linode, AWS EC2)" \
                "Cài đặt bộ kit Supabase trên VPS mới" \
                "Restore backup từ VPS cũ sang VPS mới" \
                "Cập nhật DNS trỏ về IP mới"
            return 1
        }

        # Áp dụng framework 20 chiến lược
        SYSCTL_STRATEGIES=(
            sysctl_01_delete_line
            sysctl_02_add_privileged
            sysctl_03_add_security_opt
            sysctl_04_docker_run_sysctl
            sysctl_05_clean_cache
            sysctl_06_docker_daemon
            sysctl_07_downgrade_containerd
            sysctl_08_change_runtime
            sysctl_09_disable_apparmor
            sysctl_10_disable_selinux
            sysctl_11_change_docker
            sysctl_12_kernel_params
            sysctl_13_custom_image
            sysctl_14_net_host
            sysctl_15_use_podman
            sysctl_16_manual_privileged
            sysctl_17_manual_daemon
            sysctl_18_manual_docker
            sysctl_19_request_nesting
            sysctl_20_switch_kvm
        )
        
        if apply_all_strategies "sysctl ip_unprivileged_port_start" "try_start" "${SYSCTL_STRATEGIES[@]}"; then
            SUPABASE_STARTED=1
            echo -e "${GREEN}✅ Supabase đã khởi động thành công sau khi áp dụng các chiến lược!${NC}"
        else
            SUPABASE_STARTED=0
            echo -e "${RED}❌ Đã thử tất cả 20 chiến lược nhưng vẫn không khắc phục được lỗi sysctl.${NC}"
            echo "   📋 Lỗi cuối cùng:"
            echo "$LAST_DOCKER_ERR"
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
for i in $(seq 1 10); do
    DB_CONT=$(docker ps --format '{{.Names}}' | grep -E 'supabase.*db|db' | head -1)
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

solve_database_import_problem() {
    local strategy=1
    local success=0
    
    while [ $strategy -le 10 ]; do
        case $strategy in
            1) 
                # Chiến lược 1: Kiểm tra container database đang chạy và pg_isready
                echo "   🔧 Chiến lược 1/10: Kiểm tra container database..."
                if ! docker ps -q --filter "name=$DB_CONT" | grep -q .; then
                    echo "   ⚠️ Container database không đang chạy."
                    echo "   🔄 Đang khởi động lại Supabase..."
                    if ! try_start; then
                        echo "   ❌ Không thể khởi động container database."
                    fi
                else
                    echo "   ✅ Container database đang chạy."
                    # Kiểm tra database sẵn sàng
                    if docker exec -t $DB_CONT pg_isready -U postgres; then
                        echo "   ✅ Database đã sẵn sàng để import."
                    else
                        echo "   ⚠️ Database chưa sẵn sàng, đang chờ..."
                        sleep 10
                        if docker exec -t $DB_CONT pg_isready -U postgres; then
                            echo "   ✅ Database đã sẵn sàng."
                        else
                            echo "   ❌ Database vẫn chưa sẵn sàng."
                        fi
                    fi
                fi ;;
            2) 
                # Chiến lược 2: Nếu container không chạy, thử khởi động lại
                echo "   🔧 Chiến lược 2/10: Thử khởi động lại container database..."
                if ! docker ps -q --filter "name=$DB_CONT" | grep -q .; then
                    echo "   🔄 Đang khởi động container database..."
                    $DOCKER_COMPOSE_CMD -f "$TARGET_DIR/docker-compose.yml" up -d db
                    sleep 15
                    if docker ps -q --filter "name=$DB_CONT" | grep -q .; then
                        echo "   ✅ Container database đã khởi động."
                    else
                        echo "   ❌ Vẫn không thể khởi động container database."
                    fi
                else
                    echo "   ℹ️ Container database đã đang chạy."
                fi ;;
            3) 
                # Chiến lược 3: Kiểm tra file SQL backup có nội dung
                echo "   🔧 Chiến lược 3/10: Kiểm tra file SQL backup..."
                if [ -f "$BACKUP_DIR/database/full_backup.sql.gz" ]; then
                    local file_size=$(stat -c%s "$BACKUP_DIR/database/full_backup.sql.gz" 2>/dev/null || echo "0")
                    if [ "$file_size" -gt 0 ]; then
                        echo "   ✅ File SQL backup có nội dung (kích thước: $file_size bytes)."
                    else
                        echo "   ⚠️ File SQL backup rỗng."
                        return 1
                    fi
                else
                    echo "   ❌ Không tìm thấy file SQL backup."
                    return 1
                fi ;;
            4) 
                # Chiến lược 4: Thử giải nén lại file .sql.gz
                echo "   🔧 Chiến lược 4/10: Thử giải nén lại file SQL..."
                if [ -f "$BACKUP_DIR/database/full_backup.sql.gz" ]; then
                    echo "   Đang giải nén file SQL..."
                    if gunzip -c "$BACKUP_DIR/database/full_backup.sql.gz" > /tmp/restore.sql; then
                        echo "   ✅ Giải nén thành công."
                        local sql_size=$(stat -c%s "/tmp/restore.sql" 2>/dev/null || echo "0")
                        if [ "$sql_size" -gt 0 ]; then
                            echo "   ✅ File SQL giải nén có nội dung."
                        else
                            echo "   ⚠️ File SQL giải nén rỗng."
                            rm -f /tmp/restore.sql
                            return 1
                        fi
                    else
                        echo "   ❌ Giải nén thất bại."
                        return 1
                    fi
                else
                    echo "   ❌ Không tìm thấy file backup để giải nén."
                    return 1
                fi ;;
            5) 
                # Chiến lược 5: Nếu lỗi quyền, chạy với sudo
                echo "   🔧 Chiến lược 5/10: Kiểm tra và xử lý lỗi quyền..."
                if [ -w "/tmp" ]; then
                    echo "   ✅ Có quyền ghi vào /tmp."
                else
                    echo "   ⚠️ Không có quyền ghi vào /tmp, đang thử với sudo..."
                    if sudo touch /tmp/test_write && sudo rm /tmp/test_write; then
                        echo "   ✅ Có quyền sudo để ghi vào /tmp."
                    else
                        echo "   ❌ Không có quyền ghi vào /tmp, đang thử thư mục khác..."
                        local alt_tmp="/home/$REAL_USER/tmp_restore"
                        mkdir -p "$alt_tmp"
                        if [ -w "$alt_tmp" ]; then
                            echo "   Đang sử dụng thư mục thay thế: $alt_tmp"
                            TMP_RESTORE_DIR="$alt_tmp"
                        else
                            echo "   ❌ Không thể tìm được thư mục tạm phù hợp."
                            return 1
                        fi
                    fi
                fi ;;
            6) 
                # Chiến lược 6: Nếu lỗi phiên bản PostgreSQL, thử import bằng pg_restore
                echo "   🔧 Chiến lược 6/10: Thử import bằng pg_restore nếu cần..."
                # Copy file đến container
                docker cp /tmp/restore.sql $DB_CONT:/tmp/
                # Thử import bằng psql trước
                if docker exec -t $DB_CONT psql -U postgres -f /tmp/restore.sql; then
                    echo "   ✅ Import database thành công bằng psql."
                    success=1
                    break
                else
                    echo "   ⚠️ Import bằng psql thất bại, đang thử pg_restore..."
                    # Tạo file dump custom format nếu có thể
                    if command -v pg_dump >/dev/null 2>&1; then
                        echo "   Đang tạo dump custom format..."
                        # Đây là trường hợp phức tạp, thường cần dump lại từ đầu
                        echo "   ℹ️ pg_restore yêu cầu file dump ở định dạng custom (-Fc)."
                        echo "   Bạn có thể cần tạo backup mới với định dạng phù hợp."
                    else
                        echo "   ℹ️ pg_restore không khả dụng trên hệ thống này."
                    fi
                fi ;;
            7) 
                # Chiến lược 7: Hỏi người dùng có muốn import từng bảng một không
                echo "   🔧 Chiến lược 7/10: Hướng dẫn import từng bảng..."
                echo "   📝 Nếu database quá lớn hoặc có lỗi cụ thể, bạn có thể:"
                echo "   1. Mở file /tmp/restore.sql bằng trình soạn thảo"
                echo "   2. Tìm và comment các bảng gây lỗi bằng --"
                echo "   3. Import từng phần nhỏ hơn"
                echo "   4. Sau đó import các bảng còn lại thủ công"
                read -p "   👉 Bạn có muốn thử import từng bảng không? (y/n): " manual_import
                if [ "$manual_import" = "y" ]; then
                    echo "   📋 Đang hiển thị cấu trúc file SQL..."
                    head -20 /tmp/restore.sql
                    echo ""
                    echo "   💡 Bạn có thể edit file /tmp/restore.sql và chạy lại script."
                    echo "   Hoặc import thủ công bằng lệnh:"
                    echo "   docker exec -t $DB_CONT psql -U postgres -f /tmp/restore.sql"
                    return 1
                fi ;;
            8) 
                # Chiến lược 8: Kiểm tra database đã tồn tại chưa
                echo "   🔧 Chiến lược 8/10: Kiểm tra database đã tồn tại..."
                if docker exec -t $DB_CONT psql -U postgres -lqt | cut -d \| -f 1 | grep -qw postgres; then
                    echo "   ⚠️ Database 'postgres' đã tồn tại."
                    read -p "   👉 Bạn có muốn ghi đè database hiện tại không? (y/n): " overwrite_db
                    if [ "$overwrite_db" != "y" ]; then
                        echo "   ℹ️ Hủy import vì người dùng không muốn ghi đè."
                        return 1
                    else
                        echo "   🔄 Đang xóa database cũ..."
                        docker exec -t $DB_CONT psql -U postgres -c "DROP DATABASE IF EXISTS postgres;"
                        docker exec -t $DB_CONT psql -U postgres -c "CREATE DATABASE postgres;"
                    fi
                else
                    echo "   ℹ️ Database 'postgres' chưa tồn tại, sẽ tạo mới."
                fi ;;
            9) 
                # Chiến lược 9: Hướng dẫn tự import thủ công bằng psql
                echo "   🔧 Chiến lược 9/10: Hướng dẫn import thủ công..."
                echo "   📝 Các bước import thủ công bằng psql:"
                echo "   1. Đảm bảo container database đang chạy:"
                echo "      docker ps | grep $DB_CONT"
                echo "   2. Copy file SQL vào container:"
                echo "      docker cp /tmp/restore.sql $DB_CONT:/tmp/"
                echo "   3. Import bằng psql:"
                echo "      docker exec -t $DB_CONT psql -U postgres -f /tmp/\$(basename \$part)"
                echo "   4. Kiểm tra kết quả:"
                echo "      docker exec -t $DB_CONT psql -U postgres -c '\l'"
                read -p "   👉 Bạn đã thử import thủ công chưa? (y/n): " manual_done
                if [ "$manual_done" = "y" ]; then
                    echo "   ✅ Giả sử import thủ công đã thành công."
                    success=1
                    break
                fi ;;
            10) 
                # Chiến lược 10: Hướng dẫn chia nhỏ file SQL lớn
                echo "   🔧 Chiến lược 10/10: Hướng dẫn chia nhỏ file SQL lớn..."
                echo "   📝 Nếu file SQL quá lớn (>1GB), bạn nên chia nhỏ:"
                echo "   1. Cài đặt split: sudo apt install coreutils"
                echo "   2. Chia file: split -l 10000 /tmp/restore.sql /tmp/restore_part_"
                echo "   3. Import từng phần:"
                echo "      for part in /tmp/restore_part_*; do"
                echo "          docker cp \$part $DB_CONT:/tmp/"
                echo "          docker exec -t $DB_CONT psql -U postgres -f /tmp/\$(basename \$part)"
                echo "      done"
                echo ""
                echo "   💡 Hoặc sử dụng công cụ chuyên dụng như pgloader để import hiệu quả hơn."
                return 1 ;;
        esac
        strategy=$((strategy + 1))
    done
    
    if [ $success -eq 1 ]; then
        log_info "Import database thành công"
        return 0
    else
        log_error "Import database thất bại sau khi thử tất cả 10 chiến lược"
        return 1
    fi
}

# Thực thi giải quyết vấn đề import database
if ! solve_database_import_problem; then
    rm -f /tmp/restore.sql
    exit 1
fi

rm -f /tmp/restore.sql
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