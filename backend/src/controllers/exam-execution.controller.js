const {
  Exam,
  ExamAttempt,
  ExamQuestion,
  Question,
  QuestionOption,
  StudentAnswer,
  ExamEligibility,
  ViolationLog,
  Chapter
} = require('../models');
const crypto = require('crypto');

const getCurrentPin = (exam) => {
  if (!exam.entry_pin_secret) return null;
  const refreshSeconds = Number(exam.pin_refresh_seconds) || 300;
  const slot = Math.floor(Date.now() / (refreshSeconds * 1000));
  const digest = crypto
    .createHmac('sha256', exam.entry_pin_secret)
    .update(`${exam._id}:${slot}`)
    .digest('hex');
  return String(parseInt(digest.slice(0, 12), 16) % 1000000).padStart(6, '0');
};

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

    const exam = await Exam.findById(exam_id).select('+entry_pin_secret');
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

    if (!exam.entry_pin_secret) {
      exam.entry_pin_secret = '123456';
      await exam.save();
    }
    if (typeof access_pin !== 'string' || access_pin !== getCurrentPin(exam)) {
      return res.status(403).json({ success: false, message: 'Mã vào thi không đúng hoặc đã hết hạn' });
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

    let targetQuestionIds = [];

    // Nếu đã có assigned_questions (thí sinh kết nối lại):
    if (attempt && Array.isArray(attempt.assigned_questions) && attempt.assigned_questions.length > 0) {
      targetQuestionIds = attempt.assigned_questions;
    } else if (exam.matrix_config && exam.matrix_config.is_dynamic && Array.isArray(exam.matrix_config.rules) && exam.matrix_config.rules.length > 0) {
      // Chế độ 2: Sinh đề ngẫu nhiên theo ma trận
      const includePrivate = exam.matrix_config.include_private !== false;
      const pickedSet = new Set();
      const dynamicList = [];

      // Lấy danh sách chương của môn học để map chapter_number -> chapter_id nếu cần
      const chapters = await Chapter.find({ subject_id: exam.subject_id });
      const chapterMap = new Map();
      chapters.forEach((ch) => {
        chapterMap.set(ch.chapter_number, ch._id);
      });

      for (const rule of exam.matrix_config.rules) {
        const { chapter_num, difficulty, count } = rule;
        const requestedCount = Number(count) || 1;
        const targetChapterId = chapterMap.get(Number(chapter_num));

        const baseFilter = {
          subject_id: exam.subject_id,
          _id: { $nin: Array.from(pickedSet) }
        };

        // Điều kiện chương
        if (targetChapterId) {
          baseFilter.$or = [
            { chapter_num: Number(chapter_num) },
            { chapter_id: targetChapterId }
          ];
        } else {
          baseFilter.chapter_num = Number(chapter_num);
        }

        // Điều kiện độ khó
        const diffUpper = (difficulty || 'MEDIUM').toUpperCase();
        const diffCond = {
          $or: [
            { difficulty: diffUpper },
            { difficulty_level: diffUpper }
          ]
        };

        // Điều kiện scope: Public hoặc Private của người tạo kỳ thi
        const scopeCond = includePrivate
          ? {
              $or: [
                { scope: 'PUBLIC' },
                { is_public: true },
                { created_by: exam.created_by }
              ]
            }
          : {
              $or: [
                { scope: 'PUBLIC' },
                { is_public: true }
              ]
            };

        baseFilter.$and = [diffCond, scopeCond];

        // Lấy danh sách câu hỏi thỏa mãn và bốc ngẫu nhiên
        const candidates = await Question.find(baseFilter);
        const shuffled = candidates.sort(() => Math.random() - 0.5);
        const selected = shuffled.slice(0, requestedCount);

        for (const q of selected) {
          pickedSet.add(q._id.toString());
          dynamicList.push(q._id);
        }
      }

      attempt.assigned_questions = dynamicList;
      await attempt.save();
      targetQuestionIds = dynamicList;
    } else {
      // Chế độ 1: Chọn cố định danh sách câu hỏi
      const examQuestions = await ExamQuestion.find({ exam_id });
      if (examQuestions.length > 0) {
        targetQuestionIds = examQuestions.map((eq) => eq.question_id).filter(Boolean);
      } else if (Array.isArray(exam.question_ids) && exam.question_ids.length > 0) {
        targetQuestionIds = exam.question_ids;
      }
      attempt.assigned_questions = targetQuestionIds;
      await attempt.save();
    }

    // Tải danh sách chi tiết các câu hỏi đã phân bổ
    const questionDocs = await Question.find({ _id: { $in: targetQuestionIds } })
      .select('question_code question_type difficulty_level difficulty content description default_score chapter_num');

    let orderedQuestions = targetQuestionIds
      .map((id) => {
        const idStr = id && id._id ? id._id.toString() : (id ? id.toString() : '');
        return questionDocs.find((q) => q._id.toString() === idStr);
      })
      .filter(Boolean);

    // Xáo trộn thứ tự câu hỏi nếu kỳ thi bật shuffle_questions
    if (exam.shuffle_questions) {
      orderedQuestions = orderedQuestions.sort(() => Math.random() - 0.5);
    }

    const questionList = [];
    for (const q of orderedQuestions) {
      // Bảo mật: Ẩn is_correct khi gửi về cho thí sinh
      const options = await QuestionOption.find({ question_id: q._id })
        .select('_id question_id option_content hint');

      // Luôn xáo trộn (shuffle) thứ tự phương án trả lời của từng câu hỏi
      const shuffledOptions = options.sort(() => Math.random() - 0.5);

      questionList.push({
        question: q,
        options: shuffledOptions
      });
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

    const eligibilities = await ExamEligibility.find({ exam_id })
      .populate('student_id', 'full_name user_code email');

    const attempts = await ExamAttempt.find({ exam_id })
      .populate('student_id', 'full_name user_code email');

    const attemptIds = attempts.map((a) => a._id);
    const violations = await ViolationLog.find({ attempt_id: { $in: attemptIds } })
      .populate({
        path: 'attempt_id',
        populate: { path: 'student_id', select: 'full_name user_code email' }
      })
      .sort({ detected_at: -1 });

    const attemptsMap = new Map();
    attempts.forEach((att) => {
      if (att.student_id) {
        attemptsMap.set(att.student_id._id.toString(), att);
      }
    });

    const studentStatuses = [];
    eligibilities.forEach((el) => {
      const stu = el.student_id;
      if (!stu) return;
      const att = attemptsMap.get(stu._id.toString());
      studentStatuses.push({
        student_id: stu._id,
        user_code: stu.user_code,
        full_name: stu.full_name,
        email: stu.email,
        attempt_id: att ? att._id : null,
        status: att ? att.status : 'NOT_STARTED',
        violation_count: att ? (att.violation_count || 0) : 0,
        started_at: att ? att.started_at : null,
        submitted_at: att ? att.submitted_at : null
      });
    });

    attempts.forEach((att) => {
      if (att.student_id && !studentStatuses.some(s => s.student_id.toString() === att.student_id._id.toString())) {
        studentStatuses.push({
          student_id: att.student_id._id,
          user_code: att.student_id.user_code,
          full_name: att.student_id.full_name,
          email: att.student_id.email,
          attempt_id: att._id,
          status: att.status,
          violation_count: att.violation_count || 0,
          started_at: att.started_at,
          submitted_at: att.submitted_at
        });
      }
    });

    const inProgressCount = studentStatuses.filter(s => s.status === 'IN_PROGRESS').length;
    const submittedCount = studentStatuses.filter(s => s.status === 'SUBMITTED').length;
    const notStartedCount = studentStatuses.filter(s => s.status === 'NOT_STARTED').length;
    const suspendedCount = studentStatuses.filter(s => s.status === 'DISQUALIFIED' || s.status === 'SUSPENDED').length;

    res.status(200).json({
      success: true,
      data: {
        total_violations: violations.length,
        total_registered: studentStatuses.length,
        in_progress_count: inProgressCount,
        submitted_count: submittedCount,
        not_started_count: notStartedCount,
        suspended_count: suspendedCount,
        active_in_exam: inProgressCount + submittedCount + suspendedCount,
        student_statuses: studentStatuses,
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

const getAttemptResult = async (req, res) => {
  try {
    const { attemptId } = req.params;
    const attempt = await ExamAttempt.findById(attemptId)
      .populate('student_id', 'full_name user_code email')
      .populate({
        path: 'exam_id',
        populate: { path: 'subject_id', select: 'subject_code subject_name' }
      });

    if (!attempt) {
      return res.status(404).json({
        success: false,
        message: 'Không tìm thấy lượt thi'
      });
    }

    const exam = attempt.exam_id;
    const isProctor = req.user.role !== 'STUDENT';
    const hasExamEnded = exam && exam.end_time && new Date() > new Date(exam.end_time);
    const allowReview = isProctor || (exam && exam.allow_review) || hasExamEnded;

    let targetQuestions = [];
    if (attempt.assigned_questions && attempt.assigned_questions.length > 0) {
      targetQuestions = await Question.find({ _id: { $in: attempt.assigned_questions } });
    } else {
      const examQuestions = await ExamQuestion.find({ exam_id: exam._id })
        .populate('question_id');
      targetQuestions = examQuestions.map((eq) => eq.question_id).filter(Boolean);
      if (targetQuestions.length === 0 && Array.isArray(exam.question_ids) && exam.question_ids.length > 0) {
        targetQuestions = await Question.find({ _id: { $in: exam.question_ids } });
      }
    }
    const totalQuestions = targetQuestions.length;

    const studentAnswers = await StudentAnswer.find({ attempt_id: attemptId });
    const answerMap = new Map();
    studentAnswers.forEach((ans) => {
      answerMap.set(ans.question_id.toString(), ans);
    });

    let correctCount = 0;
    let wrongCount = 0;
    let unansweredCount = 0;

    const reviewQuestions = [];

    for (const q of targetQuestions) {
      if (!q) continue;

      const ans = answerMap.get(q._id.toString());
      const selectedOptionId = ans ? ans.selected_option_id : null;

      let isCorrect = false;
      let correctOptionId = null;

      const options = await QuestionOption.find({ question_id: q._id });
      const correctOpt = options.find((o) => o.is_correct);
      if (correctOpt) {
        correctOptionId = correctOpt._id;
      }

      if (!selectedOptionId) {
        unansweredCount++;
      } else {
        if (correctOptionId && selectedOptionId.toString() === correctOptionId.toString()) {
          correctCount++;
          isCorrect = true;
        } else {
          wrongCount++;
        }
      }

      if (allowReview) {
        reviewQuestions.push({
          question_id: q._id,
          question_code: q.question_code,
          content: q.content,
          question_type: q.question_type,
          difficulty_level: q.difficulty_level || q.difficulty,
          default_score: q.default_score,
          score_awarded: ans ? ans.score_awarded : 0,
          selected_option_id: selectedOptionId,
          correct_option_id: correctOptionId,
          is_correct: isCorrect,
          options: options.map((opt) => ({
            id: opt._id,
            content: opt.option_content,
            is_correct: opt.is_correct
          }))
        });
      }
    }

    const durationTakenSeconds = attempt.submitted_at && attempt.started_at
      ? Math.max(0, Math.floor((new Date(attempt.submitted_at) - new Date(attempt.started_at)) / 1000))
      : 0;

    const maxScore = targetQuestions.reduce((acc, q) => acc + (q?.default_score || 1.0), 0);
    const percentage = maxScore > 0 ? Math.round(((attempt.total_score || 0) / maxScore) * 100) : 0;

    // Lấy danh sách vi phạm của lượt thi này
    const violations = await ViolationLog.find({ attempt_id: attempt._id }).sort({ detected_at: 1 });

    res.status(200).json({
      success: true,
      data: {
        attempt_id: attempt._id,
        exam_id: exam._id,
        exam_title: exam.exam_title,
        subject_code: exam.subject_id?.subject_code || '',
        subject_name: exam.subject_id?.subject_name || '',
        student: attempt.student_id,
        total_score: attempt.total_score || 0,
        max_score: maxScore,
        percentage,
        is_passed: attempt.is_passed,
        status: attempt.status,
        end_reason: attempt.end_reason,
        violation_count: attempt.violation_count || 0,
        violations: violations.map((v) => ({
          id: v._id,
          type: v.violation_type,
          details: v.violation_details,
          time: v.detected_at
        })),
        started_at: attempt.started_at,
        submitted_at: attempt.submitted_at,
        duration_taken_seconds: durationTakenSeconds,
        total_questions: totalQuestions,
        correct_count: correctCount,
        wrong_count: wrongCount,
        unanswered_count: unansweredCount,
        allow_review: allowReview,
        review_questions: allowReview ? reviewQuestions : []
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

const forceSuspendAttempt = async (req, res) => {
  try {
    const { attemptId } = req.params;
    const { reason, details } = req.body;

    const attempt = await ExamAttempt.findById(attemptId).populate('student_id', 'full_name user_code email');
    if (!attempt) {
      return res.status(404).json({
        success: false,
        message: 'Không tìm thấy lượt thi'
      });
    }

    attempt.status = 'DISQUALIFIED';
    attempt.end_reason = reason || 'PROCTOR_FORCE_SUSPEND';
    attempt.submitted_at = new Date();
    await attempt.save();

    await ViolationLog.create({
      attempt_id: attempt._id,
      violation_type: 'PROCTOR_DISQUALIFIED',
      violation_details: details || reason || 'Giám thị đình chỉ thi trực tiếp',
      detected_at: new Date()
    });

    res.status(200).json({
      success: true,
      message: 'Đã đình chỉ lượt thi thành công',
      data: attempt
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

const unlockAttempt = async (req, res) => {
  try {
    const { attemptId } = req.params;
    const attempt = await ExamAttempt.findById(attemptId).populate('student_id', 'full_name user_code email');
    if (!attempt) {
      return res.status(404).json({
        success: false,
        message: 'Không tìm thấy lượt thi'
      });
    }

    attempt.status = 'IN_PROGRESS';
    attempt.end_reason = null;
    attempt.submitted_at = null;
    attempt.violation_count = Math.max(0, (attempt.violation_count || 1) - 1);
    await attempt.save();

    res.status(200).json({
      success: true,
      message: 'Đã mở khóa cho thí sinh tiếp tục làm bài',
      data: attempt
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

const getMySubmissions = async (req, res) => {
  try {
    const studentId = req.user._id;
    const attempts = await ExamAttempt.find({
      student_id: studentId,
      status: { $in: ['SUBMITTED', 'DISQUALIFIED'] }
    })
      .populate({
        path: 'exam_id',
        select: 'exam_title duration_minutes max_violations',
        populate: {
          path: 'subject_id',
          select: 'subject_code subject_name'
        }
      })
      .sort({ submitted_at: -1 })
      .limit(10);

    res.status(200).json({
      success: true,
      data: attempts
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
  getExamViolationLogs,
  getAttemptResult,
  forceSuspendAttempt,
  unlockAttempt,
  getMySubmissions
};
