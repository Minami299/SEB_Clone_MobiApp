# Phạm vi đề xuất: Trưởng bộ môn (Head of Subject)

> Đây là đề xuất diễn giải bảng công việc thành ranh giới trách nhiệm theo vai trò. Bảng hiện tại chưa điền Assignee và chưa nêu quyền cụ thể của từng vai trò, vì vậy nhóm cần xác nhận với người phụ trách nghiệp vụ trước khi coi đây là phân công chính thức.

## Hiểu nhanh điểm đang bị lẫn

Tên **Phân hệ** trong bảng cho biết nhóm chức năng của sản phẩm; nó không tự động có nghĩa mọi công việc trong phân hệ đó thuộc vai trò Head of Subject. Ví dụ, `ADM-01 Quản lý khoa/bộ môn` là nghiệp vụ quản trị hệ thống. Trưởng bộ môn có thể xem thông tin khoa của mình, nhưng không nên tự tạo, sửa hoặc xóa khoa nếu không được giao quyền quản trị.

Tương tự, một công việc có thể có nhiều vai trò tham gia ở các bước khác nhau. Với `EDU-03`, giảng viên gửi yêu cầu, còn Trưởng bộ môn xét duyệt. Đây là hai thao tác khác nhau trên cùng một luồng Maker-Checker.

## Ranh giới vai trò đề xuất

| Vai trò | Trách nhiệm chính |
| --- | --- |
| Admin | Quản trị dữ liệu và cấu hình toàn hệ thống; quản lý khoa, tài khoản, trạng thái, import/export, nhật ký. |
| Head of Subject | Quản lý chuyên môn trong khoa/môn được giao; xem thông tin môn và nhân sự liên quan; xét duyệt yêu cầu quyền; theo dõi câu hỏi, kỳ thi và báo cáo thuộc phạm vi phụ trách. |
| Lecturer | Soạn câu hỏi, đề thi và học phần được cấp quyền; quản lý lớp được phân công; gửi yêu cầu quyền môn học; chấm bài. |
| Student | Làm bài thi, xem kết quả trong phạm vi được phép. |

## Ánh xạ các Task ID

| Task ID | Phạm vi Head of Subject đề xuất | Vai trò thực hiện chính / lưu ý |
| --- | --- | --- |
| ADM-01 | Chỉ xem khoa mình, nhân sự và môn trực thuộc; không CRUD khoa. | Admin CRUD; Head of Subject xem theo khoa được gán. |
| ADM-02–ADM-06 | Không thuộc phạm vi mặc định. | Admin. |
| EDU-01 | Xem và quản lý chuyên môn môn thuộc khoa; CRUD môn chỉ giao nếu quy trình trường cho phép. | Admin tạo danh mục nền; Head of Subject quản lý môn được ủy quyền. Cần nhóm xác nhận ai được tạo/xóa môn. |
| EDU-02 | Quản lý chương mục môn phụ trách. | Head of Subject chịu trách nhiệm cấu trúc/chương; Lecturer có thể được cấp quyền đóng góp nội dung nếu nghiệp vụ yêu cầu. |
| EDU-03 | Duyệt hoặc từ chối yêu cầu cấp quyền cho môn thuộc phạm vi mình. | Lecturer gửi yêu cầu; Head of Subject xét duyệt; Admin xử lý ngoại lệ. |
| EDU-04–EDU-05 | Theo dõi lớp và sĩ số; không tự sửa lớp/ghi danh nếu không được giao. | Lecturer quản lý lớp được phân công; Admin hoặc đơn vị đào tạo quản lý danh mục/lớp và ghi danh. Head of Subject xem báo cáo theo bộ môn. |
| QST-01–QST-03 | Xem ngân hàng và theo dõi chất lượng/phân loại câu hỏi trong bộ môn. | Lecturer biên soạn câu hỏi; Head of Subject chỉ sửa/xóa hoặc duyệt câu hỏi nếu có quy trình duyệt nội dung rõ ràng. |
| EXM-01–EXM-04 | Theo dõi kỳ thi thuộc các môn phụ trách; có thể xem báo cáo và kiểm soát phát hành nếu quy trình yêu cầu. | Lecturer tạo đề, tổ chức kỳ thi và danh sách thí sinh; Head of Subject giám sát/duyệt theo chính sách của trường. |
| ATT-01–ATT-03 | Không thao tác thay thí sinh; chỉ giám sát khi được phân quyền. | Student thực hiện; backend đảm bảo điều kiện, lưu bài và tự thu bài. |
| PRO-01–PRO-02 | Theo dõi và xử lý vi phạm trong các kỳ thi thuộc phạm vi. | Lecturer giám sát ca thi; Head of Subject xem xét/ra quyết định nếu quy chế giao quyền. |
| GRA-01–GRA-04 | Xem thống kê tổng hợp của bộ môn; không thay giảng viên chấm tự luận mặc định. | Hệ thống chấm trắc nghiệm; Lecturer chấm tự luận; Head of Subject theo dõi báo cáo và chất lượng. |

## Phạm vi màn hình Head of Subject hiện tại

Màn hình hiện có bốn nhóm chính: danh sách môn và bật/tắt trạng thái; mở ngân hàng câu hỏi theo môn; duyệt yêu cầu cấp quyền; xem phổ điểm kỳ thi. Đây là nền tảng phù hợp với vai trò giám sát bộ môn, nhưng còn các điểm cần chốt với nhóm:

Backend hiện cho Head of Subject tạo/sửa/xóa/xuất bản kỳ thi và gán câu hỏi/thí sinh cho các kỳ thi trong khoa được gán. Quyền đã bị giới hạn theo khoa ở backend, nhưng vẫn rộng hơn vai trò “chỉ giám sát” trong đề xuất trên. Tài liệu này không tự ý gỡ quyền đó; cần xác nhận quyền tổ chức thi thuộc Lecturer hay Head of Subject trước khi thu hẹp API.

1. Head of Subject có được tạo/sửa/xóa môn (EDU-01) hay chỉ thay đổi trạng thái?
2. Head of Subject có được CRUD chương mục (EDU-02)?
3. Head of Subject có quyền chỉnh sửa câu hỏi, hay chỉ xem/duyệt?
4. Head of Subject có quyền tạo, sửa, xuất bản hoặc xóa kỳ thi, hay chỉ xem báo cáo?
5. `department_id` của tài khoản có phải nguồn chính thức để xác định các môn được phụ trách? Nếu một người phụ trách nhiều khoa hoặc chỉ một số môn trong một khoa thì cần lưu phân công riêng thay vì suy ra toàn khoa.

## Quy tắc phân quyền kỹ thuật đề xuất

- Mọi truy vấn và thao tác của Head of Subject phải được giới hạn theo phạm vi được gán ở backend; ẩn nút trên giao diện không thay thế được kiểm tra quyền.
- Admin được truy cập toàn hệ thống.
- Nếu vai trò chỉ được xem thì API dùng GET; chỉ mở POST/PUT/PATCH/DELETE khi nghiệp vụ xác nhận quyền sửa.
- Ghi nhận người duyệt và thời điểm duyệt cho luồng Maker-Checker; chỉ yêu cầu `PENDING` mới được xét duyệt.
- Nên xác định rõ phạm vi theo `department_id` hay bảng phân công Head-of-Subject-to-subject. Mô hình hiện tại có `users.department_id` và `subjects.department_id`, nên backend đang suy ra phạm vi môn từ khoa.
