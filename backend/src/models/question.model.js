const mongoose = require('mongoose');

const questionSchema = new mongoose.Schema(
  {
    subject_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Subject',
      required: true
    },
    chapter_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Chapter',
      required: true
    },
    created_by: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true
    },
    question_type: {
      type: String,
      required: true,
      maxlength: 20
    },
    content: {
      type: String,
      required: true
    },
    description: {
      type: String,
      default: ''
    },
    learning_outcome: {
      type: String,
      maxlength: 50,
      default: null
    },
    default_score: {
      type: Number,
      default: 1.0
    },
    is_public: {
      type: Boolean,
      default: false
    }
  },
  {
    timestamps: { createdAt: 'created_at', updatedAt: 'updated_at' }
  }
);

questionSchema.index({ subject_id: 1, chapter_id: 1 });

module.exports = mongoose.model('Question', questionSchema);

