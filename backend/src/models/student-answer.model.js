const mongoose = require('mongoose');

const studentAnswerSchema = new mongoose.Schema(
  {
    attempt_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'ExamAttempt',
      required: true
    },
    question_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Question',
      required: true
    },
    selected_option_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'QuestionOption',
      default: null
    },
    answer_text: {
      type: String,
      default: null
    },
    score_awarded: {
      type: Number,
      default: 0
    }
  },
  {
    timestamps: { createdAt: 'created_at', updatedAt: 'updated_at' }
  }
);

studentAnswerSchema.index({ attempt_id: 1, question_id: 1 });

module.exports = mongoose.model('StudentAnswer', studentAnswerSchema);

