const {
  Exam,
  ExamAttempt,
  ExamQuestion,
  Question,
  QuestionOption,
  StudentAnswer,
  ExamEligibility,
  ViolationLog
} = require('../models');

const startAttempt = async (req, res) => {
  try {
    const { exam_id, access_pin } = req.body;
    const student_id = req.user._id;

    if (!exam_id) {
      return res.status(400).json({
        success: false,
        message: 'Mã kỳ thi (exam_id) là bắt buộc'
      });
    }

    const exam = await Exam.findById(exam_id);
    if (!exam) {
      return res.status(404).json({
        success: false,
        message: 'Kỳ thi không tồn tại'
      });
    }

    if (!['PUBLISHED', 'ONGOING'].includes(exam.status)) {
      return res.status(400).json({
        success: false,
        message: 'Kỳ thi chưa được mở hoặc đã kết thúc'
      });
    }

    if (exam.access_pin && exam.access_pin !== access_pin) {
      return res.status(403).json({
        success: false,
        message: 'Mã PIN ca thi không chính xác'
      });
    }

    // Kiểm tra danh sách thí sinh hợp lệ (nếu có phân bổ)
    const eligibility = await ExamEligibility.findOne({ exam_id, student_id });
    if (eligibility && eligibility.is_banned) {
      return res.status(403).json({
        success: false,
        message: 'Bạn đã bị đình chỉ thi đối với ca thi này'
      });
    }

    let attempt = await ExamAttempt.findOne({ exam_id, student_id });

    if (attempt && attempt.status === 'SUBMITTED') {
      return res.status(400).json({
        success: false,
        message: 'Bạn đã hoàn thành và nộp bài thi này trước đó'
      });
    }

    if (!attempt) {
      attempt = await ExamAttempt.create({
        exam_id,
        student_id,
        started_at: new Date(),
        status: 'IN_PROGRESS',
        violation_count: 0
      });
    }

    // Lấy danh sách câu hỏi trong đề
    const examQuestions = await ExamQuestion.find({ exam_id })
      .populate({
        path: 'question_id',
        select: 'question_code question_type difficulty_level content description default_score'
      });

    const questionList = [];
    for (const eq of examQuestions) {
      if (eq.question_id) {
        // Bảo mật: Ẩn is_correct khi gửi về cho thí sinh
        const options = await QuestionOption.find({ question_id: eq.question_id._id })
          .select('_id question_id option_content hint');

        questionList.push({
          question: eq.question_id,
          options
        });
      }
    }

    // Lấy các câu đã chọn trước đó nếu có (phục vụ reconnect)
    const existingAnswers = await StudentAnswer.find({ attempt_id: attempt._id });

    res.status(200).json({
      success: true,
      data: {
        attempt_id: attempt._id,
        exam_title: exam.exam_title,
        duration_minutes: exam.duration_minutes,
        max_violations: exam.max_violations,
        started_at: attempt.started_at,
        questions: questionList,
        saved_answers: existingAnswers
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

const saveAnswer = async (req, res) => {
  try {
    const { attempt_id, question_id, selected_option_id, answer_text } = req.body;

    if (!attempt_id || !question_id) {
      return res.status(400).json({
        success: false,
        message: 'attempt_id và question_id là bắt buộc'
      });
    }

    const attempt = await ExamAttempt.findById(attempt_id);
    if (!attempt || attempt.status !== 'IN_PROGRESS') {
      return res.status(400).json({
        success: false,
        message: 'Lượt thi không ở trạng thái làm bài'
      });
    }

    const answer = await StudentAnswer.findOneAndUpdate(
      { attempt_id, question_id },
      {
        selected_option_id: selected_option_id || null,
        answer_text: answer_text || ''
      },
      { upsert: true, new: true, setDefaultsOnInsert: true }
    );

    res.status(200).json({
      success: true,
      message: 'Lưu đáp án thành công',
      data: answer
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

const submitExam = async (req, res) => {
  try {
    const { attempt_id } = req.params;

    const attempt = await ExamAttempt.findById(attempt_id);
    if (!attempt) {
      return res.status(404).json({
        success: false,
        message: 'Lượt thi không tồn tại'
      });
    }

    if (['SUBMITTED', 'DISQUALIFIED'].includes(attempt.status)) {
      return res.status(200).json({
        success: true,
        message: 'Bài thi đã kết thúc trước đó',
        data: {
          total_score: attempt.total_score,
          is_passed: attempt.is_passed,
          submitted_at: attempt.submitted_at,
          violation_count: attempt.violation_count,
          status: attempt.status
        }
      });
    }

    const exam = await Exam.findById(attempt.exam_id);
    const answers = await StudentAnswer.find({ attempt_id });

    let totalScore = 0;

    for (const ans of answers) {
      if (ans.selected_option_id) {
        const option = await QuestionOption.findById(ans.selected_option_id);
        const question = await Question.findById(ans.question_id);

        const isCorrect = option ? !!option.is_correct : false;
        const score = isCorrect ? (question ? question.default_score : 1.0) : 0;

        ans.score_awarded = score;
        await ans.save();

        totalScore += score;
      }
    }

    const minPass = exam ? (exam.min_pass_percentage || 50) : 50;
    const isPassed = totalScore >= (minPass / 100) * 10;

    attempt.total_score = Math.round(totalScore * 100) / 100;
    attempt.submitted_at = new Date();
    attempt.status = 'SUBMITTED';
    attempt.is_passed = isPassed;
    await attempt.save();

    res.status(200).json({
      success: true,
      message: 'Nộp bài thi thành công',
      data: {
        total_score: attempt.total_score,
        is_passed: attempt.is_passed,
        submitted_at: attempt.submitted_at,
        violation_count: attempt.violation_count
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

const getExamViolationLogs = async (req, res) => {
  try {
    const { exam_id } = req.params;

    const attempts = await ExamAttempt.find({ exam_id })
      .populate('student_id', 'full_name user_code email');

    const attemptIds = attempts.map((a) => a._id);
    const violations = await ViolationLog.find({ attempt_id: { $in: attemptIds } })
      .populate({
        path: 'attempt_id',
        populate: { path: 'student_id', select: 'full_name user_code email' }
      })
      .sort({ detected_at: -1 });

    res.status(200).json({
      success: true,
      data: {
        total_violations: violations.length,
        violations
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

const reportViolation = async (req, res) => {
  try {
    const { attempt_id, exam_id, violation_type, violation_details } = req.body;

    if (!attempt_id || !exam_id) {
      return res.status(400).json({
        success: false,
        message: 'attempt_id và exam_id là bắt buộc'
      });
    }

    const violation = await ViolationLog.create({
      attempt_id,
      violation_type: violation_type || 'APP_UNFOCUSED',
      violation_details: violation_details || '',
      detected_at: new Date()
    });

    const attempt = await ExamAttempt.findByIdAndUpdate(
      attempt_id,
      { $inc: { violation_count: 1 } },
      { new: true }
    );

    const exam = await Exam.findById(exam_id);
    const maxViolations = exam ? exam.max_violations : 3;

    let isDisqualified = false;
    if (attempt && attempt.violation_count >= maxViolations) {
      attempt.status = 'DISQUALIFIED';
      attempt.end_reason = 'EXCEEDED_MAX_VIOLATIONS';
      attempt.submitted_at = new Date();
      await attempt.save();
      isDisqualified = true;
    }

    res.status(200).json({
      success: true,
      message: 'Ghi nhận vi phạm thành công',
      data: {
        violation_id: violation._id,
        violation_count: attempt ? attempt.violation_count : 1,
        max_violations: maxViolations,
        is_disqualified: isDisqualified
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
  startAttempt,
  saveAnswer,
  submitExam,
  reportViolation,
  getExamViolationLogs
};

