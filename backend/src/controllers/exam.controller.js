const {
  Exam,
  ExamQuestion,
  ExamEligibility,
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
      shuffle_options
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
      status: 'DRAFT'
    });

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

    const totalQuestions = await ExamQuestion.countDocuments({ exam_id: id });
    const totalStudents = await ExamEligibility.countDocuments({ exam_id: id });

    res.status(200).json({
      success: true,
      data: {
        exam,
        stats: {
          total_questions: totalQuestions,
          total_students: totalStudents
        }
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
  getExams,
  getExamDetail
};

