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
      cấu hình Supabase. File backup tạo ra là một GÓI TỰ HÀNH: giải nén
      ra là bạn có ngay bộ kit kèm dữ liệu, sẵn sàng khôi phục trên VPS khác.
- [2] Khôi phục hệ thống (Restore): Dựng lại toàn bộ Supabase (cấu hình,
      database, storage, edge functions) từ file backup. Khi chạy từ bộ kit
      có sẵn backup_data, script sẽ hỏi bạn có muốn dùng dữ liệu đó không.
      Chọn 'y' và nhập thư mục cài đặt là xong – không cần chỉ định file.
- [3] Cài HTTPS & domain: Cài Nginx và chứng chỉ SSL miễn phí cho
      tên miền của bạn.
- [4] Kiểm tra trạng thái: Xem các container Supabase có đang chạy không.
- [5] Thiết lập tự động backup: Hẹn giờ backup hàng ngày lúc 2h sáng.
- [6] Cấu hình Google Drive: Thiết lập kết nối để upload backup lên Google Drive.
- [0] Thoát.

IV. SỬ DỤNG GÓI BACKUP TỰ HÀNH
   Khi bạn tải file backup .tar.gz (từ Google Drive, VPS khác...), hãy:
   1. Giải nén: tar xzf ten-file.tar.gz
   2. Di chuyển vào thư mục vừa tạo: cd ten-thu-muc
   3. Chạy: sudo bash supa-start.sh
   4. Vào menu, chọn [2] Khôi phục hệ thống.
   5. Khi được hỏi "Bạn có muốn dùng dữ liệu backup kèm sẵn không?", chọn 'y'.
   6. Nhập thư mục cài đặt (Enter để dùng mặc định) và domain (nếu có).
   7. Chờ quá trình hoàn tất – bạn sẽ có một hệ thống Supabase sống động!

V. SỬ DỤNG FILE BACKUP TỪ GOOGLE DRIVE ĐỂ KHÔI PHỤC
   Sau khi backup lên Google Drive, bạn có thể tải file đó về bất kỳ VPS nào
   để khôi phục. Có hai cách:
   Cách 1 (tự động): Trong menu Restore, nhập đường dẫn theo cú pháp:
      gdrive:supabase-backups/tên-file.tar.gz
   Script sẽ tự động tải file từ Google Drive về và tiến hành khôi phục.
   Cách 2 (thủ công): Vào Google Drive trên trình duyệt, tải file .tar.gz
      về máy tính, rồi upload lên VPS mới. Sau đó trong Restore nhập đường dẫn file.

VI. CÁC TÌNH HUỐNG THƯỜNG GẶP
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

VI. THÔNG TIN LIÊN HỆ HỖ TRỢ
   Nếu gặp khó khăn, hãy liên hệ người đã cung cấp bộ kit này.

====================================================================