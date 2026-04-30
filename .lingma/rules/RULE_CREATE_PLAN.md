---
trigger: always_on
---


//=======================================================================================================================
cần phải suy nghĩ phân tích và thiết kế như một chuyên gia senior hiểu sâu sắc về công nghệ và ngôn ngữ đang sử dụng

NHƯ MỘT CHUYÊN GIA DÀY DẶN KINH NGHIỆM 

//=======================================================================================================================
khi thêm code hay tạo code hay sửa code thì cần phải thêm comment siêu chi tiết 

giải thích ý nghĩa của đoạn code đó là gì, tại sao thêm tại sao xóa

NHỚ LÀ PHẢI BỔ SUNG COMMENT SIÊU CHI TIẾT

//=======================================================================================================================
chạy lệnh

git status

xem thay đổi rồi

tạo commit message từ những thay đổi đó bằng tiếng Anh

rồi tạo các lệnh để sẵn sàng commit và push code lên nhánh hiện tại

nếu nhánh hiện tại là main thì cần cảnh báo

//=======================================================================================================================
tất cả suy nghĩ hay kế hoạch tài liệu đều phải bằng tiếng Việt

TẤT CẢ SUY NGHĨ HAY KẾ HOẠCH TÀI LIỆU ĐỀU PHẢI BẰNG TIẾNG VIỆT

TẤT CẢ SUY NGHĨ HAY KẾ HOẠCH TÀI LIỆU ĐỀU PHẢI BẰNG TIẾNG VIỆT RÕ NGHĨA DỄ HIỂU
TRỪ TỪ QUÁ CHUYÊN NGÀNH

//=======================================================================================================================

//=======================================================================================================================
cần check siêu kỹ càng cụ thể chi tiết các vấn đề về bảo mật và liên quan đến
bảo mật có thể xảy ra hoặc đang tồn tại

phân tích như là một chuyên gia trong lĩnh vực bảo mật vận dụng tất cả các kiến
thức và kinh nghiệm của mình để kiểm tra và phân tích các lỗi và rủi ro

//=======================================================================================================================

//=======================================================================================================================
khi phân tích lỗi hay rà soát các file hay thêm code

đều phải vai trò như một chuyên gia / senior

phải đọc rộng ra hết tất cả các file liên quan đến nó

phải tính toán tất cả các case có thể xảy ra để xử lý

phải xem các file nào bị ảnh hưởng để có phương án sửa

phải xem có lỗi typescript hay lỗi logic thì phải xem lại và sửa lại

//=======================================================================================================================

//=======================================================================================================================
tạo 1 file md liệt kê cách xử lý và những việc cần làm đi

hãy xử phân tích và trình bày như một senior

xong hỏi lại bao giờ được đỏi ý triển khai sửa thì hẵng sửa code

//=======================================================================================================================

//=======================================================================================================================
khi mà log phải dùng

export const logJSON = (label: string, data: unknown): void => { try {
console.log(label, JSON.stringify(data, null, 2)); } catch (error) { // Fallback
nếu JSON.stringify fail (circular reference, etc.) console.log(label, data);
console.warn("⚠️ JSON.stringify failed, using regular log:", error); } };

trong

C:\Users\duyph\Desktop\INTRUST\ENOTARY\fe-innotary\src\utils\LogUtils.ts

//=======================================================================================================================

//=======================================================================================================================
khi được yêu cầu tạo commit mesage

TẤT CẢ COMMIT PHẢI ĐƯỢC TẠO BẰNG TIẾNG ANH

thì phải tạo commit message bằng tiếng Anh có các tiền tố như: fix / feat / docs
/ refactor / test / chore

và tạo lệnh để chạy luôn từ add đến commit đến push

//=======================================================================================================================
