const mongoose = require('mongoose');

const examAttemptSchema = new mongoose.Schema(
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
    started_at: {
      type: Date,
      default: Date.now
    },
    submitted_at: {
      type: Date,
      default: null
    },
    total_score: {
      type: Number,
      default: 0
    },
    is_passed: {
      type: Boolean,
      default: false
    },
    status: {
      type: String,
      maxlength: 20,
      default: 'IN_PROGRESS'
    }
  },
  {
    timestamps: { createdAt: 'created_at', updatedAt: 'updated_at' }
  }
);

examAttemptSchema.index({ exam_id: 1, student_id: 1 });

module.exports = mongoose.model('ExamAttempt', examAttemptSchema);

