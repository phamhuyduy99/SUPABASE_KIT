# Plan: Tổ chức cấu trúc thư mục trong gói backup

## Mục tiêu
Cải tiến cấu trúc của gói backup được tạo bởi `supa-freeze.sh` để tổ chức tốt hơn các script cho cả nền tảng Linux và Windows.

## Những file sẽ thay đổi
1. `supa-freeze.sh` - Sửa phần copy script vào gói backup
2. `linux/supa-freeze.sh` - Cập nhật bản sao trong thư mục linux
3. Script tạo ra trong quá trình chạy `supa-freeze.sh` - Cập nhật hướng dẫn sử dụng

## Mô tả thay đổi cụ thể

### 1. Cập nhật phần copy script trong supa-freeze.sh
- Tạo thư mục `linux/` trong gói backup
- Copy toàn bộ script `.sh` vào thư mục `linux/` thay vì đặt ở gốc
- Kiểm tra và copy thư mục `windows/` nếu tồn tại
- Tạo script `restore-windows.ps1` độc lập và đặt ở cả thư mục gốc và `windows/`

### 2. Cập nhật script giải nén được tạo ra
- Sửa hướng dẫn trong script giải nén để phản ánh đúng cấu trúc thư mục mới
- Hướng dẫn người dùng vào thư mục `linux/` để chạy `supa-start.sh`

### 3. Cập nhật cả hai phiên bản của script
- Cập nhật cả bản gốc và bản trong thư mục `linux/` để đảm bảo tính nhất quán

## Lý do thay đổi
- Tăng tính tổ chức cho gói backup, phân biệt rõ ràng giữa script cho Linux và Windows
- Giúp người dùng dễ dàng tìm thấy đúng loại script cho hệ điều hành của họ
- Giảm sự nhầm lẫn khi giải nén và sử dụng gói backup
- Đảm bảo tính nhất quán giữa các nền tảng trong việc tổ chức mã nguồn