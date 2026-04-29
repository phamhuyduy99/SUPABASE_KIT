====================================================================
       BỘ KIT SUPABASE SELF-HOSTED – HƯỚNG DẪN SỬ DỤNG
====================================================================

Chào bạn! Bộ kit này giúp bạn quản lý hệ thống Supabase một cách dễ dàng,
không cần kiến thức kỹ thuật chuyên sâu.

I. YÊU CẦU
- Máy chủ Ubuntu 20.04, 22.04 hoặc 24.04 (64-bit), RAM tối thiểu 2GB.
- Có kết nối Internet.
- Bạn cần có quyền sudo để thực hiện một số tác vụ cài đặt.
  Nếu chưa có, hãy liên hệ quản trị viên để được cấp quyền bằng lệnh:
      sudo usermod -aG sudo <tên-người-dùng-của-bạn>
  Sau đó đăng xuất và đăng nhập lại.

  Mẹo: Để biết tên người dùng của bạn, gõ lệnh: whoami

II. CÀI ĐẶT & CHẠY LẦN ĐẦU (CHỈ MỘT LỆNH)
1. Upload file ZIP lên VPS, giải nén vào thư mục dự án Supabase (nơi có file .env).
   Ví dụ:
     unzip SUPABASE_KIT.zip -d supabase-kit
     cd supabase-kit

2. Chạy lệnh duy nhất:
     bash supa-start.sh

   Bộ kit sẽ TỰ ĐỘNG quét hệ thống và hiển thị những chức năng đã sẵn sàng,
   những gì cần cài thêm. Sau đó bạn có thể vào menu chính.

   Nếu gặp lỗi "Permission denied", hãy chạy:
     chmod +x supa-*.sh common.sh
     sudo bash supa-start.sh

III. CÁC CHỨC NĂNG TRONG MENU
- [1] Đóng băng hệ thống (Backup): Tạo file sao lưu toàn bộ dữ liệu và
      cấu hình Supabase. Có thể tự động đồng bộ sang VPS dự phòng hoặc
      upload lên Google Drive (nếu đã cấu hình rclone).
- [2] Khôi phục hệ thống (Restore): Dựng lại toàn bộ Supabase (cấu hình,
      database, storage, edge functions) từ file backup lên bất kỳ VPS nào,
      kể cả VPS trắng chưa cài đặt gì. Bạn chỉ cần chỉ định thư mục cài đặt,
      script sẽ tự lo phần còn lại (cài Docker, khởi động, import dữ liệu).
- [3] Cài HTTPS & domain: Cài Nginx và chứng chỉ SSL miễn phí cho
      tên miền của bạn. Script sẽ kiểm tra xung đột cổng, domain
      và hướng dẫn xử lý.
- [4] Kiểm tra trạng thái: Xem các container Supabase có đang chạy không.
- [5] Thiết lập tự động backup: Hẹn giờ backup hàng ngày lúc 2h sáng.
- [6] Cấu hình Google Drive: Thiết lập kết nối để upload backup lên Google Drive.
- [0] Thoát.

   Lưu ý: Khi khởi động, màn hình sẽ hiển thị rõ chức năng nào đã sẵn sàng,
   chức năng nào cần cài thêm (và cần sudo hay không).

IV. CÁC TÌNH HUỐNG THƯỜNG GẶP
1. "Không tìm thấy file .env":
   Bạn cần nhập đường dẫn đến thư mục chứa Supabase.
2. "Không có quyền sudo":
   Script sẽ hướng dẫn bạn lệnh cần chạy (có tên người dùng của bạn).
3. Lỗi "$'\r': command not found" hoặc "Permission denied":
   Chạy: sed -i 's/\r$//' supa-*.sh common.sh && chmod +x supa-*.sh common.sh
4. "Cổng 80/443 đã bị chiếm":
   Script sẽ hỏi bạn có muốn dừng dịch vụ cũ không.
5. "Could not get lock /var/lib/apt/lists/lock":
   Hệ thống đang bận, script sẽ tự động chờ tối đa 5 phút.
6. Token Google Drive hết hạn:
   Script sẽ đề xuất chạy 'rclone config reconnect gdrive:' để làm mới.

V. CẤU HÌNH GOOGLE DRIVE (TÙY CHỌN)
   ... (giữ nguyên)

VI. THÔNG TIN LIÊN HỆ HỖ TRỢ
   Nếu gặp khó khăn, hãy liên hệ người đã cung cấp bộ kit này.

====================================================================