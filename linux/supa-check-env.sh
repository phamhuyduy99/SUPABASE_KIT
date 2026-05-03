#!/bin/bash
# ==============================================
# SUPA-CHECK-ENV.SH – Kiểm tra tương thích hệ thống
# -------------------------------------------------
# Script này kiểm tra xem VPS có đủ điều kiện để chạy Supabase không
# và đưa ra hướng dẫn chi tiết nếu không tương thích.
# ==============================================

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

print_title "KIỂM TRA TƯƠNG THÍCH VPS CHO SUPABASE"
echo ""
print_info "Chức năng này sẽ kiểm tra xem máy chủ của bạn có phù hợp để chạy Supabase hay không."
print_info "Quá trình này sẽ mất vài phút, vui lòng đợi..."
echo ""

# Kiểm tra hệ điều hành
print_step 1 5 "KIỂM TRA HỆ ĐIỀU HÀNH"
print_info "Đang xác định hệ điều hành và phiên bản..."

OS_INFO=$(uname -srm)
print_info "Hệ điều hành: $OS_INFO"

# Kiểm tra kiến trúc CPU
CPU_ARCH=$(uname -m)
if [[ "$CPU_ARCH" != "x86_64" ]] && [[ "$CPU_ARCH" != "aarch64" ]] && [[ "$CPU_ARCH" != "arm64" ]]; then
    print_error "❌ Kiến trúc CPU không được hỗ trợ: $CPU_ARCH"
    print_info "💡 Supabase chỉ hỗ trợ x86_64 (64-bit Intel/AMD) hoặc ARM64."
    COMPAT=0
else
    print_success "✅ Kiến trúc CPU được hỗ trợ: $CPU_ARCH"
    COMPAT=1
fi

# Kiểm tra ảo hóa
print_step 2 5 "KIỂM TRA CÔNG NGHỆ ẢO HÓA"
print_info "Đang xác định loại công nghệ ảo hóa..."

VIRT=$(systemd-detect-virt 2>/dev/null || echo "unknown")

if [[ "$VIRT" == "none" ]] || [[ "$VIRT" == "kvm" ]] || [[ "$VIRT" == "qemu" ]]; then
    print_success "✅ Công nghệ ảo hóa được hỗ trợ: $VIRT (KVM hoặc Bare Metal)"
    print_info "💡 Loại ảo hóa này hoàn toàn tương thích với Docker và Supabase."
elif [[ "$VIRT" == "lxc" ]] || [[ "$VIRT" == "openvz" ]]; then
    print_error "❌ Phát hiện công nghệ ảo hóa LXC hoặc OpenVZ"
    print_warning "⚠️  Loại ảo hóa này có thể gây ra lỗi với Docker và Supabase."
    print_info "💡 LXC/OpenVZ là loại ảo hóa container, không phải ảo hóa máy ảo thật sự."
    print_info "💡 Docker yêu cầu quyền truy cập kernel mức thấp mà LXC/OpenVZ thường hạn chế."
    COMPAT=0
else
    print_warning "⚠️  Công nghệ ảo hóa không xác định: $VIRT"
    print_info "💡 Hệ thống của bạn có thể vẫn hoạt động, nhưng chưa được kiểm tra đầy đủ."
fi

# Kiểm tra Docker
print_step 3 5 "KIỂM TRA DOCKER"
print_info "Đang kiểm tra phiên bản và trạng thái Docker..."

if command -v docker &>/dev/null; then
    DOCKER_VERSION=$(docker --version 2>/dev/null || echo "unknown")
    print_success "✅ Docker đã được cài đặt: $DOCKER_VERSION"
    
    # Kiểm tra trạng thái dịch vụ
    if systemctl is-active --quiet docker; then
        print_success "✅ Dịch vụ Docker đang chạy"
    else
        print_error "❌ Dịch vụ Docker không chạy"
        print_info "💡 Hãy khởi động lại Docker: sudo systemctl start docker"
        COMPAT=0
    fi
else
    print_error "❌ Docker chưa được cài đặt"
    print_info "💡 Hãy cài Docker trước khi tiếp tục: curl -fsSL https://get.docker.com | sh"
    COMPAT=0
fi

# Kiểm tra dung lượng
print_step 4 5 "KIỂM TRA DUNG LƯỢNG"
print_info "Đang kiểm tra bộ nhớ RAM và dung lượng đĩa..."

RAM_TOTAL=$(free -m | awk 'NR==2{print $2}')
print_info "Tổng RAM: ${RAM_TOTAL}MB"

if [ "$RAM_TOTAL" -ge 3900 ]; then
    print_success "✅ RAM đủ: ${RAM_TOTAL}MB (tối thiểu 4GB)"
elif [ "$RAM_TOTAL" -ge 1900 ]; then
    print_warning "⚠️  RAM thấp: ${RAM_TOTAL}MB (khuyên dùng trên 2GB)"
    print_info "💡 Hệ thống có thể hoạt động chậm hoặc gặp lỗi nếu dữ liệu lớn."
else
    print_error "❌ RAM quá thấp: ${RAM_TOTAL}MB (tối thiểu 2GB)"
    print_info "💡 Hãy sử dụng VPS có RAM ít nhất 2GB."
    COMPAT=0
fi

DISK_SPACE=$(df . | awk 'NR==2 {print int($4/1024)}')
print_info "Dung lượng trống: ${DISK_SPACE}MB"

if [ "$DISK_SPACE" -ge 19000 ]; then
    print_success "✅ Dung lượng đĩa tốt: ${DISK_SPACE}MB"
elif [ "$DISK_SPACE" -ge 5000 ]; then
    print_warning "⚠️  Dung lượng đĩa thấp: ${DISK_SPACE}MB"
    print_info "💡 Supabase có thể hoạt động nhưng sẽ nhanh đầy nếu có nhiều dữ liệu."
else
    print_error "❌ Không đủ dung lượng: ${DISK_SPACE}MB (cần tối thiểu 5GB)"
    print_info "💡 Hãy dọn dẹp bớt dữ liệu hoặc sử dụng VPS có ổ đĩa lớn hơn."
    COMPAT=0
fi

# Kiểm tra ports
print_step 5 5 "KIỂM TRA CỔNG MẠNG"
print_info "Đang kiểm tra các cổng cần thiết cho Supabase..."

REQUIRED_PORTS=(80 443 5432 8000 8081 8082 8083 8084 8085)
USED_PORTS=()

for port in "${REQUIRED_PORTS[@]}"; do
    if ss -tuln | grep -q ":$port "; then
        USED_PORTS+=("$port")
    fi
done

if [ ${#USED_PORTS[@]} -eq 0 ]; then
    print_success "✅ Tất cả cổng cần thiết đều trống"
else
    print_warning "⚠️  Một số cổng đang được sử dụng: ${USED_PORTS[*]}"
    print_info "💡 Supabase có thể không khởi động nếu các cổng này đang dùng cho dịch vụ khác."
    print_info "💡 Nếu bạn đang chạy Apache, Nginx hoặc dịch vụ khác, hãy tắt tạm thời."
fi

# ---------- Kết luận ----------
echo ""
if [ $COMPAT -eq 1 ]; then
    print_success "🎉 MÁY CHỦ CỦA BẠN TƯƠNG THÍCH HOÀN TOÀN!"
    echo "   ✅ Bạn có thể yên tâm tiếp tục sử dụng các chức năng của bộ kit."
    echo "   ✅ Supabase sẽ hoạt động ổn định trên hệ thống này."
else
    print_error "❌ MÁY CHỦ CỦA BẠN CÓ MỘT SỐ HẠN CHẾ TƯƠNG THÍCH"
    echo ""
    
    if [ "$VIRT" = "lxc" ] || [ "$VIRT" = "openvz" ]; then
        print_warning "❌ NGUYÊN NHÂN CHÍNH: Công nghệ ảo hóa $VIRT hạn chế Docker"
        echo ""
        print_info "📖 GIẢI THÍCH:"
        echo "   - LXC/OpenVZ là công nghệ ảo hóa container (giống như Docker nhưng ở cấp hệ điều hành)"
        echo "   - Docker cần quyền truy cập kernel mức thấp để chạy container"
        echo "   - Loại ảo hóa này thường giới hạn các quyền đó nên Docker không hoạt động đúng"
        echo ""
        print_info "🔧 HƯỚNG DẪN KHẮC PHỤC:"
        echo "   1. Liên hệ nhà cung cấp VPS:"
        echo "      Gửi yêu cầu (ticket hỗ trợ) với nội dung:"
        echo "      'Xin vui lòng kích hoạt tính năng nesting cho container của tôi và áp dụng profile unconfined.'"
        echo "      (Bạn có thể copy-paste dòng trên vào ticket hỗ trợ)"
        echo ""
        echo "   2. Nếu nhà cung cấp không hỗ trợ, hãy chuyển sang VPS dùng công nghệ KVM:"
        echo "      - DigitalOcean: https://www.digitalocean.com/"
        echo "      - Vultr: https://www.vultr.com/"
        echo "      - Linode: https://www.linode.com/"
        echo "      - AWS EC2: https://aws.amazon.com/ec2/"
        echo "      - Google Cloud: https://cloud.google.com/"
        echo ""
        echo "   3. Sau khi có VPS mới (dùng KVM) hoặc đã được kích hoạt nesting, hãy chạy lại script này."
        echo ""
        print_info "💡 LƯU Ý: Các VPS dùng công nghệ KVM (máy ảo thật sự) hoàn toàn tương thích với Docker."
    else
        print_info "🔧 MỘT SỐ VẤN ĐỀ CẦN KHẮC PHỤC:"
        if [ $RAM_TOTAL -lt 1900 ]; then
            echo "   - RAM quá thấp (<2GB): Nâng cấp RAM hoặc dùng VPS có RAM lớn hơn"
        fi
        if [ $DISK_SPACE -lt 5000 ]; then
            echo "   - Dung lượng đĩa không đủ (<5GB): Dọn dẹp hoặc nâng cấp ổ đĩa"
        fi
        if [ ${#USED_PORTS[@]} -gt 0 ]; then
            echo "   - Một số cổng cần thiết đang được sử dụng: ${USED_PORTS[*]}"
            echo "     Tắt các dịch vụ đang dùng các cổng này (Apache, Nginx, v.v.)"
        fi
        echo ""
        print_info "💡 Sau khi khắc phục các vấn đề trên, hãy chạy lại script này để kiểm tra lại."
    fi
    
    echo ""
    print_warning "⚠️  BẠN VẪN CÓ THỂ TIẾP TỤC NHƯNG CÓ THỂ GẶP LỖI:"
    read -p "👉 Bạn có muốn tiếp tục (dù có cảnh báo)? (y/n): " continue_anyway
    if [ "$continue_anyway" != "y" ]; then
        print_info "✅ Đã hủy quá trình. Hãy khắc phục các vấn đề trên rồi thử lại."
        exit 0
    fi
fi

exit $COMPAT