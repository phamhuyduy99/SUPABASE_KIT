#!/bin/bash
# ==============================================
# COMMON.SH – Thư viện dùng chung cho toàn bộ kit
# -------------------------------------------------
# Chứa tất cả các hàm xác thực, kiểm tra môi trường,
# quét trạng thái chức năng, hỗ trợ Google Drive,
# xử lý lỗi apt lock, dung lượng đĩa, mạng, OS...
# ==============================================

# ---------- MÀU SẮC (DÙNG tput, HỖ TRỢ HẦU HẾT TERMINAL) ----------
if [ -t 1 ] && command -v tput &>/dev/null && [ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]; then
    # Terminal hỗ trợ màu
    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    BLUE=$(tput setaf 4)
    MAGENTA=$(tput setaf 5)
    CYAN=$(tput setaf 6)
    WHITE=$(tput setaf 7)
    BOLD=$(tput bold)
    RESET=$(tput sgr0)
    BG_RED=$(tput setab 1)
    BG_GREEN=$(tput setab 2)
    BG_YELLOW=$(tput setab 3)
    BG_BLUE=$(tput setab 4)
    BG_MAGENTA=$(tput setab 5)
    BG_CYAN=$(tput setab 6)
    BG_WHITE=$(tput setab 7)
    # Định dạng đặc biệt
    UNDERLINE=$(tput smul)
    BLINK=$(tput blink)
    REVERSE=$(tput rev)
else
    # Không màu – dùng ký hiệu thay thế cho trực quan
    RED="❌ "
    GREEN="✅ "
    YELLOW="⚠️ "
    BLUE=""
    MAGENTA=""
    CYAN=""
    WHITE=""
    BOLD=""
    RESET=""
    BG_RED=""
    BG_GREEN=""
    BG_YELLOW=""
    BG_BLUE=""
    BG_MAGENTA=""
    BG_CYAN=""
    BG_WHITE=""
    UNDERLINE=""
    BLINK=""
    REVERSE=""
fi

# Biến phụ trợ để in nổi bật
BOLD_RED="${BOLD}${RED}"
BOLD_GREEN="${BOLD}${GREEN}"
BOLD_YELLOW="${BOLD}${YELLOW}"
BOLD_BLUE="${BOLD}${BLUE}"
BOLD_MAGENTA="${BOLD}${MAGENTA}"
BOLD_CYAN="${BOLD}${CYAN}"
BOLD_WHITE="${BOLD}${WHITE}"

# ---------- HÀM TIỆN ÍCH IN THÔNG BÁO ----------
# In thông báo thành công
print_success() { echo -e "${BOLD_GREEN}✓ $*${RESET}"; }
# In thông báo lỗi
print_error()   { echo -e "${BOLD_RED}✗ $*${RESET}"; }
# In thông báo cảnh báo
print_warning() { echo -e "${BOLD_YELLOW}⚠ $*${RESET}"; }
# In thông báo đang làm việc
print_info()    { echo -e "${BOLD_BLUE}ℹ $*${RESET}"; }
# In tiêu đề chính
print_title()   { echo -e "${BOLD_MAGENTA}=== $* ===${RESET}"; }
# In bước hướng dẫn
print_step()    { echo -e "${BOLD_WHITE}[$1/$2] $3${RESET}"; }

# Hiển thị tiến trình đang chạy (spinner)
show_progress() {
    local pid=$1
    local msg="$2"
    local spin='-\|/'
    echo -ne "${BOLD_YELLOW}${msg}... ${RESET}"
    while kill -0 $pid 2>/dev/null; do
        for i in $(seq 0 3); do
            echo -ne "\b${spin:$i:1}"
            sleep 0.2
        done
    done
    echo -e "\b${BOLD_GREEN}✓ Hoàn tất${RESET}"
}

# ---------- HÀM KIỂM TRA NGƯỜI DÙNG THỰC SỰ ----------
# Lấy tên người dùng thực, ngay cả khi đang chạy với sudo
if [ -n "$SUDO_USER" ]; then
    REAL_USER="$SUDO_USER"        # Nếu chạy bằng sudo, SUDO_USER là tên gốc
else
    REAL_USER="$(whoami)"         # Nếu không, dùng whoami
fi

# ---------- HỆ THỐNG LOG ----------
# Xác định file log: ưu tiên /var/log/supabase-kit.log, nếu không có quyền thì dùng ~/supabase-kit.log
if [ -w "/var/log" ]; then
    LOG_FILE="/var/log/supabase-kit.log"
else
    LOG_FILE="$HOME/supabase-kit.log"
fi

# Hàm ghi log với timestamp và tên người dùng thực
log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] [${REAL_USER:-unknown}] $*" >> "$LOG_FILE"
}

log_warn() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] [${REAL_USER:-unknown}] $*" >> "$LOG_FILE"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] [${REAL_USER:-unknown}] $*" >> "$LOG_FILE"
}

# Ghi log bắt đầu phiên làm việc mới
log_info "=============================================="
log_info "Bắt đầu phiên làm việc mới"

# ---------- HỆ THỐNG XỬ LÝ LỖI TOÀN DIỆN ----------
# Framework 10 chiến lược cho mọi vấn đề
solve_problem() {
    local problem_type="$1"
    local strategy=1
    local success=0
    
    while [ $strategy -le 10 ]; do
        case $strategy in
            1) 
                # Chiến lược 1: Tự động kiểm tra và sửa lỗi cơ bản
                if try_strategy_1 "$problem_type"; then
                    success=1
                    break
                fi ;;
            2) 
                # Chiến lược 2: Áp dụng giải pháp thay thế tự động
                if try_strategy_2 "$problem_type"; then
                    success=1
                    break
                fi ;;
            3) 
                # Chiến lược 3: Cấu hình lại hoặc cài đặt lại thành phần liên quan
                if try_strategy_3 "$problem_type"; then
                    success=1
                    break
                fi ;;
            4) 
                # Chiến lược 4: Thử với các tùy chọn cấu hình khác
                if try_strategy_4 "$problem_type"; then
                    success=1
                    break
                fi ;;
            5) 
                # Chiến lược 5: Retry với thời gian chờ và giới hạn số lần
                if try_strategy_5 "$problem_type"; then
                    success=1
                    break
                fi ;;
            6) 
                # Chiến lược 6: Hỏi người dùng trước khi thực hiện thay đổi hệ thống
                if try_strategy_6 "$problem_type"; then
                    success=1
                    break
                fi ;;
            7) 
                # Chiến lược 7: Đưa ra lựa chọn thay thế và hỏi xác nhận
                if try_strategy_7 "$problem_type"; then
                    success=1
                    break
                fi ;;
            8) 
                # Chiến lược 8: Đề xuất giải pháp bán tự động với hướng dẫn chi tiết
                if try_strategy_8 "$problem_type"; then
                    success=1
                    break
                fi ;;
            9) 
                # Chiến lược 9: Hướng dẫn thủ công chi tiết từng bước
                echo -e "${YELLOW}📋 Hướng dẫn thủ công cho vấn đề '$problem_type':${NC}"
                provide_manual_guide_9 "$problem_type"
                read -p "Bạn đã thực hiện theo hướng dẫn chưa? (y/n): " manual_done
                if [ "$manual_done" = "y" ]; then
                    success=1
                    break
                fi ;;
            10) 
                # Chiến lược 10: Hướng dẫn cuối cùng và liên hệ hỗ trợ
                echo -e "${RED}❌ Đã thử tất cả các chiến lược nhưng vẫn không khắc phục được.${NC}"
                echo -e "${MAGENTA}📌 Hướng dẫn cuối cùng cho vấn đề '$problem_type':${NC}"
                provide_final_guide_10 "$problem_type"
                echo ""
                echo -e "${CYAN}💡 Bạn có thể liên hệ hỗ trợ kỹ thuật hoặc tham khảo tài liệu chi tiết.${NC}"
                return 1 ;;
        esac
        strategy=$((strategy + 1))
    done
    
    if [ $success -eq 1 ]; then
        echo -e "${GREEN}✅ Vấn đề '$problem_type' đã được giải quyết thành công!${NC}"
        return 0
    else
        return 1
    fi
}

# Các hàm placeholder cho từng chiến lược - sẽ được triển khai cụ thể trong từng script
try_strategy_1() { return 1; }
try_strategy_2() { return 1; }
try_strategy_3() { return 1; }
try_strategy_4() { return 1; }
try_strategy_5() { return 1; }
try_strategy_6() { return 1; }
try_strategy_7() { return 1; }
try_strategy_8() { return 1; }
provide_manual_guide_9() { echo "Hướng dẫn thủ công cho $1"; }
provide_final_guide_10() { echo "Hướng dẫn cuối cùng cho $1"; }

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
    echo "      Hãy COPY TOÀN BỘ đoạn JSON đó (bao gồm cả dấu ngoặc nhọn { })."
    echo "      Ví dụ: {\"access_token\":\"...\",\"token_type\":\"Bearer\",\"refresh_token\":\"...\",\"expiry\":\"...\"}"
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

    # Hàm giải quyết vấn đề tải file từ Google Drive với 10 chiến lược
    solve_gdrive_download_problem() {
        local strategy=1
        local success=0
        
        while [ $strategy -le 10 ]; do
            case $strategy in
                1) 
                    # Chiến lược 1: Kiểm tra rclone đã cài chưa, nếu chưa thì cài đặt
                    echo "   🔧 Chiến lược 1/10: Kiểm tra và cài đặt rclone nếu cần..."
                    if ! command -v rclone >/dev/null 2>&1; then
                        echo "   ⚠️ Rclone chưa được cài đặt."
                        read -p "   👉 Bạn có muốn cài đặt rclone không? (y/n): " install_rclone
                        if [ "$install_rclone" = "y" ]; then
                            if sudo apt update && sudo apt install -y rclone; then
                                echo "   ✅ Đã cài đặt rclone thành công."
                            else
                                echo "   ❌ Cài đặt rclone thất bại."
                            fi
                        fi
                    else
                        echo "   ℹ️ Rclone đã được cài đặt."
                    fi ;;
                2) 
                    # Chiến lược 2: Kiểm tra remote gdrive đã cấu hình chưa
                    echo "   🔧 Chiến lược 2/10: Kiểm tra cấu hình remote gdrive..."
                    if ! rclone listremotes | grep -q "gdrive:"; then
                        echo "   ⚠️ Remote 'gdrive' chưa được cấu hình."
                        echo "   📝 Đang chạy script cấu hình Google Drive..."
                        if [ -f "./supa-setup-gdrive.sh" ]; then
                            bash ./supa-setup-gdrive.sh
                        else
                            echo "   ❌ Không tìm thấy script supa-setup-gdrive.sh."
                            suggest_gdrive_reconnect
                        fi
                    else
                        echo "   ✅ Remote 'gdrive' đã được cấu hình."
                    fi ;;
                3) 
                    # Chiến lược 3: Kiểm tra token hết hạn
                    echo "   🔧 Chiến lược 3/10: Kiểm tra token Google Drive..."
                    if ! check_gdrive_connection; then
                        echo "   ⚠️ Token Google Drive có thể đã hết hạn."
                        suggest_gdrive_reconnect
                        if check_gdrive_connection; then
                            echo "   ✅ Token đã được làm mới thành công."
                        else
                            echo "   ℹ️ Vui lòng tự tạo token mới theo hướng dẫn trên."
                        fi
                    else
                        echo "   ✅ Token Google Drive vẫn hợp lệ."
                    fi ;;
                4) 
                    # Chiến lược 4: Thử tải lại với retry
                    echo "   🔧 Chiến lược 4/10: Thử tải lại với retry (tối đa 3 lần)..."
                    local retry_count=0
                    local max_retries=3
                    while [ $retry_count -lt $max_retries ]; do
                        echo "   🔄 Lần thử thứ $((retry_count + 1))..."
                        if rclone copy "$remote_path" "$local_path" --progress; then
                            echo "   ✅ Tải thành công sau $((retry_count + 1)) lần thử."
                            success=1
                            break 2  # Thoát khỏi cả vòng lặp while bên ngoài
                        else
                            retry_count=$((retry_count + 1))
                            sleep 5
                        fi
                    done
                    if [ $success -eq 0 ]; then
                        echo "   ❌ Tải thất bại sau $max_retries lần thử."
                    fi ;;
                5) 
                    # Chiến lược 5: Kiểm tra file tải về
                    echo "   🔧 Chiến lược 5/10: Kiểm tra file tải về..."
                    if [ -f "$local_path" ]; then
                        local file_size=$(stat -c%s "$local_path" 2>/dev/null || echo "0")
                        if [ "$file_size" -eq 0 ]; then
                            echo "   ⚠️ File tải về rỗng, đang xóa và thử lại..."
                            rm -f "$local_path"
                            # Thử tải lại một lần nữa
                            if rclone copy "$remote_path" "$local_path" --progress; then
                                echo "   ✅ Tải lại thành công."
                                success=1
                                break
                            fi
                        elif [[ "$local_path" == *.tar.gz ]] && ! tar -tzf "$local_path" >/dev/null 2>&1; then
                            echo "   ⚠️ File không đúng định dạng tar.gz, đang xóa và thử lại..."
                            rm -f "$local_path"
                            if rclone copy "$remote_path" "$local_path" --progress; then
                                echo "   ✅ Tải lại thành công."
                                success=1
                                break
                            fi
                        else
                            echo "   ✅ File tải về hợp lệ."
                            success=1
                            break
                        fi
                    else
                        echo "   ℹ️ File chưa được tải về."
                    fi ;;
                6) 
                    # Chiến lược 6: Kiểm tra dung lượng ổ đĩa
                    echo "   🔧 Chiến lược 6/10: Kiểm tra dung lượng ổ đĩa..."
                    local required_space_mb=1000  # Cần ít nhất 1GB
                    if check_disk_space $required_space_mb "."; then
                        echo "   ✅ Đủ dung lượng để tải file."
                    else
                        echo "   ⚠️ Không đủ dung lượng đĩa để tải file."
                        echo "   📝 Vui lòng giải phóng ít nhất ${required_space_mb}MB dung lượng."
                        return 1
                    fi ;;
                7) 
                    # Chiến lược 7: Hướng dẫn xử lý lỗi mạng
                    echo "   🔧 Chiến lược 7/10: Hướng dẫn xử lý lỗi mạng..."
                    echo "   📝 Nếu gặp lỗi mạng khi tải từ Google Drive:"
                    echo "   1. Thử đổi DNS sang 8.8.8.8 hoặc 1.1.1.1"
                    echo "   2. Nếu đang dùng proxy, hãy cấu hình rclone sử dụng proxy:"
                    echo "      rclone config edit gdrive"
                    echo "      Thêm dòng: http_proxy = http://proxy_host:proxy_port"
                    echo "   3. Thử tải vào thời điểm khác khi mạng ổn định hơn"
                    read -p "   👉 Bạn đã thử các giải pháp trên chưa? (y/n): " network_fixed
                    if [ "$network_fixed" = "y" ]; then
                        echo "   🔄 Đang thử tải lại..."
                        if rclone copy "$remote_path" "$local_path" --progress; then
                            echo "   ✅ Tải thành công."
                            success=1
                            break
                        fi
                    fi ;;
                8) 
                    # Chiến lược 8: Cho phép nhập URL/file local thay thế
                    echo "   🔧 Chiến lược 8/10: Nhập đường dẫn thay thế..."
                    echo "   📝 Bạn có thể sử dụng file backup từ nguồn khác:"
                    read -p "   👉 Nhập đường dẫn file local hoặc URL khác (Enter để bỏ qua): " alt_path
                    if [ -n "$alt_path" ]; then
                        if [ -f "$alt_path" ]; then
                            echo "   Đang sao chép file local..."
                            cp "$alt_path" "$local_path"
                            echo "   ✅ Đã sao chép file thành công."
                            success=1
                            break
                        elif [[ "$alt_path" == http* ]]; then
                            echo "   Đang tải từ URL..."
                            if wget -O "$local_path" "$alt_path"; then
                                echo "   ✅ Đã tải từ URL thành công."
                                success=1
                                break
                            else
                                echo -e "   ${RED}❌ Tải từ URL thất bại.${NC}"
                            fi
                        else
                            echo -e "   ${RED}❌ Đường dẫn không hợp lệ.${NC}"
                        fi
                    else
                        echo "   ℹ️ Bỏ qua nhập đường dẫn thay thế."
                    fi ;;
                9) 
                    # Chiến lược 9: Hướng dẫn tải thủ công
                    echo "   🔧 Chiến lược 9/10: Hướng dẫn tải thủ công từ Google Drive web..."
                    echo "   📝 Các bước tải thủ công:"
                    echo "   1. Truy cập Google Drive và tìm file backup"
                    echo "   2. Tải file về máy tính cá nhân của bạn"
                    echo "   3. Upload file lên VPS bằng lệnh sau:"
                    echo "      scp /đường/dẫn/local/file.tar.gz $REAL_USER@$(hostname):$local_path"
                    echo "   4. Sau khi upload xong, chạy lại script này"
                    read -p "   👉 Bạn đã upload file thủ công chưa? (y/n): " manual_upload
                    if [ "$manual_upload" = "y" ] && [ -f "$local_path" ]; then
                        echo "   ✅ Xác nhận file đã được upload."
                        success=1
                        break
                    fi ;;
                10) 
                    # Chiến lược 10: Kiểm tra checksum SHA256
                    echo "   🔧 Chiến lược 10/10: Kiểm tra checksum SHA256..."
                    echo "   📝 Nếu bạn có file checksum SHA256:"
                    echo "   1. Tạo file checksum tương ứng (ví dụ: backup.tar.gz.sha256)"
                    echo "   2. Chạy lệnh kiểm tra:"
                    echo "      sha256sum -c backup.tar.gz.sha256"
                    echo "   3. Nếu checksum không khớp, file có thể bị hỏng khi tải"
                    echo ""
                    echo "   💡 Nếu không có checksum, bạn có thể tạo backup mới và đảm bảo"
                    echo "   quá trình upload/tải không bị gián đoạn."
                    return 1 ;;
            esac
            strategy=$((strategy + 1))
        done
        
        if [ $success -eq 1 ]; then
            echo -e "${GREEN}✅ Đã tải về: $local_path${NC}"
            echo -e "   ☁️  Nguồn: $remote_path"
            return 0
        else
            echo -e "${RED}❌ Đã thử tất cả 10 chiến lược nhưng vẫn không tải được file từ Google Drive.${NC}"
            return 1
        fi
    }
    
    # Thực thi giải quyết vấn đề tải file từ Google Drive
    solve_gdrive_download_problem
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
    local os=$(uname -s)
    if [ "$os" = "Linux" ]; then
        local version=$(lsb_release -rs)
        if [[ "$version" =~ ^(20\.04|22\.04|24\.04)$ ]]; then
            return 0
        else
            print_error "Ubuntu không được hỗ trợ (cần 20.04/22.04/24.04). Phiên bản: $version"
            return 1
        fi
    elif [ "$os" = "Darwin" ]; then
        print_success "macOS được hỗ trợ (yêu cầu Docker Desktop)."
        return 0
    else
        print_error "Hệ điều hành không được hỗ trợ."
        return 1
    fi
}

# ============================================================
# HÀM KIỂM TRA CÁC THÀNH PHẦN CẦN THIẾT
# ============================================================
check_required_components() {
    local all_good=1
    
    if command -v docker >/dev/null 2>&1; then
        print_success "Docker đã được cài đặt."
    else
        print_error "Docker chưa được cài đặt."
        all_good=0
    fi
    
    if command -v docker-compose >/dev/null 2>&1 || (docker compose version >/dev/null 2>&1); then
        print_success "Docker Compose đã được cài đặt."
    else
        print_error "Docker Compose chưa được cài đặt."
        all_good=0
    fi
    
    if command -v node >/dev/null 2>&1; then
        local node_version=$(node --version | sed 's/v//')
        print_success "Node.js đã được cài đặt (v$node_version)."
    else
        print_warning "Node.js chưa được cài đặt (không bắt buộc)."
    fi
    
    if command -v python3 >/dev/null 2>&1; then
        local python_version=$(python3 --version | cut -d' ' -f2)
        print_success "Python 3 đã được cài đặt (v$python_version)."
    else
        print_warning "Python 3 chưa được cài đặt (không bắt buộc)."
    fi
    
    return $all_good
}

# ============================================================
# HÀM KIỂM TRA TỔNG QUÁT MÔI TRƯỜNG
# ============================================================
check_environment() {
    print_title "KIỂM TRA MÔI TRƯỜNG HỆ THỐNG"
    
    print_info "Kiểm tra phiên bản hệ điều hành..."
    if check_os_version; then
        print_success "Hệ điều hành được hỗ trợ."
    else
        return 1
    fi
    
    print_info "Kiểm tra kết nối mạng..."
    if check_network; then
        print_success "Kết nối mạng ổn định."
    else
        return 1
    fi
    
    print_info "Kiểm tra dung lượng đĩa trống..."
    if check_disk_space 2000; then  # Cần ít nhất 2GB
        print_success "Đủ dung lượng đĩa."
    else
        return 1
    fi
    
    print_info "Kiểm tra RAM..."
    local ram_mb=$(free -m | awk 'NR==2{print $2}')
    if [ "$ram_mb" -ge 2048 ]; then
        print_success "RAM đủ (>= 2GB): ${ram_mb}MB"
    else
        print_warning "RAM thấp (< 2GB): ${ram_mb}MB - Supabase có thể hoạt động chậm"
    fi
    
    print_info "Kiểm tra các thành phần cần thiết..."
    if check_required_components; then
        print_success "Tất cả thành phần cần thiết đã sẵn sàng."
    else
        print_warning "Một số thành phần chưa được cài đặt (chỉ bắt buộc Docker)."
    fi
    
    print_success "Kiểm tra môi trường hoàn tất!"
    return 0
}

# ============================================================
# HÀM QUÉT TRẠNG THÁI CÁC CHỨC NĂNG
# ============================================================
scan_features_status() {
    echo -e "${CYAN}🔍 Quét trạng thái các chức năng...${NC}"
    
    # Kiểm tra file backup_data tự hành
    if [ -f "$SCRIPT_DIR/backup_data/config/.env" ] && [ -f "$SCRIPT_DIR/backup_data/config/docker-compose.yml" ]; then
        echo -e "${GREEN}📦 Gói backup tự hành: SẴN SÀNG${NC}"
    else
        echo -e "${YELLOW}📦 Gói backup tự hành: CHƯA CÓ${NC}"
    fi
    
    # Kiểm tra thư mục Supabase
    if validate_supabase_dir "$SCRIPT_DIR"; then
        echo -e "${GREEN}📁 Thư mục dự án: CÓ (${SCRIPT_DIR})${NC}"
    else
        local auto_dir=$(auto_find_supabase_dir "$SCRIPT_DIR")
        if [ -n "$auto_dir" ]; then
            echo -e "${GREEN}📁 Thư mục dự án: CÓ (${auto_dir})${NC}"
        else
            echo -e "${YELLOW}📁 Thư mục dự án: KHÔNG TÌM THẤY${NC}"
        fi
    fi
    
    # Kiểm tra cấu hình Google Drive
    if command -v rclone >/dev/null 2>&1 && rclone listremotes | grep -q "^gdrive:"; then
        echo -e "${GREEN}☁️  Google Drive: ĐÃ CẤU HÌNH${NC}"
    else
        echo -e "${YELLOW}☁️  Google Drive: CHƯA CẤU HÌNH${NC}"
    fi
    
    # Kiểm tra Docker
    if command -v docker >/dev/null 2>&1; then
        echo -e "${GREEN}🐳 Docker: ĐÃ CÀI ĐẶT${NC}"
    else
        echo -e "${RED}🐳 Docker: CHƯA CÀI ĐẶT${NC}"
    fi
    
    echo ""
}