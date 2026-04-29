#!/bin/bash
# ==============================================
# COMMON.SH – Thư viện dùng chung cho toàn bộ kit
# -------------------------------------------------
# Chứa tất cả các hàm xác thực, kiểm tra môi trường,
# quét trạng thái chức năng, hỗ trợ Google Drive,
# xử lý lỗi apt lock, dung lượng đĩa, mạng, OS...
# ==============================================

# ---------- MÀU SẮC ----------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'   # No Color

# ---------- BIẾN TOÀN CỤC ----------
# Lấy tên người dùng thực, ngay cả khi đang chạy với sudo
if [ -n "$SUDO_USER" ]; then
    REAL_USER="$SUDO_USER"        # Nếu chạy bằng sudo, SUDO_USER là tên gốc
else
    REAL_USER="$(whoami)"         # Nếu không, dùng whoami
fi

# ---------- PHÁT HIỆN DOCKER COMPOSE ----------
detect_docker_compose() {
    if docker compose version &>/dev/null 2>&1; then
        DOCKER_COMPOSE_CMD="docker compose"
    elif command -v docker-compose &>/dev/null; then
        DOCKER_COMPOSE_CMD="docker-compose"
    else
        echo -e "${RED}❌ Không tìm thấy docker compose. Vui lòng cài đặt Docker.${NC}"
        exit 1
    fi
}
detect_docker_compose
export DOCKER_COMPOSE_CMD

# ============================================================
# HÀM YÊU CẦU QUYỀN SUDO HOẶC THOÁT (kèm hướng dẫn)
# ============================================================
require_sudo_or_exit() {
    if ! sudo -n true 2>/dev/null; then
        echo -e "${RED}❌ Hành động này cần quyền sudo (quản trị).${NC}"
        echo "   Hiện tại bạn đang là: $REAL_USER"
        echo "   Để được cấp quyền sudo, hãy nhờ quản trị viên chạy:"
        echo "   sudo usermod -aG sudo $REAL_USER"
        echo "   Sau đó đăng xuất và đăng nhập lại."
        echo "   Hoặc bạn có thể chạy lại script với sudo:"
        echo "   sudo bash $0"
        exit 1
    fi
}

# ============================================================
# HÀM KIỂM TRA DOMAIN HỢP LỆ
# ============================================================
validate_domain() {
    local domain=$1
    if [[ ! "$domain" =~ ^([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}$ ]]; then
        echo -e "${RED}Domain không hợp lệ. Phải có dạng như api.example.com${NC}"
        return 1
    fi
    return 0
}

# ============================================================
# HÀM KIỂM TRA THƯ MỤC DỰ ÁN SUPABASE HỢP LỆ
# ============================================================
validate_supabase_dir() {
    local dir=$1
    if [ -f "$dir/.env" ] && [ -f "$dir/docker-compose.yml" ]; then
        return 0
    else
        return 1
    fi
}

# ============================================================
# HÀM NHẬP THƯ MỤC DỰ ÁN KHI KHÔNG TÌM THẤY
# ============================================================
input_supabase_dir() {
    local dir=""
    while true; do
        read -p "Nhập đường dẫn thư mục Supabase (chứa .env và docker-compose.yml): " dir
        if validate_supabase_dir "$dir"; then
            echo "$dir"
            return 0
        else
            echo -e "${RED}Thư mục '$dir' không hợp lệ. Vui lòng thử lại.${NC}"
        fi
    done
}

# ============================================================
# HÀM TỰ ĐỘNG DÒ TÌM THƯ MỤC DỰ ÁN
# ============================================================
auto_find_supabase_dir() {
    local start_dir="$1"
    local dir="$start_dir"
    for i in {1..5}; do
        if validate_supabase_dir "$dir"; then
            echo "$dir"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    return 1
}

# ============================================================
# HÀM KIỂM TRA FILE BACKUP HỢP LỆ
# ============================================================
validate_backup_file() {
    local file=$1
    if [ ! -f "$file" ]; then
        echo -e "${RED}File '$file' không tồn tại.${NC}"
        return 1
    fi
    if [[ ! "$file" =~ \.tar\.gz$ ]]; then
        echo -e "${RED}File phải có đuôi .tar.gz (ví dụ: backup-20260425.tar.gz)${NC}"
        return 1
    fi
    return 0
}

# ============================================================
# HÀM KIỂM TRA CỔNG 80/443 ĐANG BỊ AI CHIẾM
# ============================================================
check_port() {
    local port=$1
    local pid=$(sudo ss -tlnp "sport = :$port" 2>/dev/null | grep -Po '(?<=pid=)\d+' | head -1)
    if [ -z "$pid" ]; then
        echo "FREE"
        return
    fi
    if grep -q 'docker' /proc/$pid/cgroup 2>/dev/null; then
        local container_id=$(cat /proc/$pid/cgroup | grep 'docker' | head -1 | sed 's/.*\/docker\/\(.*\)/\1/' | cut -c1-12)
        local container_name=$(docker ps --format "{{.Names}}" --filter "id=$container_id")
        echo "DOCKER|${container_name:-unknown}"
    else
        local proc_name=$(ps -p $pid -o comm=)
        echo "HOST|${proc_name:-unknown}"
    fi
}

# ============================================================
# HÀM KIỂM TRA XUNG ĐỘT DOMAIN TRONG CẤU HÌNH NGINX
# ============================================================
check_nginx_domain_conflict() {
    local domain=$1
    if grep -r "server_name $domain" /etc/nginx/sites-enabled/ >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# ============================================================
# HÀM HỎI GHI ĐÈ FILE CẤU HÌNH
# ============================================================
offer_overwrite_config() {
    local file=$1
    if [ -f "$file" ]; then
        echo -e "${YELLOW}File cấu hình $file đã tồn tại.${NC}"
        read -p "Bạn có muốn ghi đè không? (y/n): " ans
        if [ "$ans" != "y" ]; then
            echo "Hủy bỏ."
            return 1
        fi
        sudo cp "$file" "${file}.backup.$(date +%s)"
        echo "Đã sao lưu file cũ."
    fi
    return 0
}

# ============================================================
# HÀM TỰ ĐỘNG CẤP QUYỀN THỰC THI CHO CÁC FILE .sh
# ============================================================
auto_chmod_sh() {
    for f in *.sh; do
        [ -f "$f" ] && chmod +x "$f" 2>/dev/null
    done
}

# ============================================================
# CÁC HÀM LIÊN QUAN RCLONE (Google Drive)
# ============================================================

# Đảm bảo rclone đã cài và remote gdrive đã được cấu hình
ensure_rclone_gdrive() {
    if ! command -v rclone &> /dev/null; then
        echo -e "${YELLOW}rclone chưa cài đặt. Cần để upload/tải từ Google Drive.${NC}"
        read -p "Cài đặt rclone ngay? (y/n): " install_rclone
        if [ "$install_rclone" = "y" ]; then
            if ! sudo -n true 2>/dev/null; then
                echo -e "${RED}❌ Bạn cần quyền sudo để cài đặt rclone.${NC}"
                echo "   Hãy chạy: sudo bash supa-start.sh"
                echo "   hoặc tự cài rclone theo hướng dẫn tại https://rclone.org/install/"
                return 1
            fi
            echo "📥 Đang tải và cài đặt rclone..."
            curl -s https://rclone.org/install.sh | sudo bash >/dev/null 2>&1
            if ! command -v rclone &> /dev/null; then
                echo -e "${RED}❌ Cài đặt rclone thất bại. Vui lòng thử lại hoặc cài thủ công.${NC}"
                return 1
            fi
            echo -e "${GREEN}✅ rclone đã được cài đặt thành công.${NC}"
        else
            echo "Bỏ qua cài đặt rclone."
            return 1
        fi
    fi

    if ! rclone listremotes | grep -q "^gdrive:"; then
        echo -e "${YELLOW}Remote 'gdrive' chưa được cấu hình.${NC}"
        echo "   Để cấu hình, hãy chọn mục 6 (Cấu hình Google Drive) trong menu chính."
        echo "   Hoặc bạn có thể cấu hình ngay bây giờ:"
        read -p "   Bạn có muốn cấu hình Google Drive ngay không? (y/n): " setup_gdrive
        if [ "$setup_gdrive" = "y" ]; then
            # Gọi script setup chuyên dụng thay vì rclone config thô
            if [ -f "$SCRIPT_DIR/supa-setup-gdrive.sh" ]; then
                bash "$SCRIPT_DIR/supa-setup-gdrive.sh"
            else
                echo -e "${RED}Không tìm thấy script cấu hình Google Drive.${NC}"
                return 1
            fi
        else
            return 1
        fi
    fi
    rclone mkdir gdrive:supabase-backups 2>/dev/null || true
    return 0
}

# Kiểm tra kết nối Google Drive – có hiển thị trạng thái ra terminal
check_gdrive_connection() {
    echo -n "🔍 Đang kiểm tra kết nối Google Drive..."
    if rclone about gdrive: >/dev/null 2>&1; then
        echo -e " ${GREEN}OK${NC}"
        return 0
    else
        echo -e " ${RED}THẤT BẠI${NC}"
        echo -e "${RED}❌ Không thể kết nối Google Drive. Token có thể đã hết hạn hoặc mất kết nối.${NC}"
        return 1
    fi
}

# Gợi ý làm mới token nếu kết nối thất bại
# KHÔNG dùng rclone config reconnect (yêu cầu trình duyệt trên VPS)
# Thay vào đó, hướng dẫn tạo token trên máy cá nhân và tự cập nhật
suggest_gdrive_reconnect() {
    echo ""
    echo -e "${YELLOW}📌 Token Google Drive đã hết hạn hoặc không hợp lệ.${NC}"
    echo "   Để làm mới, bạn cần thực hiện các bước sau:"
    echo ""
    echo "   1. Trên máy tính cá nhân (Windows/Mac/Linux), mở terminal và chạy:"
    echo "      rclone authorize \"drive\""
    echo "      (Nếu chưa cài rclone, tải từ https://rclone.org/downloads/)"
    echo ""
    echo "   2. Trình duyệt sẽ mở ra, yêu cầu bạn đăng nhập Google và cấp quyền."
    echo "      Sau khi cho phép, terminal sẽ hiển thị một đoạn JSON."
    echo "      Hãy COPY TOÀN BỘ đoạn JSON đó (bao gồm cả dấu { })."
    echo ""
    echo "   3. Quay lại đây và DÁN đoạn JSON vào khi được yêu cầu."
    echo ""
    read -p "👉 Bạn có muốn cập nhật token ngay bây giờ không? (y/n): " do_update
    if [ "$do_update" != "y" ]; then
        echo "Hủy bỏ. Bạn có thể chạy lại sau."
        return 1
    fi

    # Nhận token mới từ người dùng
    read -p "👉 Dán đoạn JSON token mới của bạn vào đây: " token
    if [ -z "$token" ]; then
        echo -e "${RED}Token không được để trống.${NC}"
        return 1
    fi

    # Cập nhật token trong file cấu hình rclone
    local config_file="$HOME/.config/rclone/rclone.conf"
    if [ ! -f "$config_file" ]; then
        echo -e "${RED}❌ Không tìm thấy file cấu hình rclone.${NC}"
        return 1
    fi

    # Tạo file tạm thay thế section [gdrive] bằng token mới
    local tmp_conf="/tmp/rclone_renew_$$.conf"
    awk -v new_token="token = $token" '
        /^\[gdrive\]/ { in_gdrive=1; print; next }
        in_gdrive && /^\[/ { in_gdrive=0 }
        in_gdrive && /^token / { print new_token; next }
        { print }
    ' "$config_file" > "$tmp_conf"

    # Kiểm tra xem file mới có hoạt động không
    if rclone --config "$tmp_conf" about gdrive: >/dev/null 2>&1; then
        mv "$tmp_conf" "$config_file"
        chmod 600 "$config_file"
        echo -e "${GREEN}✅ Token đã được cập nhật thành công!${NC}"
        return 0
    else
        echo -e "${RED}❌ Token mới không hợp lệ. Vui lòng thử lại.${NC}"
        rm -f "$tmp_conf"
        return 1
    fi
}

# Upload file lên Google Drive – kèm thông báo chi tiết từng bước và hướng dẫn sử dụng
upload_to_gdrive() {
    local file=$1
    local folder=${2:-supabase-backups}

    echo -e "${YELLOW}📤 Chuẩn bị upload lên Google Drive...${NC}"
    if ! check_gdrive_connection; then
        suggest_gdrive_reconnect
        if ! check_gdrive_connection; then
            echo -e "${RED}Hủy upload vì chưa kết nối được Google Drive.${NC}"
            return 1
        fi
    fi

    echo "📤 Đang tải lên Google Drive (thư mục gốc / $folder)..."
    rclone copy "$file" "gdrive:$folder" --progress && {
        echo -e "${GREEN}✅ Đã upload thành công!${NC}"
        echo -e "   📂 File: $file"
        echo -e "   ☁️  Vị trí: Google Drive > $folder > $(basename "$file")"
        echo -e "   📌 Để khôi phục hệ thống từ file này trên bất kỳ VPS nào:"
        echo -e "      1. Đảm bảo đã cấu hình Google Drive (chọn mục 6 trong menu)."
        echo -e "      2. Chọn mục 2 (Restore) và khi được hỏi đường dẫn file backup, nhập:"
        echo -e "         gdrive:supabase-backups/$(basename "$file")"
        echo -e "      3. Script sẽ tự động tải file từ Google Drive về và khôi phục."
        echo -e "   💡 Nếu bạn muốn tải về máy cá nhân, vào Google Drive, vào thư mục 'supabase-backups' và tải xuống."
    } || {
        echo -e "${RED}Có lỗi khi upload. Kiểm tra kết nối và dung lượng Drive.${NC}"
        if ! check_gdrive_connection; then
            suggest_gdrive_reconnect
        fi
        return 1
    }
}

# Tải file từ Google Drive – kèm thông báo chi tiết
download_from_gdrive() {
    local remote_path=$1
    local local_path=$2

    echo -e "${YELLOW}📥 Chuẩn bị tải từ Google Drive...${NC}"
    if ! check_gdrive_connection; then
        suggest_gdrive_reconnect
        if ! check_gdrive_connection; then
            echo -e "${RED}Hủy tải vì chưa kết nối được Google Drive.${NC}"
            return 1
        fi
    fi

    echo "📥 Đang tải từ Google Drive..."
    rclone copy "$remote_path" "$local_path" --progress && {
        echo -e "${GREEN}✅ Đã tải về: $local_path${NC}"
        echo -e "   ☁️  Nguồn: $remote_path"
    } || {
        echo -e "${RED}Có lỗi khi tải từ Google Drive.${NC}"
        if ! check_gdrive_connection; then
            suggest_gdrive_reconnect
        fi
        return 1
    }
}

# ============================================================
# HÀM CHỜ KHOÁ APT (tránh lỗi "Could not get lock")
# ============================================================
wait_for_apt_lock() {
    local max_wait=300  # 5 phút
    local waited=0
    echo -n "🔍 Đang chờ khóa apt được giải phóng"
    while sudo fuser /var/lib/apt/lists/lock /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
        sleep 5
        waited=$((waited + 5))
        echo -n "."
        if [ $waited -ge $max_wait ]; then
            echo ""
            echo -e "${RED}❌ Đã chờ 5 phút nhưng apt vẫn bị khóa. Có thể có tiến trình bị treo.${NC}"
            echo "   Hãy thử chạy: sudo killall apt-get apt dpkg"
            return 1
        fi
    done
    echo ""
    echo -e "${GREEN}✅ apt đã sẵn sàng.${NC}"
    return 0
}

# ============================================================
# HÀM KIỂM TRA DUNG LƯỢNG ĐĨA TRỐNG
# ============================================================
check_disk_space() {
    local required_mb=$1
    local path=${2:-/tmp}
    local available=$(df -BM "$path" | tail -1 | awk '{print $4}' | sed 's/M//')
    if [ -z "$available" ] || [ "$available" -lt "$required_mb" ]; then
        echo -e "${RED}❌ Không đủ dung lượng đĩa. Cần ít nhất ${required_mb}MB, hiện chỉ có ${available:-?}MB tại $path.${NC}"
        return 1
    fi
    return 0
}

# ============================================================
# HÀM KIỂM TRA KẾT NỐI MẠNG
# ============================================================
check_network() {
    if ping -c 2 8.8.8.8 >/dev/null 2>&1; then
        return 0
    else
        echo -e "${RED}❌ Không có kết nối Internet. Vui lòng kiểm tra mạng.${NC}"
        return 1
    fi
}

# ============================================================
# HÀM KIỂM TRA PHIÊN BẢN HỆ ĐIỀU HÀNH
# ============================================================
check_os_version() {
    local version=$(lsb_release -rs)
    if [[ "$version" =~ ^(20\.04|22\.04|24\.04)$ ]]; then
        return 0
    else
        echo -e "${RED}❌ Hệ điều hành không được hỗ trợ (cần Ubuntu 20.04/22.04/24.04). Phiên bản hiện tại: $version${NC}"
        return 1
    fi
}

# ============================================================
# HÀM THỬ LẠI LỆNH KHI THẤT BẠI
# ============================================================
retry_command() {
    local max_retry=3
    local count=0
    until "$@"; do
        count=$((count+1))
        if [ $count -ge $max_retry ]; then
            echo -e "${RED}❌ Lệnh thất bại sau $max_retry lần thử: $*${NC}"
            return 1
        fi
        echo "⚠️ Lệnh thất bại, thử lại lần $count..."
        sleep 2
    done
}

# ============================================================
# QUÉT TRẠNG THÁI CHỨC NĂNG (phiên bản phân biệt Docker)
# ============================================================
scan_features_status() {
    echo -e "${YELLOW}Đang quét hệ thống...${NC}"

    local docker_installed=0
    local docker_usable=0
    local nginx_ok=0
    local certbot_ok=0
    local sudo_ok=0
    local cron_ok=0

    # Docker
    if command -v docker &> /dev/null; then
        docker_installed=1
        if docker ps &> /dev/null; then
            docker_usable=1
        fi
    fi

    # Các thành phần khác
    command -v nginx &> /dev/null && nginx_ok=1
    command -v certbot &> /dev/null && certbot_ok=1
    sudo -n true 2>/dev/null && sudo_ok=1
    command -v crontab &> /dev/null && cron_ok=1

    echo ""
    echo "----------------------------------------"
    echo "        TRẠNG THÁI CHỨC NĂNG"
    echo "----------------------------------------"

    # 1. Đóng băng
    if [ $docker_usable -eq 1 ]; then
        echo -e "1. 🧊 Đóng băng hệ thống            ✅ Sẵn sàng"
    elif [ $docker_installed -eq 1 ]; then
        echo -e "1. 🧊 Đóng băng hệ thống            ❌ Cần quyền Docker (thêm user vào group docker)"
    else
        echo -e "1. 🧊 Đóng băng hệ thống            ❌ Cần cài Docker"
    fi

    # 2. Khôi phục
    if [ $docker_usable -eq 1 ]; then
        echo -e "2. ♻️  Khôi phục hệ thống            ✅ Sẵn sàng"
    elif [ $docker_installed -eq 1 ]; then
        echo -e "2. ♻️  Khôi phục hệ thống            ❌ Cần quyền Docker (thêm user vào group docker)"
    else
        echo -e "2. ♻️  Khôi phục hệ thống            ❌ Cần cài Docker"
    fi

    # 3. Kiểm tra trạng thái
    if [ $docker_usable -eq 1 ]; then
        echo -e "3. 📊 Kiểm tra trạng thái            ✅ Sẵn sàng"
    elif [ $docker_installed -eq 1 ]; then
        echo -e "3. 📊 Kiểm tra trạng thái            ❌ Cần quyền Docker (thêm user vào group docker)"
    else
        echo -e "3. 📊 Kiểm tra trạng thái            ❌ Cần cài Docker"
    fi

    # 4. Cài HTTPS
    if [ $nginx_ok -eq 1 ] && [ $certbot_ok -eq 1 ] && [ $sudo_ok -eq 1 ]; then
        echo -e "4. 🌐 Cài HTTPS & domain             ✅ Sẵn sàng"
    elif [ $nginx_ok -eq 0 ] || [ $certbot_ok -eq 0 ]; then
        echo -e "4. 🌐 Cài HTTPS & domain             ❌ Cần cài Nginx/Certbot (cần sudo)"
    else
        echo -e "4. 🌐 Cài HTTPS & domain             ❌ Cần quyền sudo"
    fi

    # 5. Tự động backup
    if [ $cron_ok -eq 1 ]; then
        echo -e "5. ⏰ Thiết lập tự động backup        ✅ Sẵn sàng"
    else
        echo -e "5. ⏰ Thiết lập tự động backup        ❌ Cần cài cron (sudo)"
    fi

    # 6. Cấu hình Google Drive
    if command -v rclone &> /dev/null; then
        echo -e "6. 🔧 Cấu hình Google Drive           ✅ Sẵn sàng"
    else
        echo -e "6. 🔧 Cấu hình Google Drive           ❌ Cần cài rclone (có thể không cần sudo)"
    fi

    echo "----------------------------------------"

    # Hướng dẫn chi tiết nếu thiếu
    if [ $docker_usable -eq 0 ] || [ $nginx_ok -eq 0 ] || [ $certbot_ok -eq 0 ] || [ $sudo_ok -eq 0 ]; then
        echo ""
        echo -e "${YELLOW}📌 HƯỚNG DẪN KHẮC PHỤC:${NC}"

        if [ $sudo_ok -eq 0 ]; then
            echo "   🔹 Bạn chưa có quyền sudo."
            echo "      Để được cấp quyền, nhờ quản trị viên chạy:"
            echo "      sudo usermod -aG sudo $REAL_USER"
            echo "      Sau đó đăng xuất và đăng nhập lại."
        fi

        if [ $docker_installed -eq 0 ]; then
            echo "   🔹 Docker chưa được cài đặt."
            echo "      (Cần sudo) Hãy chạy các lệnh sau:"
            echo "      sudo apt update && sudo apt install -y docker.io docker-compose-v2"
            echo "      sudo usermod -aG docker $REAL_USER"
            echo "      Sau đó đăng xuất và đăng nhập lại."
        elif [ $docker_usable -eq 0 ]; then
            echo "   🔹 Docker đã được cài nhưng bạn chưa có quyền sử dụng."
            echo "      (Cần sudo) Hãy chạy lệnh:"
            echo "      sudo usermod -aG docker $REAL_USER"
            echo "      Sau đó đăng xuất và đăng nhập lại."
        fi

        if [ $nginx_ok -eq 0 ]; then
            echo "   🔹 Nginx chưa được cài đặt."
            echo "      (Cần sudo) Hãy chạy:"
            echo "      sudo apt install -y nginx"
        fi

        if [ $certbot_ok -eq 0 ]; then
            echo "   🔹 Certbot chưa được cài đặt."
            echo "      (Cần sudo) Hãy chạy:"
            echo "      sudo apt install -y certbot python3-certbot-nginx"
        fi

        echo ""
    fi
}