const mongoose = require('mongoose');

const examChapterRuleSchema = new mongoose.Schema(
  {
    exam_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Exam',
      required: true
    },
    chapter_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Chapter',
      required: true
    },
    question_type: {
      type: String,
      required: true,
      maxlength: 20
    },
    difficulty_level: {
      type: String,
      maxlength: 10,
      default: null
    },
    question_count: {
      type: Number,
      required: true,
      min: 0
    }
  },
  {
    timestamps: { createdAt: 'created_at', updatedAt: 'updated_at' }
  }
);

examChapterRuleSchema.index({ exam_id: 1, chapter_id: 1 });

module.exports = mongoose.model('ExamChapterRule', examChapterRuleSchema);

