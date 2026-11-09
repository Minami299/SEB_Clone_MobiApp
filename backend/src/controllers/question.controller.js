const mongoose = require('mongoose');
const { Question, QuestionOption, Chapter, SubjectAccess, Class } = require('../models');

const createQuestion = async (req, res) => {
  try {
    const {
      subject_id,
      chapter_id,
      chapter_num,
      question_code,
      question_type,
      difficulty,
      difficulty_level,
      scope,
      content,
      description,
      learning_outcome,
      default_score,
      is_public,
      options
    } = req.body;

    if (!subject_id || !chapter_id || !content || !question_type) {
      return res.status(400).json({
        success: false,
        message: 'subject_id, chapter_id, content và question_type là bắt buộc'
      });
    }

    if (req.user.role === 'LECTURER') {
      const hasApprovedAccess = await SubjectAccess.exists({
        subject_id,
        lecturer_id: req.user._id,
        status: 'APPROVED'
      });
      const teachesClass = await Class.exists({
        subject_id,
        lecturer_id: req.user._id
      });
      if (!hasApprovedAccess && !teachesClass) {
        return res.status(403).json({
          success: false,
          message: 'Bạn chưa được cấp quyền tạo câu hỏi cho môn học này. Vui lòng gửi yêu cầu đăng ký môn học và chờ Trưởng bộ môn phê duyệt.'
        });
      }
    }

    // Phân định rõ ràng: Giảng viên chỉ tạo câu hỏi vào Kho riêng (PRIVATE),
    // Trưởng bộ môn tạo câu hỏi chuẩn cho Ngân hàng bộ môn (PUBLIC).
    let resolvedScope = 'PUBLIC';
    if (req.user.role === 'LECTURER') {
      resolvedScope = 'PRIVATE';
    } else if (req.user.role === 'HEAD_OF_SUBJECT') {
      resolvedScope = (scope === 'PRIVATE') ? 'PRIVATE' : 'PUBLIC';
    } else if (scope) {
      resolvedScope = scope.toUpperCase() === 'PUBLIC' ? 'PUBLIC' : 'PRIVATE';
    }

    // Xác định chapter_num nếu chưa có
    let resolvedChapterNum = Number(chapter_num);
    if (!resolvedChapterNum || isNaN(resolvedChapterNum)) {
      const ch = await Chapter.findById(chapter_id);
      resolvedChapterNum = ch ? ch.chapter_number : 1;
    }

    const resolvedDifficulty = (difficulty || difficulty_level || 'MEDIUM').toUpperCase();

    const question = await Question.create({
      subject_id,
      chapter_id,
      chapter_num: resolvedChapterNum,
      created_by: req.user._id,
      question_code: question_code || null,
      question_type,
      difficulty: resolvedDifficulty,
      difficulty_level: resolvedDifficulty,
      scope: resolvedScope,
      content,
      description: description || '',
      learning_outcome: learning_outcome || null,
      default_score: default_score !== undefined ? default_score : 1.0,
      is_public: resolvedScope === 'PUBLIC'
    });

    let createdOptions = [];
    if (Array.isArray(options) && options.length > 0) {
      const optionsDocs = options.map((opt) => ({
        question_id: question._id,
        option_content: opt.option_content,
        matching_answer: opt.matching_answer || '',
        is_correct: !!opt.is_correct,
        hint: opt.hint || ''
      }));
      createdOptions = await QuestionOption.insertMany(optionsDocs);
    }

    res.status(201).json({
      success: true,
      message: 'Tạo câu hỏi thành công',
      data: {
        question,
        options: createdOptions
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

const createBatchQuestions = async (req, res) => {
  try {
    const { subject_id, questions } = req.body;

    if (!subject_id || !Array.isArray(questions) || questions.length === 0) {
      return res.status(400).json({
        success: false,
        message: 'Dữ liệu không hợp lệ: subject_id và danh sách câu hỏi là bắt buộc'
      });
    }

    if (req.user.role === 'LECTURER') {
      const hasApprovedAccess = await SubjectAccess.exists({
        subject_id,
        lecturer_id: req.user._id,
        status: 'APPROVED'
      });
      const teachesClass = await Class.exists({
        subject_id,
        lecturer_id: req.user._id
      });
      if (!hasApprovedAccess && !teachesClass) {
        return res.status(403).json({
          success: false,
          message: 'Bạn chưa được cấp quyền tạo câu hỏi cho môn học này.'
        });
      }
    }

    const resolvedScope = req.user.role === 'LECTURER' ? 'PRIVATE' : 'PUBLIC';
    const isPublic = resolvedScope === 'PUBLIC';

    const createdQuestions = [];

    for (const q of questions) {
      if (!q.content || !Array.isArray(q.options) || q.options.length < 2) {
        continue;
      }

      const questionDoc = await Question.create({
        subject_id,
        chapter_id: q.chapter_id || null,
        chapter_num: Number(q.chapter_num) || 1,
        created_by: req.user._id,
        question_code: q.question_code || null,
        question_type: q.question_type || 'SINGLE_CHOICE',
        difficulty_level: (q.difficulty || q.difficulty_level || 'MEDIUM').toUpperCase(),
        scope: resolvedScope,
        is_public: isPublic,
        content: q.content.trim(),
        default_score: Number(q.default_score) || 1.0,
        status: 'ACTIVE'
      });

      const optionDocs = q.options.map((opt) => ({
        question_id: questionDoc._id,
        option_content: (opt.option_content || opt.text || '').trim(),
        is_correct: !!opt.is_correct
      }));

      await QuestionOption.insertMany(optionDocs);
      createdQuestions.push(questionDoc);
    }

    res.status(201).json({
      success: true,
      message: `Đã nhập thành công ${createdQuestions.length} câu hỏi`,
      count: createdQuestions.length
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

const getQuestionsBySubject = async (req, res) => {
  try {
    const { subject_id } = req.params;
    const { scope, chapter, chapter_id, difficulty, difficulty_level } = req.query;

    const filter = { subject_id };
    const userRole = req.user.role;
    const userId = req.user._id;

    if (userRole === 'LECTURER') {
      const hasApprovedAccess = await SubjectAccess.exists({
        subject_id,
        lecturer_id: userId,
        status: 'APPROVED'
      });
      const teachesClass = await Class.exists({
        subject_id,
        lecturer_id: userId
      });
      if (!hasApprovedAccess && !teachesClass) {
        return res.status(403).json({
          success: false,
          message: 'Bạn chưa được cấp quyền truy cập ngân hàng câu hỏi của môn học này. Vui lòng gửi yêu cầu đăng ký môn học và chờ Trưởng bộ môn phê duyệt.'
        });
      }
    }

    // Phân quyền kho câu hỏi (PUBLIC vs PRIVATE)
    if (scope && scope.toUpperCase() === 'PUBLIC') {
      filter.$or = [{ scope: 'PUBLIC' }, { is_public: true }];
    } else if (scope && scope.toUpperCase() === 'PRIVATE') {
      filter.created_by = userId;
      filter.$or = [{ scope: 'PRIVATE' }, { is_public: false }];
    } else {
      // ALL hoặc mặc định: Giảng viên chỉ xem câu Public + câu Private của chính mình
      if (userRole === 'LECTURER') {
        filter.$or = [
          { scope: 'PUBLIC' },
          { is_public: true },
          { created_by: userId }
        ];
      }
    }

    // Lọc theo chương (hỗ trợ cả ObjectId chapter_id hoặc số chương chapter_num)
    if (chapter) {
      if (mongoose.Types.ObjectId.isValid(chapter)) {
        filter.chapter_id = chapter;
      } else {
        filter.chapter_num = Number(chapter);
      }
    } else if (chapter_id) {
      filter.chapter_id = chapter_id;
    }

    // Lọc theo độ khó
    const targetDiff = difficulty || difficulty_level;
    if (targetDiff && targetDiff.toUpperCase() !== 'ALL') {
      const dUpper = targetDiff.toUpperCase();
      const diffCond = {
        $or: [{ difficulty: dUpper }, { difficulty_level: dUpper }]
      };
      if (filter.$and) {
        filter.$and.push(diffCond);
      } else {
        filter.$and = [diffCond];
      }
    }

    const questions = await Question.find(filter)
      .populate('chapter_id', 'chapter_number chapter_title')
      .populate('created_by', 'full_name email')
      .sort({ created_at: -1 });

    res.status(200).json({
      success: true,
      data: questions
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

const getQuestionDetail = async (req, res) => {
  try {
    const { id } = req.params;
    const question = await Question.findById(id)
      .populate('subject_id', 'subject_code subject_name')
      .populate('chapter_id', 'chapter_number chapter_title')
      .populate('created_by', 'full_name email');

    if (!question) {
      return res.status(404).json({
        success: false,
        message: 'Không tìm thấy câu hỏi'
      });
    }

    const options = await QuestionOption.find({ question_id: id });

    res.status(200).json({
      success: true,
      data: {
        question,
        options
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

const getChaptersBySubject = async (req, res) => {
  try {
    const { subject_id } = req.params;
    const chapters = await Chapter.find({ subject_id }).sort({ chapter_number: 1 });
    res.status(200).json({
      success: true,
      data: chapters
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

const deleteQuestion = async (req, res) => {
  try {
    const { id } = req.params;
    const question = await Question.findById(id);
    if (!question) {
      return res.status(404).json({
        success: false,
        message: 'Không tìm thấy câu hỏi'
      });
    }

    if (req.user.role === 'LECTURER' && question.created_by.toString() !== req.user._id.toString()) {
      return res.status(403).json({
        success: false,
        message: 'Bạn chỉ có quyền xóa câu hỏi thuộc Kho riêng của mình'
      });
    }

    await QuestionOption.deleteMany({ question_id: id });
    await Question.findByIdAndDelete(id);
    res.status(200).json({
      success: true,
      message: 'Đã xóa câu hỏi thành công'
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

const updateQuestion = async (req, res) => {
  try {
    const { id } = req.params;
    const {
      chapter_id,
      chapter_num,
      question_code,
      question_type,
      difficulty,
      difficulty_level,
      scope,
      is_public,
      content,
      description,
      default_score,
      options
    } = req.body;

    const question = await Question.findById(id);
    if (!question) {
      return res.status(404).json({
        success: false,
        message: 'Không tìm thấy câu hỏi'
      });
    }

    if (req.user.role === 'LECTURER' && question.created_by.toString() !== req.user._id.toString()) {
      return res.status(403).json({
        success: false,
        message: 'Bạn chỉ có quyền cập nhật câu hỏi thuộc Kho riêng của mình'
      });
    }

    if (chapter_id) {
      question.chapter_id = chapter_id;
      if (!chapter_num) {
        const ch = await Chapter.findById(chapter_id);
        if (ch) question.chapter_num = ch.chapter_number;
      }
    }
    if (chapter_num !== undefined) question.chapter_num = Number(chapter_num);
    if (question_code !== undefined) question.question_code = question_code;
    if (question_type) question.question_type = question_type;
    const diff = difficulty || difficulty_level;
    if (diff) {
      question.difficulty = diff.toUpperCase();
      question.difficulty_level = diff.toUpperCase();
    }
    if (scope) {
      question.scope = scope.toUpperCase();
      question.is_public = scope.toUpperCase() === 'PUBLIC';
    } else if (is_public !== undefined) {
      question.is_public = !!is_public;
      question.scope = is_public ? 'PUBLIC' : 'PRIVATE';
    }
    if (content) question.content = content;
    if (description !== undefined) question.description = description;
    if (default_score !== undefined) question.default_score = Number(default_score);

    await question.save();

    if (Array.isArray(options) && options.length > 0) {
      await QuestionOption.deleteMany({ question_id: id });
      const optionsDocs = options.map((opt) => ({
        question_id: id,
        option_content: opt.option_content,
        is_correct: !!opt.is_correct,
        hint: opt.hint || ''
      }));
      await QuestionOption.insertMany(optionsDocs);
    }

    const updatedOptions = await QuestionOption.find({ question_id: id });

    res.status(200).json({
      success: true,
      message: 'Cập nhật câu hỏi thành công',
      data: {
        question,
        options: updatedOptions
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
  createQuestion,
  createBatchQuestions,
  getQuestionsBySubject,
  getQuestionDetail,
  getChaptersBySubject,
  updateQuestion,
  deleteQuestion
};

