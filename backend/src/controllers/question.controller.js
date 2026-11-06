const { Question, QuestionOption, Chapter } = require('../models');

const createQuestion = async (req, res) => {
  try {
    const {
      subject_id,
      chapter_id,
      question_code,
      question_type,
      difficulty_level,
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

    const question = await Question.create({
      subject_id,
      chapter_id,
      created_by: req.user._id,
      question_code: question_code || null,
      question_type,
      difficulty_level: difficulty_level || 'MEDIUM',
      content,
      description: description || '',
      learning_outcome: learning_outcome || null,
      default_score: default_score !== undefined ? default_score : 1.0,
      is_public: req.user.role === 'HEAD_OF_SUBJECT' ? true : !!is_public
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

const getQuestionsBySubject = async (req, res) => {
  try {
    const { subject_id } = req.params;
    const { chapter_id, difficulty_level } = req.query;

    const filter = { subject_id };

    // Sinh viên không được gọi API này
    if (req.user.role === 'LECTURER') {
      filter.$or = [{ is_public: true }, { created_by: req.user._id }];
    }

    if (chapter_id) filter.chapter_id = chapter_id;
    if (difficulty_level) filter.difficulty_level = difficulty_level;

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

module.exports = {
  createQuestion,
  getQuestionsBySubject,
  getQuestionDetail
};

