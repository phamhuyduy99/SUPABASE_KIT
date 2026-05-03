#!/bin/bash
# ==============================================
# SUPA-START.SH – Khởi động Supabase Kit trên tất cả nền tảng
# -------------------------------------------------
# Script này sẽ xác định hệ điều hành và hướng dẫn người dùng
# cách sử dụng Supabase Kit phù hợp với nền tảng của họ.
# ==============================================

# Detect OS
detect_os() {
    case "$(uname -s)" in
        Linux*)
            if [[ -f /.dockerenv ]]; then
                echo "docker"
            else
                echo "linux"
            fi
            ;;
        Darwin*)
            echo "macos"
            ;;
        CYGWIN*|MINGW*|MSYS*)
            echo "windows-cygwin"
            ;;
        *)
            echo "linux"  # Mặc định là Linux
            ;;
    esac
}

# Main function
main() {
    echo "🚀 Khởi động Supabase Kit"
    echo "=========================="
    
    OS_TYPE=$(detect_os)
    
    case "$OS_TYPE" in
        "linux"|"docker"|"macos")
            echo "Phát hiện hệ điều hành: $OS_TYPE"
            echo ""
            echo "🔹 Để sử dụng Supabase Kit trên Linux/macOS:"
            echo "   1. cd linux/"
            echo "   2. chmod +x supa-*.sh common.sh"
            echo "   3. ./supa-menu.sh"
            echo ""
            echo "🔹 Hoặc sử dụng trực tiếp các script:"
            echo "   ./supa-freeze.sh     # Backup hệ thống"
            echo "   ./supa-restore.sh    # Khôi phục hệ thống"
            echo "   ./supa-status.sh     # Kiểm tra trạng thái"
            echo "   ./supa-check-env.sh  # Kiểm tra môi trường"
            ;;
        "windows-cygwin")
            echo "Phát hiện hệ điều hành: Windows (Cygwin/MSYS2)"
            echo ""
            echo "🔹 Để sử dụng Supabase Kit trên Windows:"
            echo "   1. Mở PowerShell với quyền Administrator"
            echo "   2. cd windows/"
            echo "   3. .\\Start-SupabaseKit.ps1"
            echo ""
            echo "🔹 Nếu không có quyền Administrator:"
            echo "   - Có thể gặp hạn chế khi cài đặt HTTPS"
            echo "   - Một số chức năng yêu cầu quyền cao hơn"
            ;;
        *)
            echo "Không thể xác định hệ điều hành chính xác."
            echo "Vui lòng xem README.md để biết cách sử dụng phù hợp với hệ điều hành của bạn."
            ;;
    esac
    
    echo ""
    echo "📖 Tài liệu hướng dẫn:"
    echo "   - README.md          # Tài liệu tổng quan"
    echo "   - README-WINDOWS.md  # Hướng dẫn cho Windows"
    echo "   - README-MACOS.md    # Hướng dẫn cho macOS"
    echo "   - HUONG_DAN_SU_DUNG.md # Hướng dẫn chi tiết bằng tiếng Việt"
}

# Call main function
main "$@"