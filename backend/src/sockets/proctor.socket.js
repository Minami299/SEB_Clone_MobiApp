const { ViolationLog, ExamAttempt, Exam, User } = require('../models');

const initProctorSocket = (io) => {
  const proctorNamespace = io.of('/ws/proctoring');

  proctorNamespace.on('connection', (socket) => {
    // Giám thị/Giảng viên tham gia phòng theo dõi của ca thi
    socket.on('proctor:join_exam', ({ exam_id }) => {
      if (exam_id) {
        socket.join(`monitor_${exam_id}`);
      }
    });

    // Thí sinh kết nối vào ca thi
    socket.on('student:join_exam', ({ exam_id, student_id }) => {
      if (student_id) {
        socket.join(`student_${student_id}`);
      }
    });

    // Tiếp nhận sự kiện vi phạm an toàn từ thiết bị thí sinh
    socket.on('violation:report', async (payload) => {
      try {
        const { attempt_id, exam_id, student_id, violation_type, violation_details } = payload;

        if (!attempt_id || !exam_id) return;

        // Lưu bản ghi vào ViolationLog
        const violation = await ViolationLog.create({
          attempt_id,
          violation_type: violation_type || 'UNKNOWN_VIOLATION',
          violation_details: violation_details || '',
          detected_at: new Date()
        });

        // Tăng số lỗi vi phạm trong ExamAttempt
        const attempt = await ExamAttempt.findByIdAndUpdate(
          attempt_id,
          { $inc: { violation_count: 1 } },
          { new: true }
        ).populate('student_id', 'full_name user_code email');

        const exam = await Exam.findById(exam_id);
        const maxViolations = exam ? exam.max_violations : 3;

        // Bắn thông báo vi phạm thời gian thực tới phòng Giám thị
        proctorNamespace.to(`monitor_${exam_id}`).emit('violation:alert', {
          violation_id: violation._id,
          attempt_id,
          student: attempt ? attempt.student_id : null,
          violation_type,
          violation_details,
          violation_count: attempt ? attempt.violation_count : 1,
          max_violations: maxViolations,
          detected_at: violation.detected_at
        });

        // Tự động đình chỉ nếu vượt quá số lần vi phạm cho phép
        if (attempt && attempt.violation_count >= maxViolations) {
          attempt.status = 'DISQUALIFIED';
          attempt.end_reason = 'EXCEEDED_MAX_VIOLATIONS';
          attempt.submitted_at = new Date();
          await attempt.save();

          proctorNamespace.to(`student_${student_id}`).emit('exam:terminated', {
            message: 'Bài thi đã bị khóa tự động do vượt quá giới hạn vi phạm quy chế thi',
            violation_count: attempt.violation_count
          });
        }
      } catch (error) {
        console.error('Lỗi ghi nhận vi phạm:', error.message);
      }
    });

    // Giám thị gửi cảnh báo trực tiếp cho một thí sinh
    socket.on('proctor:send_warning', ({ student_id, message }) => {
      if (student_id) {
        proctorNamespace.to(`student_${student_id}`).emit('exam:warning', {
          message: message || 'Cảnh báo từ giám thị: Hãy tập trung vào bài thi'
        });
      }
    });
  });
};

module.exports = initProctorSocket;

