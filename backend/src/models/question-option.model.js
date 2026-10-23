const mongoose = require('mongoose');

const questionOptionSchema = new mongoose.Schema(
  {
    question_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Question',
      required: true
    },
    option_content: {
      type: String,
      required: true
    },
    matching_answer: {
      type: String,
      default: null
    },
    is_correct: {
      type: Boolean,
      default: false
    },
    hint: {
      type: String,
      default: null
    }
  },
  {
    timestamps: { createdAt: 'created_at', updatedAt: 'updated_at' }
  }
);

questionOptionSchema.index({ question_id: 1 });

module.exports = mongoose.model('QuestionOption', questionOptionSchema);

