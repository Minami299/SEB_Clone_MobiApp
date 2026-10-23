const mongoose = require('mongoose');

const examQuestionSchema = new mongoose.Schema(
  {
    exam_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Exam',
      required: true
    },
    question_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Question',
      required: true
    }
  },
  {
    timestamps: { createdAt: 'created_at', updatedAt: 'updated_at' }
  }
);

examQuestionSchema.index({ exam_id: 1, question_id: 1 }, { unique: true });

module.exports = mongoose.model('ExamQuestion', examQuestionSchema);

