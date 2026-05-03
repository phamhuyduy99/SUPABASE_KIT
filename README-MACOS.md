# Supabase Kit - Hướng Dẫn Sử Dụng Trên macOS

## 📋 Tổng Quan

Supabase Kit là bộ công cụ hỗ trợ quản trị hệ thống Supabase tự hosted, bao gồm các tính năng: backup, restore, kiểm tra trạng thái, cấu hình HTTPS, và nhiều tiện ích khác. Bộ kit hỗ trợ cả Linux, Windows và macOS.

Phiên bản macOS sử dụng các script bash tương tự như phiên bản Linux, vì macOS dựa trên Unix.

## 🚀 Yêu Cầu Hệ Thống

- **Hệ điều hành**: macOS 10.15 (Catalina) trở lên
- **RAM**: Tối thiểu 2GB (khuyến nghị 4GB trở lên)
- **Dung lượng đĩa trống**: Tối thiểu 5GB
- **Docker Desktop**: Phiên bản mới nhất cho macOS

## 🔧 Cài Đặt

1. **Cài đặt Docker Desktop cho macOS**:
   - Tải tại: [https://www.docker.com/products/docker-desktop](https://www.docker.com/products/docker-desktop)
   - Cài đặt và khởi động Docker Desktop
   - Đảm bảo Docker đang chạy trước khi sử dụng Supabase Kit

2. **Cài đặt các công cụ dòng lệnh**:
   ```bash
   # Cài đặt Homebrew nếu chưa có
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   
   # Cài đặt các công cụ hữu ích
   brew install coreutils
   ```

3. **Giải nén Supabase Kit**:
   - Giải nén thư mục `supabase-kit` vào nơi bạn muốn lưu trữ

## 🖥️ Cách Sử Dụng

### Khởi động chương trình

1. Mở **Terminal**
2. Di chuyển đến thư mục `supabase-kit`
3. Cấp quyền thực thi cho các script:
   ```bash
   chmod +x supa-*.sh common.sh
   ```
4. Chạy chương trình chính:
   ```bash
   ./supa-start.sh
   ```

### Các tính năng chính

Các tính năng trên macOS giống hệt với phiên bản Linux:

#### 1. 🧊 Đóng băng hệ thống (Backup) - `supa-freeze.sh`
- Sao lưu toàn bộ hệ thống Supabase (cấu hình, database, storage)
- Tạo file backup `.tar.gz` để lưu trữ hoặc chuyển sang máy khác
- Hỗ trợ tạo checksum SHA256 để kiểm tra tính toàn vẹn

#### 2. ♻️ Khôi phục hệ thống (Restore) - `supa-restore.sh`
- Khôi phục hệ thống Supabase từ file backup
- Tự động xử lý cấu hình, database và storage
- Xử lý 25 chiến lược khác nhau khi gặp lỗi sysctl
- Hỗ trợ import database với 10 phương pháp khác nhau

#### 3. 📊 Kiểm tra trạng thái - `supa-status.sh`
- Hiển thị trạng thái các container đang chạy
- Kiểm tra tài nguyên hệ thống (RAM, disk)
- Báo cáo các dịch vụ Supabase

#### 4. 🌐 Cài đặt HTTPS & domain - `supa-setup-nginx.sh`
- Cài đặt Nginx và cấp chứng chỉ SSL miễn phí từ Let's Encrypt
- Hỗ trợ cấu hình domain cho hệ thống Supabase

#### 5. 🔍 Kiểm tra tương thích - `supa-check-env.sh`
- Kiểm tra hệ thống có đáp ứng yêu cầu chạy Supabase không
- Kiểm tra Docker, RAM, disk, kết nối mạng

## ⚙️ Các Script Chính

Tất cả các script trong thư mục gốc đều có thể chạy độc lập:

- `supa-start.sh`: Khởi động chương trình
- `supa-menu.sh`: Giao diện menu chính
- `supa-freeze.sh`: Chức năng backup
- `supa-restore.sh`: Chức năng restore
- `supa-status.sh`: Kiểm tra trạng thái
- `supa-check-env.sh`: Kiểm tra môi trường
- `supa-setup-nginx.sh`: Cài đặt HTTPS
- `supa-setup-gdrive.sh`: Cấu hình Google Drive
- `common.sh`: Module chứa các hàm dùng chung

## 🛠️ Troubleshooting trên macOS

### Lỗi thường gặp:

1. **"Operation not permitted"**:
   - Kiểm tra quyền truy cập trong System Preferences > Security & Privacy > Privacy > Full Disk Access
   - Thêm Terminal vào danh sách được phép

2. **"Docker command not found"**:
   - Đảm bảo Docker Desktop đã được cài đặt và đang chạy
   - Khởi động lại Terminal sau khi cài Docker

3. **"Permission denied" khi chạy script**:
   - Chạy lệnh: `chmod +x supa-*.sh common.sh`

4. **"Port already in use"**:
   - Kiểm tra ứng dụng đang sử dụng cổng 80/443 (Apache, Nginx...)
   - Tắt các ứng dụng đó trước khi sử dụng Supabase

5. **Lỗi sysctl trên macOS**:
   - macOS có các hạn chế bảo mật khác với Linux
   - Một số cấu hình sysctl có thể không khả dụng
   - Theo dõi đầu ra của script để biết cách xử lý cụ thể

## 📁 Cấu Trúc Thư Mục

```
supabase-kit/
├── linux/                      # Các script gốc (cũng dùng cho macOS)
│   ├── common.sh               # Module chứa các hàm dùng chung
│   ├── supa-start.sh           # Script khởi động chính
│   ├── supa-menu.sh            # Giao diện menu
│   ├── supa-freeze.sh          # Backup hệ thống
│   ├── supa-restore.sh         # Khôi phục hệ thống
│   ├── supa-status.sh          # Kiểm tra trạng thái
│   ├── supa-check-env.sh       # Kiểm tra môi trường
│   └── ...
├── windows/                    # Các script cho Windows
├── README.md                   # Tài liệu tổng quan
├── README-MACOS.md             # Tài liệu này
└── ...
```

## ⚠️ Lưu Ý Đặc Biệt Về macOS

- Docker Desktop trên macOS hoạt động khác với Linux, nên một số tùy chọn sysctl có thể không khả dụng
- macOS có các lớp bảo mật bổ sung (SIP, TCC), có thể ảnh hưởng đến một số thao tác hệ thống
- Quyền truy cập thư mục hệ thống bị hạn chế hơn Linux
- Một số lệnh dòng lệnh mặc định có thể khác với Linux (ví dụ: `sed`, `awk`)

## 🆘 Hỗ Trợ

Nếu gặp sự cố khi sử dụng, vui lòng:

1. Chạy `supa-check-env.sh` để kiểm tra môi trường
2. Kiểm tra Docker Desktop đang chạy
3. Đảm bảo có đủ tài nguyên hệ thống
4. Kiểm tra quyền truy cập thư mục và tệp
5. Liên hệ hỗ trợ nếu vẫn gặp sự cố