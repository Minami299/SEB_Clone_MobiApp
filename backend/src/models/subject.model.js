const mongoose = require('mongoose');

const subjectSchema = new mongoose.Schema(
  {
    subject_code: {
      type: String,
      required: true,
      unique: true,
      trim: true,
      maxlength: 20
    },
    subject_name: {
      type: String,
      required: true,
      trim: true,
      maxlength: 150
    },
    description: {
      type: String,
      default: ''
    },
    allow_auto_grading: {
      type: Boolean,
      default: false
    },
    status: {
      type: String,
      maxlength: 20,
      default: 'ACTIVE'
    },
    department_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Department',
      required: true
    },
    created_by: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true
    }
  },
  {
    timestamps: { createdAt: 'created_at', updatedAt: 'updated_at' }
  }
);

module.exports = mongoose.model('Subject', subjectSchema);

