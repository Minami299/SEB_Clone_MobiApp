const {
  Exam,
  ExamQuestion,
  ExamEligibility,
  ExamAttempt,
  Question,
  Class,
  ClassEnrollment,
  Subject,
  User
} = require('../models');

const hasSubjectScope = async (user, subjectId) => {
  if (user.role === 'ADMIN') return true;
  if (!user.department_id) return false;
  return !!(await Subject.exists({ _id: subjectId, department_id: user.department_id }));
};

const canAccessExam = async (user, examId) => {
  if (user.role !== 'HEAD_OF_SUBJECT') return true;
  if (!user.department_id) return false;
  const exam = await Exam.findById(examId).populate('subject_id', 'department_id');
  return !!exam && exam.subject_id?.department_id?.toString() === user.department_id.toString();
};

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
      mcq_grading_method,
      shuffle_questions,
      shuffle_options,
      allow_review,
      question_ids,
      student_ids,
      matrix_config
    } = req.body;

    if (!subject_id || !exam_title || !start_time || !end_time || !duration_minutes) {
      return res.status(400).json({
        success: false,
        message: 'Vui lòng cung cấp đầy đủ thông tin ca thi: môn học, tiêu đề, thời gian bắt đầu, kết thúc và thời lượng'
      });
    }

    if (!await hasSubjectScope(req.user, subject_id)) {
      return res.status(403).json({ success: false, message: 'Bạn không phụ trách môn học này' });
    }
    if (class_id) {
      const classDoc = await Class.findById(class_id).select('subject_id');
      if (!classDoc || classDoc.subject_id.toString() !== subject_id.toString()) {
        return res.status(400).json({ success: false, message: 'Lớp học phần không thuộc môn thi đã chọn' });
      }
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
      exit_pin: req.body.exit_pin || '888888',
      mcq_grading_method: mcq_grading_method || 'ALL_CORRECT',
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

    if (Array.isArray(student_ids) && student_ids.length > 0) {
      const eligDocs = student_ids.map((sId) => ({
        exam_id: exam._id,
        student_id: sId,
        is_banned: false
      }));
      await ExamEligibility.insertMany(eligDocs);
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
    if (!await canAccessExam(req.user, id)) return res.status(403).json({ success: false, message: 'Bạn không có quyền với kỳ thi này' });

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
    if (!await canAccessExam(req.user, id)) return res.status(403).json({ success: false, message: 'Bạn không có quyền với kỳ thi này' });

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
    const exists = await Exam.exists({ _id: id });
    if (!exists) return res.status(404).json({ success: false, message: 'Ca thi không tồn tại' });
    if (!await canAccessExam(req.user, id)) return res.status(403).json({ success: false, message: 'Bạn không có quyền với kỳ thi này' });
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

const closeExam = async (req, res) => {
  try {
    const { id } = req.params;
    const exam = await Exam.findByIdAndUpdate(
      id,
      { status: 'COMPLETED' },
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
      message: 'Ca thi đã được đóng thành công (COMPLETED)',
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
    } else if (req.user.role === 'HEAD_OF_SUBJECT') {
      const subjects = req.user.department_id
        ? await Subject.find({ department_id: req.user.department_id }).distinct('_id')
        : [];
      filter.subject_id = { $in: subjects };
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
    if (!await canAccessExam(req.user, id)) return res.status(403).json({ success: false, message: 'Bạn không có quyền với kỳ thi này' });

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
    if (!await canAccessExam(req.user, id)) return res.status(403).json({ success: false, message: 'Bạn không có quyền với kỳ thi này' });

    if (exam.status === 'ONGOING' || exam.status === 'COMPLETED') {
      return res.status(400).json({
        success: false,
        message: 'Không thể chỉnh sửa ca thi đang diễn ra hoặc đã kết thúc'
      });
    }

    const {
      class_id,
      exam_title,
      description,
      start_time,
      end_time,
      duration_minutes,
      max_violations,
      access_pin,
      min_pass_percentage,
      mcq_grading_method,
      shuffle_questions,
      shuffle_options,
      allow_review,
      question_ids,
      student_ids,
      matrix_config,
      status
    } = req.body;

    if (class_id !== undefined) exam.class_id = class_id || null;
    if (class_id) {
      const classDoc = await Class.findById(class_id).select('subject_id');
      if (!classDoc || classDoc.subject_id.toString() !== exam.subject_id.toString()) {
        return res.status(400).json({ success: false, message: 'Lớp học phần không thuộc môn thi đã chọn' });
      }
    }
    if (exam_title) exam.exam_title = exam_title;
    if (description !== undefined) exam.description = description;
    if (start_time) exam.start_time = new Date(start_time);
    if (end_time) exam.end_time = new Date(end_time);
    if (duration_minutes) exam.duration_minutes = Number(duration_minutes);
    if (max_violations !== undefined) exam.max_violations = Number(max_violations);
    if (access_pin !== undefined) exam.access_pin = access_pin;
    if (req.body.exit_pin !== undefined) exam.exit_pin = req.body.exit_pin;
    if (min_pass_percentage !== undefined) exam.min_pass_percentage = Number(min_pass_percentage);
    if (mcq_grading_method !== undefined) exam.mcq_grading_method = mcq_grading_method;
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
    if (Array.isArray(student_ids)) {
      await ExamEligibility.deleteMany({ exam_id: id });
      const eligDocs = student_ids.map((sId) => ({
        exam_id: id,
        student_id: sId,
        is_banned: false
      }));
      await ExamEligibility.insertMany(eligDocs);
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
    if (!await canAccessExam(req.user, id)) return res.status(403).json({ success: false, message: 'Bạn không có quyền với kỳ thi này' });

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
    if (!await canAccessExam(req.user, id)) return res.status(403).json({ success: false, message: 'Bạn không có quyền với kỳ thi này' });

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
    if (!await canAccessExam(req.user, id)) return res.status(403).json({ success: false, message: 'Bạn không có quyền với kỳ thi này' });

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

const getClassesBySubject = async (req, res) => {
  try {
    const { subject_id } = req.params;
    const filter = { subject_id };
    if (!await hasSubjectScope(req.user, subject_id)) return res.status(403).json({ success: false, message: 'Bạn không phụ trách môn học này' });
    if (req.user.role === 'LECTURER') {
      filter.lecturer_id = req.user._id;
    }
    const classes = await Class.find(filter).populate('lecturer_id', 'full_name email');
    res.status(200).json({
      success: true,
      data: classes
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

const searchStudents = async (req, res) => {
  try {
    const { q } = req.query;
    const filter = { role: 'STUDENT', status: 'ACTIVE' };
    if (q && q.trim().length > 0) {
      const regex = new RegExp(q.trim(), 'i');
      filter.$or = [
        { full_name: regex },
        { user_code: regex },
        { email: regex }
      ];
    }
    const students = await User.find(filter)
      .select('full_name user_code email')
      .limit(60);
    res.status(200).json({
      success: true,
      data: students
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

const getClassStudents = async (req, res) => {
  try {
    const { class_id } = req.params;
    const classDoc = await Class.findById(class_id).select('subject_id');
    if (!classDoc) return res.status(404).json({ success: false, message: 'Lớp học phần không tồn tại' });
    if (!await hasSubjectScope(req.user, classDoc.subject_id)) return res.status(403).json({ success: false, message: 'Bạn không phụ trách môn học của lớp này' });
    const enrollments = await ClassEnrollment.find({ class_id }).populate('student_id', 'full_name user_code email');
    const students = enrollments.map((e) => e.student_id).filter(Boolean);
    res.status(200).json({
      success: true,
      data: students
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

const getLivePin = async (req, res) => {
  try {
    const { id } = req.params;
    const exam = await Exam.findById(id);

    if (!exam) {
      return res.status(404).json({
        success: false,
        message: 'Ca thi không tồn tại'
      });
    }

    const now = Date.now();
    const lastUpdated = exam.pin_updated_at ? new Date(exam.pin_updated_at).getTime() : now;
    const elapsedSeconds = Math.floor((now - lastUpdated) / 1000);
    const interval = exam.pin_rotate_interval_seconds || 300;

    const totalCandidates = await ExamEligibility.countDocuments({ exam_id: id });
    const activeAttempts = await ExamAttempt.countDocuments({
      exam_id: id,
      status: { $in: ['IN_PROGRESS', 'SUBMITTED', 'COMPLETED', 'DISQUALIFIED'] }
    });

    // Nếu chưa có PIN hoặc đã hết chu kỳ 5 phút thì tự động sinh PIN mới
    if (!exam.access_pin || elapsedSeconds >= interval) {
      const newPin = Math.floor(100000 + Math.random() * 900000).toString();
      exam.previous_pin = exam.access_pin || null;
      exam.access_pin = newPin;
      exam.pin_updated_at = new Date();
      await exam.save();

      return res.status(200).json({
        success: true,
        data: {
          access_pin: exam.access_pin,
          previous_pin: exam.previous_pin,
          remaining_seconds: interval,
          interval_seconds: interval,
          pin_updated_at: exam.pin_updated_at,
          total_candidates: totalCandidates,
          active_attempts: activeAttempts
        }
      });
    }

    const remainingSeconds = Math.max(0, interval - elapsedSeconds);
    return res.status(200).json({
      success: true,
      data: {
        access_pin: exam.access_pin,
        previous_pin: exam.previous_pin,
        remaining_seconds: remainingSeconds,
        interval_seconds: interval,
        pin_updated_at: exam.pin_updated_at,
        total_candidates: totalCandidates,
        active_attempts: activeAttempts
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

const refreshPin = async (req, res) => {
  try {
    const { id } = req.params;
    const exam = await Exam.findById(id);

    if (!exam) {
      return res.status(404).json({
        success: false,
        message: 'Ca thi không tồn tại'
      });
    }

    const newPin = Math.floor(100000 + Math.random() * 900000).toString();
    exam.previous_pin = exam.access_pin || null;
    exam.access_pin = newPin;
    exam.pin_updated_at = new Date();
    await exam.save();

    const totalCandidates = await ExamEligibility.countDocuments({ exam_id: id });
    const activeAttempts = await ExamAttempt.countDocuments({
      exam_id: id,
      status: { $in: ['IN_PROGRESS', 'SUBMITTED', 'COMPLETED', 'DISQUALIFIED'] }
    });

    const interval = exam.pin_rotate_interval_seconds || 300;
    return res.status(200).json({
      success: true,
      message: 'Đã đổi mã PIN ca thi thành công',
      data: {
        access_pin: exam.access_pin,
        previous_pin: exam.previous_pin,
        remaining_seconds: interval,
        interval_seconds: interval,
        pin_updated_at: exam.pin_updated_at,
        total_candidates: totalCandidates,
        active_attempts: activeAttempts
      }
    });
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
  closeExam,
  getExams,
  getExamDetail,
  updateExam,
  deleteExam,
  getExamStatistics,
  exportExamGrades,
  getClassesBySubject,
  getClassStudents,
  getLivePin,
  refreshPin,
  searchStudents
};

