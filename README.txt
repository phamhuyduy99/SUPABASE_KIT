# SUPABASE KIT - BỘ CÔNG CỤ QUẢN LÝ SUPABASE TỰ HOST

## Mô tả

SUPABASE KIT là bộ công cụ hỗ trợ quản lý hệ thống Supabase tự lưu trữ (self-hosted), giúp đơn giản hóa các tác vụ như backup, restore, cấu hình HTTPS, và giám sát trạng thái hệ thống. Bộ công cụ hỗ trợ cả Linux và Windows, đảm bảo tính linh hoạt trong triển khai.

## Tính năng

- Đóng băng hệ thống (Backup): Sao lưu toàn bộ dữ liệu và cấu hình Supabase
- Khôi phục hệ thống (Restore): Phục hồi hệ thống từ file backup
- Kiểm tra trạng thái: Kiểm tra tình trạng các container
- Kiểm tra tương thích VPS: Kiểm tra hệ thống có đủ điều kiện để chạy Supabase
- Cài HTTPS & Domain: Cấu hình SSL và domain cho Supabase
- Thiết lập tự động backup: Lên lịch backup tự động hàng ngày
- Cấu hình Google Drive: Tích hợp lưu trữ backup lên Google Drive
- Tải backup từ VPS: Tự động tải file backup mới nhất từ VPS về máy local

## Yêu cầu hệ thống

- Ubuntu 20.04+, Windows 10/11 64-bit
- RAM tối thiểu: 2GB
- Docker và Docker Compose đã được cài đặt
- Quyền sudo (Linux) hoặc Administrator (Windows)

## Cài đặt và sử dụng

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

## Giải nén file backup từ Linux trên Windows

Nếu bạn có file backup `.tar.gz` được tạo từ hệ thống Linux và muốn sử dụng trên Windows, hãy làm theo hướng dẫn sau:

### Sử dụng script tự động (khuyên dùng)

Bộ kit cung cấp script [Invoke-ExtractBackup.ps1](file:///c%3A/Users/duyph/Desktop/INTRUST/NATEC_SUPABASE/SUPABASE\SUPABASE_KIT\windows\Invoke-ExtractBackup.ps1) để tự động giải nén file backup:

1. Copy file backup `.tar.gz` vào cùng thư mục với các script của SUPABASE KIT
2. Mở PowerShell với quyền Administrator
3. Di chuyển đến thư mục chứa script
4. Chạy lệnh:

```powershell
powershell -ExecutionPolicy Bypass -File "Invoke-ExtractBackup.ps1"
```

Script sẽ:
- Tự động tìm file backup `.tar.gz` mới nhất trong thư mục
- Giải nén vào thư mục mới với tên có chứa timestamp
- Hiển thị hướng dẫn tiếp theo để chạy hệ thống

### Tải backup từ VPS về máy local

Từ phiên bản mới, bộ kit hỗ trợ tính năng tải trực tiếp file backup từ VPS về máy local:

#### Trên Linux/macOS:
1. Trong menu chính, chọn tùy chọn "8. Tải backup từ VPS về máy"
2. Nhập thông tin:
   - Địa chỉ VPS (dưới dạng `user@ip`)
   - Đường dẫn thư mục chứa backup trên VPS (mặc định: `/opt/supabase/backup`)
   - Thư mục lưu trên máy local (mặc định: `~/Downloads`)
3. Script sẽ tự động tìm file backup mới nhất và tải về máy

#### Trên Windows:
1. Trong menu chính, chọn tùy chọn "Tải backup từ VPS về máy"
2. Nhập thông tin:
   - Địa chỉ VPS (dưới dạng `user@ip`)
   - Đường dẫn thư mục chứa backup trên VPS (mặc định: `/opt/supabase/backup`)
   - Thư mục lưu trên máy local (mặc định: `%USERPROFILE%\Downloads`)
3. Script sẽ tự động tìm file backup mới nhất và tải về máy

Tính năng này yêu cầu:
- Máy local đã cấu hình SSH key để kết nối đến VPS (hoặc bạn phải nhập mật khẩu khi được hỏi)
- Máy local có cài đặt `scp` trong PATH
- Quyền đọc thư mục chứa backup trên VPS

## Các lỗi thường gặp

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