const mongoose = require('mongoose');

const examEligibilitySchema = new mongoose.Schema(
  {
    exam_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Exam',
      required: true
    },
    student_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true
    },
    is_banned: {
      type: Boolean,
      default: false
    }
  },
  {
    timestamps: { createdAt: 'created_at', updatedAt: 'updated_at' }
  }
);

examEligibilitySchema.index({ exam_id: 1, student_id: 1 }, { unique: true });

module.exports = mongoose.model('ExamEligibility', examEligibilitySchema);

