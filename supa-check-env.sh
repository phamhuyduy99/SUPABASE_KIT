#!/bin/bash
# ==============================================
# SUPA-CHECK-ENV.SH – Kiểm tra VPS có tương thích Supabase không
# ==============================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"   # Dùng chung màu tput mới

echo -e "${BOLD_BLUE}🔍 KIỂM TRA TƯƠNG THÍCH VPS CHO SUPABASE...${RESET}"

# ---------- 1. Kiểm tra ảo hóa ----------
print_info "1. Phát hiện công nghệ ảo hóa..."
VIRT=$(systemd-detect-virt 2>/dev/null || echo "none")
if [ "$VIRT" = "none" ]; then
    VIRT_TYPE="Máy chủ vật lý (Bare Metal) - ${BOLD_GREEN}Tuyệt vời${RESET}"
    COMPAT=1
elif [ "$VIRT" = "kvm" ]; then
    VIRT_TYPE="KVM - ${BOLD_GREEN}Hoàn toàn tương thích${RESET}"
    COMPAT=1
elif [ "$VIRT" = "lxc" ] || [ "$VIRT" = "openvz" ]; then
    VIRT_TYPE="${BOLD_RED}$VIRT${RESET} - ${BOLD_RED}KHÔNG tương thích hoàn toàn với Docker/Supabase${RESET}"
    COMPAT=0
else
    VIRT_TYPE="$VIRT - ${BOLD_YELLOW}Có thể không hỗ trợ đầy đủ, cần kiểm tra thêm${RESET}"
    COMPAT=0
fi
echo -e "   Công nghệ: $VIRT_TYPE"

# ---------- 2. Kiểm tra kernel & modules ----------
print_info "2. Kiểm tra kernel và modules hỗ trợ Docker..."
if [ "$(uname -m)" != "x86_64" ]; then
    echo -e "   ${BOLD_RED}❌ CPU không phải x86_64 – Supabase yêu cầu x86_64.${RESET}"
    COMPAT=0
else
    echo -e "   ${BOLD_GREEN}✅ CPU x86_64.${RESET}"
fi

# Overlay filesystem
if lsmod | grep -q overlay 2>/dev/null; then
    echo -e "   ${BOLD_GREEN}✅ Kernel hỗ trợ overlay.${RESET}"
else
    echo -e "   ${BOLD_YELLOW}⚠️ Chưa load module overlay (có thể ảnh hưởng Docker).${RESET}"
fi

# Kiểm tra quyền sysctl
if sudo sysctl net.ipv4.ip_unprivileged_port_start=2 2>/dev/null; then
    echo -e "   ${BOLD_GREEN}✅ Có thể thay đổi sysctl (quan trọng với Supabase).${RESET}"
else
    echo -e "   ${BOLD_RED}❌ Không đủ quyền sysctl – Supabase sẽ gặp lỗi khởi động.${RESET}"
    COMPAT=0
fi

# ---------- 3. Kiểm tra Docker ----------
print_info "3. Kiểm tra Docker..."
if ! command -v docker &>/dev/null; then
    echo -e "   ${BOLD_YELLOW}⚠️ Docker chưa cài đặt. Bạn có thể cài bằng script restore.${RESET}"
else
    if docker run --rm hello-world &>/dev/null; then
        echo -e "   ${BOLD_GREEN}✅ Docker hoạt động tốt.${RESET}"
    else
        echo -e "   ${BOLD_RED}❌ Docker không chạy được container. Kiểm tra quyền hoặc cài đặt.${RESET}"
        COMPAT=0
    fi
fi

# ---------- Kết luận ----------
echo ""
if [ $COMPAT -eq 1 ]; then
    print_success "VPS của bạn TƯƠNG THÍCH để cài Supabase."
    echo "   Bạn có thể tiếp tục sử dụng chức năng Khôi phục/Đóng băng."
else
    print_error "VPS của bạn KHÔNG TƯƠNG THÍCH hoàn toàn."
    if [ "$VIRT" = "lxc" ] || [ "$VIRT" = "openvz" ]; then
        echo -e "${BOLD_YELLOW}   - Nguyên nhân chính: Công nghệ ảo hóa ${VIRT} hạn chế Docker.${RESET}"
        echo "   - Cần chuyển sang VPS dùng KVM (DigitalOcean, Vultr, Linode, AWS EC2...)."
        echo "   - Hoặc yêu cầu nhà cung cấp VPS bật 'nesting' và cấp quyền sysctl."
    else
        echo "   - Kiểm tra các mục ở trên và khắc phục theo hướng dẫn."
    fi
fi