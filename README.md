# Supabase Kit Toàn Năng

**Supabase Kit** là bộ công cụ quản trị và vận hành hệ thống Supabase với các tính năng:
- Đóng băng hệ thống (Backup)
- Khôi phục hệ thống (Restore)
- Kiểm tra trạng thái hệ thống
- Kiểm tra môi trường tương thích
- Hỗ trợ đa nền tảng: Linux, macOS, Windows
- Giao diện trực quan, màu sắc rõ ràng
- Hướng dẫn bằng tiếng Việt

## 📁 Cấu trúc thư mục

```
supabase-kit/
├── linux/                 # Script cho Linux & macOS
│   ├── common.sh
│   ├── supa-menu.sh
│   ├── supa-freeze.sh
│   ├── supa-restore.sh
│   ├── supa-setup-nginx.sh
│   ├── supa-status.sh
│   ├── supa-setup-gdrive.sh
│   ├── supa-check-env.sh
│   ├── supa-freeze-enhanced.sh    # Phiên bản nâng cao
│   ├── supa-restore-enhanced.sh   # Phiên bản nâng cao
│   └── supa-start.sh      # Điểm vào chung cho Linux/macOS
├── windows/               # Script PowerShell cho Windows
│   ├── SupabaseKit.psm1   # Module chứa hàm dùng chung
│   ├── Start-SupabaseKit.ps1
│   ├── Invoke-Freeze.ps1
│   ├── Invoke-Restore.ps1
│   ├── Invoke-Status.ps1
│   ├── Invoke-CheckEnv.ps1
│   └── Install-DockerDesktop.ps1 (tùy chọn)
├── README.md              # Hướng dẫn tổng quan
├── README-WINDOWS.md      # Hướng dẫn riêng cho Windows
├── README-MACOS.md        # Hướng dẫn riêng cho macOS
├── HUONG_DAN_SU_DUNG.md   # Hướng dẫn sử dụng chi tiết cho người mới
├── enhanced-features-guide.sh  # Hướng dẫn sử dụng tính năng nâng cao
├── quick-start.sh         # Hướng dẫn nhanh
├── backup-config.sh       # Sao lưu cấu hình kit
├── check-completeness.sh  # Kiểm tra tính toàn vẹn
├── initialize-kit.sh      # Khởi tạo cấu trúc kit
└── setup-permissions.sh   # Cấp quyền thực thi
```

## ✅ Yêu cầu hệ thống

- **RAM**: Tối thiểu 4GB (khuyên dùng 8GB trở lên)
- **Ổ cứng**: Tối thiểu 20GB trống
- **Internet**: Kết nối ổn định
- **Docker & Docker Compose**: Đã cài đặt

## 🚀 Cách sử dụng

### Linux/macOS:

1. Giải nén thư mục `supabase-kit`
2. Di chuyển vào thư mục `linux`
3. Chạy lệnh:
   ```bash
   chmod +x *.sh
   ./supa-start.sh
   ```

### Windows:

1. Giải nén thư mục `supabase-kit`
2. Mở PowerShell với quyền Administrator
3. Di chuyển vào thư mục `windows`
4. Chạy lệnh:
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   .\Start-SupabaseKit.ps1
   ```

## 🔧 Các tính năng chính

- **Backup/Freeze**: Sao lưu toàn bộ cấu hình và dữ liệu hệ thống
- **Restore**: Khôi phục hệ thống từ bản backup
- **Status Check**: Kiểm tra trạng thái các dịch vụ đang chạy
- **Environment Check**: Kiểm tra môi trường hệ thống có tương thích không
- **Nginx Setup**: Thiết lập reverse proxy cho Supabase
- **Google Drive Sync**: Đồng bộ backup với Google Drive

## 📚 Tài liệu chi tiết

- [Hướng dẫn sử dụng chi tiết cho người mới bắt đầu](HUONG_DAN_SU_DUNG.md)
- [Hướng dẫn sử dụng cho Windows](README-WINDOWS.md)
- [Hướng dẫn sử dụng cho macOS](README-MACOS.md)
- [Hướng dẫn tính năng nâng cao](enhanced-features-guide.sh)

## 🔄 Sao lưu giữa các hệ điều hành

Hướng dẫn chi tiết về cách thực hiện backup từ Linux sang Windows và ngược lại, cũng như cách chuyển đổi giữa các hệ điều hành khác nhau, đã được cung cấp trong [file hướng dẫn chi tiết](HUONG_DAN_SU_DUNG.md).

## 🛠️ Gỡ rối

Nếu gặp lỗi trong quá trình sử dụng:

- Đảm bảo Docker và Docker Compose đã được cài đặt đúng cách
- Kiểm tra quyền truy cập thư mục
- Với Windows, đảm bảo chạy PowerShell với quyền Administrator
- Nếu sử dụng macOS, cần cài Docker Desktop cho Mac

## 🤝 Đóng góp

Nếu bạn thấy Supabase Kit hữu ích, hãy đánh dấu ⭐ cho dự án!