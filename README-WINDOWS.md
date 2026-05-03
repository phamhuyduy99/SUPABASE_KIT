# Supabase Kit - Hướng Dẫn Sử Dụng Trên Windows

## 📋 Tổng Quan

Supabase Kit là bộ công cụ hỗ trợ quản trị hệ thống Supabase tự hosted, bao gồm các tính năng: backup, restore, kiểm tra trạng thái, cấu hình HTTPS, và nhiều tiện ích khác. Bộ kit hỗ trợ cả Linux và Windows.

Phiên bản Windows sử dụng PowerShell để thực hiện các tác vụ tương tự như phiên bản Linux.

## 🚀 Yêu Cầu Hệ Thống

- **Hệ điều hành**: Windows 10 hoặc 11 (64-bit)
- **RAM**: Tối thiểu 4GB (khuyên dùng 8GB trở lên)
- **Dung lượng đĩa trống**: Tối thiểu 10GB
- **Docker Desktop**: Phiên bản mới nhất với WSL 2 backend (đối với Windows 10)
- **PowerShell 5.1+**

## 🔧 Cài Đặt

1. **Cài đặt Docker Desktop**:
   - Tải tại: [https://www.docker.com/products/docker-desktop](https://www.docker.com/products/docker-desktop)
   - Cài đặt và khởi động Docker Desktop
   - Đảm bảo Docker đang chạy trước khi sử dụng Supabase Kit

2. **(Tùy chọn) Cài đặt 7-Zip** (để hỗ trợ đầy đủ tính năng nén/giải nén):
   - Tải tại: [https://www.7-zip.org/](https://www.7-zip.org/)
   - Cài đặt để hỗ trợ nén/giải nén file backup

3. **Giải nén Supabase Kit**:
   - Giải nén thư mục `supabase-kit` vào nơi bạn muốn lưu trữ

## 🖥️ Cách Sử Dụng

### Khởi động chương trình

1. Mở **PowerShell với quyền Administrator**
2. Di chuyển đến thư mục `supabase-kit\windows`
3. Chạy lệnh:
   ```powershell
   .\Start-SupabaseKit.ps1
   ```

> **Lưu ý**: Nếu gặp lỗi thực thi script, bạn có thể cần thay đổi chính sách thực thi script:
> ```powershell
> Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
> ```

### Các tính năng chính

#### 1. 🧊 Đóng băng hệ thống (Backup) - `Invoke-Freeze.ps1`
- Sao lưu toàn bộ hệ thống Supabase (cấu hình, database, storage)
- Tạo file backup `.tar.gz` để lưu trữ hoặc chuyển sang máy khác
- Hỗ trợ tạo checksum SHA256 để kiểm tra tính toàn vẹn
- Hỗ trợ đồng bộ sang VPS dự phòng qua SSH
- Hỗ trợ upload lên Google Drive (nếu đã cấu hình rclone)
- Hỗ trợ thiết lập lịch backup tự động hàng ngày

#### 2. ♻️ Khôi phục hệ thống (Restore) - `Invoke-Restore.ps1`
- Khôi phục hệ thống Supabase từ file backup
- Tự động xử lý cấu hình, database và storage
- **25 chiến lược xử lý lỗi sysctl** cho VPS dùng công nghệ ảo hóa LXC/OpenVZ
- **10 phương pháp import database** khác nhau để đảm bảo thành công
- Kiểm tra và thông báo lỗi nếu có

#### 3. 📊 Kiểm tra trạng thái - `Invoke-Status.ps1`
- Hiển thị trạng thái các container đang chạy
- Kiểm tra tài nguyên hệ thống (RAM, disk)
- Báo cáo các dịch vụ Supabase

#### 4. 🔍 Kiểm tra tương thích VPS - `Invoke-CheckEnv.ps1`
- Kiểm tra hệ thống có đáp ứng yêu cầu chạy Supabase không
- Kiểm tra Docker, RAM, disk, kết nối mạng
- Phát hiện công nghệ ảo hóa (KVM, LXC, OpenVZ...)

#### 5. ☁️ Cấu hình Google Drive - `Invoke-SetupGDrive.ps1`
- Hướng dẫn cài đặt rclone nếu chưa có
- Hỗ trợ cấu hình Google Drive để backup/upload
- Tự động tạo cấu hình và lưu trữ token

## ⚙️ Các Script PowerShell

Tất cả các script trong thư mục `windows/` đều có thể chạy độc lập:

- `Start-SupabaseKit.ps1`: Giao diện menu chính
- `Invoke-Freeze.ps1`: Chức năng backup
- `Invoke-Restore.ps1`: Chức năng restore
- `Invoke-Status.ps1`: Kiểm tra trạng thái
- `Invoke-CheckEnv.ps1`: Kiểm tra môi trường
- `Invoke-SetupGDrive.ps1`: Cấu hình Google Drive
- `SupabaseKit.psm1`: Module chứa các hàm dùng chung

## 🔧 Tính năng nâng cao

### 25 chiến lược xử lý lỗi sysctl
Khi làm việc với VPS dùng công nghệ ảo hóa LXC/OpenVZ, bạn có thể gặp lỗi liên quan đến sysctl. Supabase Kit có 25 chiến lược xử lý khác nhau:

1. Xóa dòng sysctl khỏi docker-compose.yml
2. Thêm privileged: true cho các container
3. Thêm security_opt và cap_add
4. Cấu hình Docker daemon
5. Hạ cấp containerd
6. Đổi tag image sang phiên bản cũ hơn
7. Hướng dẫn thử runtime khác
8. Vô hiệu hóa AppArmor/SELinux (nếu áp dụng)
9. Yêu cầu nhà cung cấp VPS bật nesting
10. Chuyển sang VPS KVM
11. Thêm sysctls thủ công
12. Đặt biến môi trường bỏ qua sysctl
13. Khởi động riêng từng service
14. Xóa toàn bộ volumes và networks cũ
15. Sử dụng Docker Compose V1
16. Khởi động với cờ --compatibility
17. Cập nhật Docker
18. Đăng ký lại dịch vụ Docker
19. File docker-compose tối thiểu
20. Đề xuất chuyển Supabase Cloud
21. Vô hiệu hóa toàn bộ sysctl trong compose
22. Khởi động với --no-deps --no-healthcheck
23. Dùng docker run trực tiếp
24. Yêu cầu nhà cung cấp sửa AppArmor
25. Docker trong Docker hoặc máy ảo

### 10 phương pháp import database
Supabase Kit hỗ trợ 10 phương pháp khác nhau để import database:

1. Import trực tiếp từ SQL dump
2. Import từng phần nếu file quá lớn
3. Sử dụng pg_restore nếu có sẵn
4. Import từng schema riêng biệt
5. Import với các tùy chọn tối ưu khác nhau
6. Hướng dẫn thủ công nếu tự động thất bại
7. Phân tích lỗi và đề xuất phương pháp thay thế
8. Sử dụng công cụ chuyên dụng nếu cần
9. Kiểm tra tính toàn vẹn sau khi import
10. Ghi log chi tiết quá trình import

## 🛠️ Troubleshooting

### Lỗi thường gặp:

1. **"File cannot be loaded because running scripts is disabled"**:
   - Giải pháp: Chạy lệnh `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`

2. **"Docker command not found"**:
   - Đảm bảo Docker Desktop đã được cài đặt và đang chạy

3. **"Insufficient permissions"**:
   - Chạy PowerShell với quyền Administrator

4. **"Out of disk space"**:
   - Giải phóng dung lượng đĩa trước khi thực hiện backup/restore

5. **"Lỗi sysctl trên VPS LXC/OpenVZ"**:
   - Supabase Kit sẽ tự động thử 25 chiến lược xử lý lỗi như đã mô tả ở trên

## 📁 Cấu Trúc Thư Mục

```
supabase-kit/
├── windows/
│   ├── SupabaseKit.psm1        # Module chứa các hàm dùng chung
│   ├── Start-SupabaseKit.ps1   # Menu chính
│   ├── Invoke-Freeze.ps1       # Backup hệ thống
│   ├── Invoke-Restore.ps1      # Khôi phục hệ thống
│   ├── Invoke-Status.ps1       # Kiểm tra trạng thái
│   ├── Invoke-CheckEnv.ps1     # Kiểm tra môi trường
│   └── Invoke-SetupGDrive.ps1  # Cấu hình Google Drive
├── linux/                      # Các script cho Linux
├── README.md                   # Tài liệu tổng quan
├── README-WINDOWS.md           # Tài liệu này
└── ...
```

## 🆘 Hỗ Trợ

Nếu gặp sự cố khi sử dụng, vui lòng:

1. Chạy `Invoke-CheckEnv.ps1` để kiểm tra môi trường
2. Kiểm tra Docker Desktop đang chạy
3. Đảm bảo có đủ tài nguyên hệ thống
4. Liên hệ hỗ trợ nếu vẫn gặp sự cố

# SUPABASE KIT CHO WINDOWS

## Giới thiệu

SUPABASE KIT CHO WINDOWS là bộ công cụ hỗ trợ quản lý hệ thống Supabase tự lưu trữ (self-hosted) trên nền tảng Windows. Bộ công cụ cung cấp các chức năng thiết yếu như:

- Đóng băng hệ thống (Backup): Sao lưu toàn bộ dữ liệu và cấu hình Supabase
- Khôi phục hệ thống (Restore): Phục hồi hệ thống từ file backup
- Kiểm tra trạng thái: Kiểm tra tình trạng các container
- Kiểm tra tương thích VPS: Kiểm tra hệ thống có đủ điều kiện để chạy Supabase
- Cài HTTPS & Domain: Cấu hình SSL và domain cho Supabase
- Thiết lập tự động backup: Lên lịch backup tự động hàng ngày
- Cấu hình Google Drive: Tích hợp lưu trữ backup lên Google Drive

## Yêu cầu hệ thống

- Windows 10/11 64-bit
- Docker Desktop đã cài đặt và chạy được
- WSL 2 backend được kích hoạt trong Docker Desktop
- Ít nhất 4GB RAM trống
- Quyền Administrator để chạy script

## Cài đặt

1. Giải nén thư mục `SUPABASE_KIT` vào vị trí mong muốn
2. Mở PowerShell với quyền Administrator
3. Di chuyển đến thư mục `SUPABASE_KIT\windows`
4. Chạy lệnh để cấp quyền thực thi cho script:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

## Hướng dẫn sử dụng

### Chạy chương trình

1. Mở PowerShell với quyền Administrator
2. Di chuyển đến thư mục `SUPABASE_KIT\windows`
3. Chạy lệnh:

```powershell
powershell -ExecutionPolicy Bypass -File "Start-SupabaseKit.ps1"
```

### Các chức năng chính

Chương trình cung cấp giao diện menu dễ sử dụng với các chức năng:

- **1. Đóng băng hệ thống (Backup)**: Tạo bản sao lưu toàn bộ hệ thống
- **2. Khôi phục hệ thống (Restore)**: Phục hồi hệ thống từ bản sao lưu
- **3. Kiểm tra trạng thái**: Hiển thị tình trạng các container đang chạy
- **4. Kiểm tra tương thích VPS**: Kiểm tra hệ thống có đủ điều kiện chạy Supabase
- **5. Cài HTTPS & domain**: Cấu hình SSL và domain cho Supabase
- **6. Thiết lập tự động backup**: Lên lịch backup tự động
- **7. Cấu hình Google Drive**: Thiết lập lưu trữ backup lên Google Drive

## Hướng dẫn giải nén file backup từ Linux trên Windows

Nếu bạn có file backup `.tar.gz` được tạo từ hệ thống Linux và muốn khôi phục trên Windows, hãy làm theo các bước sau:

### Bước 1: Cài đặt các công cụ cần thiết

1. **Cài đặt 7-Zip** (để hỗ trợ giải nén file `.tar.gz`):
   - Tải từ: https://www.7-zip.org/
   - Cài đặt với quyền Administrator

2. **Đảm bảo Docker Desktop đang chạy**:
   - Khởi động Docker Desktop
   - Kiểm tra Docker có hoạt động bằng lệnh: `docker --version`

### Bước 2: Sử dụng script giải nén tự động

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

### Bước 3: Thủ công (nếu không dùng script)

Nếu bạn muốn giải nén thủ công:

1. **Giải nén file `.tar.gz`**:
   - Click chuột phải vào file backup
   - Chọn "7-Zip" → "Extract Here" hoặc "Extract to..."
   
2. **Di chuyển vào thư mục đã giải nén**:
   - Thư mục có tên dạng `supabase-backup-yyyymmdd_hhmmss`
   
3. **Chạy chương trình**:
   ```powershell
   cd supabase-backup-yyyymmdd_hhmmss
   powershell -ExecutionPolicy Bypass -File "Start-SupabaseKit.ps1"
   ```

### Bước 4: Khôi phục hệ thống

Sau khi giải nén thành công, bạn có thể sử dụng chức năng "Khôi phục hệ thống (Restore)" trong menu chính để khôi phục dữ liệu từ bản backup.

## Lưu ý quan trọng

- Luôn chạy PowerShell với quyền Administrator để đảm bảo các chức năng hoạt động đúng
- File backup có thể có dung lượng lớn, đảm bảo đủ không gian đĩa cứng
- Nếu sử dụng backup từ hệ thống Linux, cần chú ý đến sự khác biệt về đường dẫn và quyền truy cập
- Giữ bản sao lưu các file cấu hình quan trọng như `.env` ở nơi an toàn

## Troubleshooting

Nếu gặp lỗi khi chạy script:

1. **Lỗi thực thi script**: Đảm bảo đã chạy lệnh `Set-ExecutionPolicy`
2. **Lỗi Docker**: Kiểm tra Docker Desktop đang chạy và có quyền truy cập
3. **Lỗi quyền truy cập**: Chạy lại PowerShell với quyền Administrator

## Liên hệ hỗ trợ

Nếu gặp vấn đề trong quá trình sử dụng, vui lòng liên hệ với đội ngũ hỗ trợ kỹ thuật.
