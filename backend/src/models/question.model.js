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
    question_code: {
      type: String,
      trim: true,
      maxlength: 20,
      default: null
    },
    question_type: {
      type: String,
      required: true,
      maxlength: 20
    },
    difficulty_level: {
      type: String,
      maxlength: 10,
      default: 'MEDIUM'
    },
    difficulty: {
      type: String,
      enum: ['EASY', 'MEDIUM', 'HARD'],
      default: 'MEDIUM'
    },
    chapter_num: {
      type: Number,
      default: 1
    },
    scope: {
      type: String,
      enum: ['PUBLIC', 'PRIVATE'],
      default: 'PUBLIC'
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
      default: true
    }
  },
  {
    timestamps: { createdAt: 'created_at', updatedAt: 'updated_at' }
  }
);

questionSchema.pre('save', function (next) {
  if (this.difficulty && !this.difficulty_level) {
    this.difficulty_level = this.difficulty;
  } else if (this.difficulty_level && !this.difficulty) {
    this.difficulty = this.difficulty_level;
  }
  if (this.scope === 'PUBLIC') {
    this.is_public = true;
  } else if (this.scope === 'PRIVATE') {
    this.is_public = false;
  }
  next();
});

questionSchema.index({ subject_id: 1, chapter_id: 1, scope: 1 });

module.exports = mongoose.model('Question', questionSchema);

