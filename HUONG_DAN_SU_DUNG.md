# HƯỚNG DẪN SỬ DỤNG SUPABASE KIT

## Mục lục
1. [Giới thiệu](#giới-thiệu)
2. [Chuẩn bị](#chuẩn-bị)
3. [Cài đặt](#cài-đặt)
4. [Sử dụng các chức năng](#sử-dụng-các-chức-năng)
5. [Giải nén file backup từ Linux](#giải-nén-file-backup-từ-linux)
6. [Troubleshooting](#troubleshooting)

## Giới thiệu

SUPABASE KIT là bộ công cụ hỗ trợ quản lý hệ thống Supabase tự lưu trữ (self-hosted), giúp đơn giản hóa các tác vụ như backup, restore, cấu hình HTTPS, và giám sát trạng thái hệ thống. Bộ công cụ hỗ trợ cả Linux và Windows, đảm bảo tính linh hoạt trong triển khai.

## Chuẩn bị

Trước khi sử dụng, bạn cần đảm bảo:
- Hệ điều hành: Ubuntu 20.04+, Windows 10/11
- RAM tối thiểu: 2GB
- Docker và Docker Compose đã được cài đặt
- Quyền sudo (Linux) hoặc Administrator (Windows)

## Cài đặt

### Linux/macOS:
1. Giải nén thư mục chứa bộ kit
2. Cấp quyền thực thi cho các script:
   ```bash
   chmod +x supa-*.sh common.sh
   ```
3. Chạy script chính:
   ```bash
   bash supa-start.sh
   ```

### Windows:
1. Giải nén thư mục chứa bộ kit
2. Mở PowerShell với quyền Administrator
3. Cấp quyền thực thi cho script:
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```
4. Chạy script chính:
   ```powershell
   powershell -ExecutionPolicy Bypass -File "Start-SupabaseKit.ps1"
   ```

## Sử dụng các chức năng

Menu chính của bộ kit cung cấp các chức năng sau:

1. **Đóng băng hệ thống (Backup)**: Tạo bản sao lưu toàn bộ hệ thống
2. **Khôi phục hệ thống (Restore)**: Phục hồi hệ thống từ bản sao lưu
3. **Kiểm tra trạng thái**: Hiển thị tình trạng các container đang chạy
4. **Kiểm tra tương thích VPS**: Kiểm tra hệ thống có đủ điều kiện chạy Supabase
5. **Cài HTTPS & domain**: Cấu hình SSL và domain cho Supabase
6. **Thiết lập tự động backup**: Lên lịch backup tự động
7. **Cấu hình Google Drive**: Thiết lập lưu trữ backup lên Google Drive

## Giải nén file backup từ Linux

Nếu bạn có file backup `.tar.gz` được tạo từ hệ thống Linux và muốn sử dụng trên Windows, hãy làm theo hướng dẫn sau:

### Sử dụng script tự động

Bộ kit cung cấp script [Invoke-ExtractBackup.ps1](file:///c%3A/Users/duyph/Desktop/INTRUST/NATEC_SUPABASE/SUPABASE\SUPABASE_KIT\windows\Invoke-ExtractBackup.ps1) để tự động giải nén file backup:

1. Copy file backup `.tar.gz` vào cùng thư mục với các script của SUPABASE KIT
2. Mở PowerShell với quyền Administrator
3. Di chuyển đến thư mục chứa script
4. Chạy lệnh:

``powershell
powershell -ExecutionPolicy Bypass -File "Invoke-ExtractBackup.ps1"
```

Script sẽ:
- Tự động tìm file backup `.tar.gz` mới nhất trong thư mục
- Giải nén vào thư mục mới với tên có chứa timestamp
- Hiển thị hướng dẫn tiếp theo để chạy hệ thống

### Giải nén thủ công

Nếu bạn muốn giải nén thủ công:

1. **Cài đặt 7-Zip** (nếu chưa có):
   - Tải từ: https://www.7-zip.org/
   - Cài đặt với quyền Administrator

2. **Giải nén file `.tar.gz`**:
   - Click chuột phải vào file backup
   - Chọn "7-Zip" → "Extract Here" hoặc "Extract to..."

3. **Di chuyển vào thư mục đã giải nén**:
   - Thư mục có tên dạng `supabase-backup-yyyymmdd_hhmmss`

4. **Chạy chương trình**:
   ```powershell
   cd supabase-backup-yyyymmdd_hhmmss
   powershell -ExecutionPolicy Bypass -File "Start-SupabaseKit.ps1"
   ```

### Lưu ý khi sử dụng backup từ Linux trên Windows

- Đường dẫn file: Linux sử dụng [/](file://c:\Users\duyph\Desktop\INTRUST\NATEC_SUPABASE\SUPABASE\SUPABASE_KIT\HUONG_DAN_SU_DUNG.md), Windows sử dụng [\](file://c:\Users\duyph\Desktop\INTRUST\NATEC_SUPABASE\SUPABASE\SUPABASE_KIT\HUONG_DAN_SU_DUNG.md), có thể cần điều chỉnh trong file cấu hình
- Docker volumes: Có thể cần điều chỉnh quyền truy cập cho các volume được backup từ Linux
- Nếu file backup có file `.sha256` đi kèm, nên kiểm tra tính toàn vẹn trước khi khôi phục

## Troubleshooting

### Các lỗi thường gặp

1. **Lỗi thực thi script trên Windows**:
   - Lỗi: "File cannot be loaded because running scripts is disabled..."
   - Giải pháp: Chạy lệnh `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`

2. **Lỗi Docker không khả dụng**:
   - Đảm bảo Docker Desktop đang chạy
   - Với Linux, kiểm tra quyền truy cập vào Docker bằng lệnh: `sudo usermod -aG docker $USER`

3. **Lỗi không tìm thấy thư mục dự án**:
   - Đảm bảo thư mục chứa file `.env` và `docker-compose.yml`
   - Nếu dùng backup từ Linux, cần giải nén đúng cấu trúc thư mục

4. **Lỗi liên quan đến sysctl trên container**:
   - Một số hệ thống ảo hóa (OpenVZ/LXC) không hỗ trợ các tùy chọn sysctl
   - Script sẽ tự động áp dụng các chiến lược khắc phục tương thích

### Khi gặp lỗi

1. Kiểm tra log đầu ra để xác định nguyên nhân
2. Đảm bảo hệ thống đáp ứng yêu cầu tối thiểu
3. Nếu lỗi liên quan đến quyền truy cập, thử chạy với quyền Administrator (Windows) hoặc sudo (Linux)
4. Thử lại sau khi áp dụng giải pháp phù hợp

## Liên hệ hỗ trợ

Nếu gặp khó khăn trong quá trình sử dụng, vui lòng liên hệ với đội ngũ hỗ trợ kỹ thuật.
