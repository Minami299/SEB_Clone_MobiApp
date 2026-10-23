lib/
├── core/ # Thành phần dùng chung toàn app
│ ├── config/ # Env, System Config, Routes (GoRouter)
│ ├── network/ # Dio client, WebSocket (cho Real-time logs)
│ ├── services/ # Native Channel / Kiosk Mode (SEB Lock)
│ ├── theme/ # App Theme, Colors, Typography
│ ├── utils/ # Constants, Extensions, Validators
│ └── widgets/ # Common UI (Buttons, Dialogs, Loading...)
│
├── features/ # Chia theo từng Feature để phân công công việc
│ ├── auth/ # Đăng nhập, phiên đăng nhập
│ ├── admin_system/ # Quản lý User, Role, System Config & Logs
│ ├── academic_structure/ # Quản lý Khoa, Lớp, Môn học, Chương
│ ├── subject_access/ # Luồng xin quyền & duyệt quyền môn học
│ ├── question_bank/ # Ngân hàng câu hỏi Public & theo môn
│ ├── exam_management/ # Tạo đề thi, cấu hình ca thi, danh sách thí sinh
│ ├── exam_execution/ # Giao diện làm bài thi của Student + Bắt lỗi vi phạm
│ └── monitoring_reports/ # Real-time violation logs (Lecturer) & Báo cáo (HoS)
│
└── main.dart

Cấu trúc bên trong mỗi Feature (Chuẩn Clean Architecture)
Mỗi thư mục con trong features/ nên thống nhất cấu trúc 3 tầng để các thành viên làm việc không bị xung đột code (conflict):

Plaintext
features/exam_execution/
├── data/
│ ├── datasources/ # Gọi API / WebSocket / Local DB
│ ├── models/ # JSON Serialization (Freezed / JsonSerializable)
│ └── repositories/ # Thực thi (Implement) các repository từ tầng domain
├── domain/
│ ├── entities/ # Các đối tượng nghiệp vụ thuần túy
│ ├── repositories/ # Abstract class (Interface) định nghĩa hành vi
│ └── usecases/ # Logic nghiệp vụ (VD: SubmitExamUseCase)
└── presentation/
├── bloc/ (hoặc providers/notifiers)# Quản lý State (Bloc / Riverpod)
├── pages/ # Các màn hình chính (Screens)
└── widgets/ # Các thành phần UI riêng của feature này
