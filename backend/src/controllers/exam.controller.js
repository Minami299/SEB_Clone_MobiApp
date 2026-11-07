const {
  Exam,
  ExamQuestion,
  ExamEligibility,
  ExamAttempt,
  Question
} = require('../models');

const createExam = async (req, res) => {
  try {
    const {
      subject_id,
      class_id,
      exam_title,
      description,
      start_time,
      end_time,
      duration_minutes,
      max_violations,
      access_pin,
      min_pass_percentage,
      shuffle_questions,
      shuffle_options,
      allow_review,
      question_ids,
      matrix_config
    } = req.body;

    if (!subject_id || !exam_title || !start_time || !end_time || !duration_minutes) {
      return res.status(400).json({
        success: false,
        message: 'Vui lòng cung cấp đầy đủ thông tin ca thi: môn học, tiêu đề, thời gian bắt đầu, kết thúc và thời lượng'
      });
    }

    const exam = await Exam.create({
      subject_id,
      class_id: class_id || null,
      created_by: req.user._id,
      exam_title,
      description: description || '',
      start_time: new Date(start_time),
      end_time: new Date(end_time),
      duration_minutes: Number(duration_minutes),
      max_violations: max_violations !== undefined ? Number(max_violations) : 3,
      access_pin: access_pin || null,
      min_pass_percentage: min_pass_percentage !== undefined ? Number(min_pass_percentage) : 50,
      shuffle_questions: !!shuffle_questions,
      shuffle_options: !!shuffle_options,
      allow_review: !!allow_review,
      question_ids: Array.isArray(question_ids) ? question_ids : [],
      matrix_config: matrix_config || {
        is_dynamic: false,
        rules: [],
        include_private: true
      },
      status: 'DRAFT'
    });

    if (Array.isArray(question_ids) && question_ids.length > 0) {
      const examQuestionDocs = question_ids.map((qId) => ({
        exam_id: exam._id,
        question_id: qId
      }));
      await ExamQuestion.insertMany(examQuestionDocs);
    }

    res.status(201).json({
      success: true,
      message: 'Khởi tạo ca thi thành công',
      data: exam
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

const assignQuestions = async (req, res) => {
  try {
    const { id } = req.params;
    const { question_ids } = req.body;

    if (!Array.isArray(question_ids) || question_ids.length === 0) {
      return res.status(400).json({
        success: false,
        message: 'Danh sách câu hỏi (question_ids) không được để trống'
      });
    }

    const exam = await Exam.findById(id);
    if (!exam) {
      return res.status(404).json({
        success: false,
        message: 'Ca thi không tồn tại'
      });
    }

    await ExamQuestion.deleteMany({ exam_id: id });

    const examQuestionDocs = question_ids.map((qId) => ({
      exam_id: id,
      question_id: qId
    }));

    await ExamQuestion.insertMany(examQuestionDocs);

    exam.question_ids = question_ids;
    await exam.save();

    res.status(200).json({
      success: true,
      message: `Đã gán ${question_ids.length} câu hỏi vào đề thi`
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

const assignStudents = async (req, res) => {
  try {
    const { id } = req.params;
    const { student_ids } = req.body;

    if (!Array.isArray(student_ids) || student_ids.length === 0) {
      return res.status(400).json({
        success: false,
        message: 'Danh sách sinh viên (student_ids) không được để trống'
      });
    }

    const exam = await Exam.findById(id);
    if (!exam) {
      return res.status(404).json({
        success: false,
        message: 'Ca thi không tồn tại'
      });
    }

    const docs = student_ids.map((sId) => ({
      exam_id: id,
      student_id: sId,
      is_banned: false
    }));

    // Bỏ qua các bản ghi trùng lặp
    for (const doc of docs) {
      await ExamEligibility.updateOne(
        { exam_id: doc.exam_id, student_id: doc.student_id },
        { $setOnInsert: doc },
        { upsert: true }
      );
    }

    res.status(200).json({
      success: true,
      message: `Đã phân bổ danh sách thí sinh vào ca thi`
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

const publishExam = async (req, res) => {
  try {
    const { id } = req.params;
    const exam = await Exam.findByIdAndUpdate(
      id,
      { status: 'PUBLISHED' },
      { new: true }
    );

    if (!exam) {
      return res.status(404).json({
        success: false,
        message: 'Ca thi không tồn tại'
      });
    }

    res.status(200).json({
      success: true,
      message: 'Ca thi đã được xuất bản (PUBLISHED)',
      data: exam
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

const getExams = async (req, res) => {
  try {
    const filter = {};
    if (req.user.role === 'LECTURER') {
      filter.created_by = req.user._id;
    } else if (req.user.role === 'STUDENT') {
      filter.status = 'PUBLISHED';
    }

    const exams = await Exam.find(filter)
      .populate('subject_id', 'subject_code subject_name')
      .populate('class_id', 'class_code semester')
      .sort({ start_time: -1 });

    res.status(200).json({
      success: true,
      data: exams
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

const getExamDetail = async (req, res) => {
  try {
    const { id } = req.params;
    const exam = await Exam.findById(id)
      .populate('subject_id', 'subject_code subject_name')
      .populate('class_id', 'class_code semester')
      .populate('created_by', 'full_name email');

    if (!exam) {
      return res.status(404).json({
        success: false,
        message: 'Ca thi không tồn tại'
      });
    }

    const examQuestions = await ExamQuestion.find({ exam_id: id })
      .populate({
        path: 'question_id',
        select: 'question_code question_type difficulty_level content default_score'
      });

    const eligibilities = await ExamEligibility.find({ exam_id: id })
      .populate('student_id', 'full_name user_code email');

    res.status(200).json({
      success: true,
      data: {
        exam,
        stats: {
          total_questions: examQuestions.length,
          total_students: eligibilities.length
        },
        questions: examQuestions.map((eq) => eq.question_id).filter(Boolean),
        students: eligibilities.map((el) => el.student_id).filter(Boolean)
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

const updateExam = async (req, res) => {
  try {
    const { id } = req.params;
    const exam = await Exam.findById(id);

    if (!exam) {
      return res.status(404).json({
        success: false,
        message: 'Ca thi không tồn tại'
      });
    }

    if (exam.status === 'ONGOING' || exam.status === 'COMPLETED') {
      return res.status(400).json({
        success: false,
        message: 'Không thể chỉnh sửa ca thi đang diễn ra hoặc đã kết thúc'
      });
    }

    const {
      exam_title,
      description,
      start_time,
      end_time,
      duration_minutes,
      max_violations,
      access_pin,
      min_pass_percentage,
      shuffle_questions,
      shuffle_options,
      allow_review,
      question_ids,
      matrix_config,
      status
    } = req.body;

    if (exam_title) exam.exam_title = exam_title;
    if (description !== undefined) exam.description = description;
    if (start_time) exam.start_time = new Date(start_time);
    if (end_time) exam.end_time = new Date(end_time);
    if (duration_minutes) exam.duration_minutes = Number(duration_minutes);
    if (max_violations !== undefined) exam.max_violations = Number(max_violations);
    if (access_pin !== undefined) exam.access_pin = access_pin;
    if (min_pass_percentage !== undefined) exam.min_pass_percentage = Number(min_pass_percentage);
    if (shuffle_questions !== undefined) exam.shuffle_questions = !!shuffle_questions;
    if (shuffle_options !== undefined) exam.shuffle_options = !!shuffle_options;
    if (allow_review !== undefined) exam.allow_review = !!allow_review;
    if (matrix_config !== undefined) exam.matrix_config = matrix_config;
    if (Array.isArray(question_ids)) {
      exam.question_ids = question_ids;
      await ExamQuestion.deleteMany({ exam_id: id });
      const examQuestionDocs = question_ids.map((qId) => ({
        exam_id: id,
        question_id: qId
      }));
      await ExamQuestion.insertMany(examQuestionDocs);
    }
    if (status) exam.status = status;

    await exam.save();

    res.status(200).json({
      success: true,
      message: 'Cập nhật ca thi thành công',
      data: exam
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

const deleteExam = async (req, res) => {
  try {
    const { id } = req.params;
    const exam = await Exam.findById(id);

    if (!exam) {
      return res.status(404).json({
        success: false,
        message: 'Ca thi không tồn tại'
      });
    }

    if (exam.status === 'ONGOING') {
      return res.status(400).json({
        success: false,
        message: 'Không thể xóa ca thi đang diễn ra'
      });
    }

    await ExamQuestion.deleteMany({ exam_id: id });
    await ExamEligibility.deleteMany({ exam_id: id });
    await Exam.findByIdAndDelete(id);

    res.status(200).json({
      success: true,
      message: 'Đã hủy và xóa ca thi thành công'
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

const getExamStatistics = async (req, res) => {
  try {
    const { id } = req.params;
    const exam = await Exam.findById(id)
      .populate('subject_id', 'subject_code subject_name')
      .populate('created_by', 'full_name email');

    if (!exam) {
      return res.status(404).json({
        success: false,
        message: 'Ca thi không tồn tại'
      });
    }

    const eligibilities = await ExamEligibility.find({ exam_id: id })
      .populate('student_id', 'full_name user_code email');

    const attempts = await ExamAttempt.find({ exam_id: id })
      .populate('student_id', 'full_name user_code email');

    const attemptsMap = new Map();
    attempts.forEach((att) => {
      if (att.student_id) {
        attemptsMap.set(att.student_id._id.toString(), att);
      }
    });

    let submittedCount = 0;
    let suspendedCount = 0;
    let inProgressCount = 0;
    let passCount = 0;
    let failCount = 0;
    const scores = [];

    const histogram = {
      under5: 0,
      from5To65: 0,
      from65To8: 0,
      from8To10: 0
    };

    attempts.forEach((att) => {
      if (att.status === 'SUBMITTED') {
        submittedCount++;
        scores.push(att.total_score || 0);
        const s = att.total_score || 0;
        if (s < 5.0) histogram.under5++;
        else if (s < 6.5) histogram.from5To65++;
        else if (s < 8.0) histogram.from65To8++;
        else histogram.from8To10++;

        if (att.is_passed) passCount++;
        else failCount++;
      } else if (att.status === 'DISQUALIFIED' || att.status === 'SUSPENDED') {
        suspendedCount++;
      } else if (att.status === 'IN_PROGRESS') {
        inProgressCount++;
      }
    });

    const studentResults = [];
    const addedStudentIds = new Set();

    eligibilities.forEach((el) => {
      const stu = el.student_id;
      if (!stu) return;
      addedStudentIds.add(stu._id.toString());
      const att = attemptsMap.get(stu._id.toString());
      studentResults.push({
        student_id: stu._id,
        user_code: stu.user_code,
        full_name: stu.full_name,
        email: stu.email,
        score: att ? att.total_score : null,
        is_passed: att ? att.is_passed : false,
        status: att ? att.status : 'NOT_STARTED',
        violation_count: att ? att.violation_count : 0,
        submitted_at: att ? att.submitted_at : null
      });
    });

    // Bổ sung các sinh viên đã vào làm bài nhưng chưa nằm trong danh sách phân bổ sẵn
    attempts.forEach((att) => {
      const stu = att.student_id;
      if (!stu || addedStudentIds.has(stu._id.toString())) return;
      addedStudentIds.add(stu._id.toString());
      studentResults.push({
        student_id: stu._id,
        user_code: stu.user_code,
        full_name: stu.full_name,
        email: stu.email,
        score: att.total_score,
        is_passed: att.is_passed,
        status: att.status,
        violation_count: att.violation_count,
        submitted_at: att.submitted_at
      });
    });

    const totalRegistered = Math.max(eligibilities.length, studentResults.length);
    const notStartedCount = Math.max(0, totalRegistered - attempts.length);
    const avgScore = scores.length > 0 ? scores.reduce((a, b) => a + b, 0) / scores.length : 0;
    const maxScore = scores.length > 0 ? Math.max(...scores) : 0;
    const minScore = scores.length > 0 ? Math.min(...scores) : 0;

    res.status(200).json({
      success: true,
      data: {
        exam: {
          id: exam._id,
          title: exam.exam_title,
          subject: exam.subject_id,
          duration_minutes: exam.duration_minutes,
          status: exam.status,
          allow_review: exam.allow_review
        },
        summary: {
          total_registered: totalRegistered,
          total_attempts: attempts.length,
          submitted_count: submittedCount,
          suspended_count: suspendedCount,
          in_progress_count: inProgressCount,
          not_started_count: notStartedCount,
          pass_count: passCount,
          fail_count: failCount,
          pass_rate: submittedCount > 0 ? Math.round((passCount / submittedCount) * 100) : 0,
          average_score: Math.round(avgScore * 100) / 100,
          highest_score: maxScore,
          lowest_score: minScore
        },
        histogram,
        students: studentResults
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

const exportExamGrades = async (req, res) => {
  try {
    const { id } = req.params;
    const exam = await Exam.findById(id).populate('subject_id', 'subject_code subject_name');

    if (!exam) {
      return res.status(404).json({
        success: false,
        message: 'Ca thi không tồn tại'
      });
    }

    const eligibilities = await ExamEligibility.find({ exam_id: id })
      .populate('student_id', 'full_name user_code email');
    const attempts = await ExamAttempt.find({ exam_id: id })
      .populate('student_id', 'full_name user_code email');

    const attemptsMap = new Map();
    attempts.forEach((a) => {
      if (a.student_id) attemptsMap.set(a.student_id._id.toString(), a);
    });

    let csvContent = '\uFEFF';
    csvContent += 'STT,Mã sinh viên,Họ và tên,Email,Điểm số,Kết quả,Số vi phạm,Thời gian nộp,Trạng thái\n';

    let rowIndex = 1;
    const exportedStudentIds = new Set();

    eligibilities.forEach((el) => {
      const stu = el.student_id;
      if (!stu) return;
      exportedStudentIds.add(stu._id.toString());
      const att = attemptsMap.get(stu._id.toString());
      const score = att && att.total_score !== undefined ? att.total_score : '';
      const result = att ? (att.is_passed ? 'ĐẠT' : 'KHÔNG ĐẠT') : 'CHƯA THI';
      const violations = att ? att.violation_count : 0;
      const submitTime = att && att.submitted_at ? new Date(att.submitted_at).toLocaleString('vi-VN') : '';
      const status = att ? att.status : 'NOT_STARTED';

      csvContent += `${rowIndex++},"${stu.user_code}","${stu.full_name}","${stu.email}","${score}","${result}",${violations},"${submitTime}","${status}"\n`;
    });

    attempts.forEach((att) => {
      const stu = att.student_id;
      if (!stu || exportedStudentIds.has(stu._id.toString())) return;
      exportedStudentIds.add(stu._id.toString());
      const score = att.total_score !== undefined ? att.total_score : '';
      const result = att.is_passed ? 'ĐẠT' : 'KHÔNG ĐẠT';
      const violations = att.violation_count || 0;
      const submitTime = att.submitted_at ? new Date(att.submitted_at).toLocaleString('vi-VN') : '';
      const status = att.status || 'IN_PROGRESS';

      csvContent += `${rowIndex++},"${stu.user_code}","${stu.full_name}","${stu.email}","${score}","${result}",${violations},"${submitTime}","${status}"\n`;
    });

    res.setHeader('Content-Type', 'text/csv; charset=utf-8');
    res.setHeader('Content-Disposition', `attachment; filename="bang_diem_${exam.subject_id?.subject_code || 'thi'}.csv"`);
    res.status(200).send(csvContent);
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

module.exports = {
  createExam,
  assignQuestions,
  assignStudents,
  publishExam,
  getExams,
  getExamDetail,
  updateExam,
  deleteExam,
  getExamStatistics,
  exportExamGrades
};

