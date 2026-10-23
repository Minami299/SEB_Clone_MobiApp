const mongoose = require('mongoose');

const examSchema = new mongoose.Schema(
  {
    subject_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Subject',
      required: true
    },
    class_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Class',
      default: null
    },
    created_by: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true
    },
    exam_title: {
      type: String,
      required: true,
      trim: true,
      maxlength: 200
    },
    description: {
      type: String,
      default: ''
    },
    importance_level: {
      type: Number,
      default: 1
    },
    start_time: {
      type: Date,
      required: true
    },
    end_time: {
      type: Date,
      required: true
    },
    duration_minutes: {
      type: Number,
      required: true
    },
    mcq_grading_method: {
      type: String,
      maxlength: 50,
      default: null
    },
    min_pass_percentage: {
      type: Number,
      default: 0
    },
    question_source_mode: {
      type: String,
      maxlength: 30,
      default: null
    },
    mcq_weight_percent: {
      type: Number,
      default: 0
    },
    essay_weight_percent: {
      type: Number,
      default: 0
    },
    status: {
      type: String,
      maxlength: 20,
      default: 'DRAFT'
    }
  },
  {
    timestamps: { createdAt: 'created_at', updatedAt: 'updated_at' }
  }
);

examSchema.index({ subject_id: 1, class_id: 1 });

module.exports = mongoose.model('Exam', examSchema);

