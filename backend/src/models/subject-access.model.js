const mongoose = require('mongoose');

const subjectAccessSchema = new mongoose.Schema(
  {
    subject_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Subject',
      required: true
    },
    lecturer_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true
    },
    grant_type: {
      type: String,
      required: true,
      maxlength: 30
    },
    status: {
      type: String,
      maxlength: 20,
      default: 'PENDING'
    },
    approved_by: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      default: null
    }
  },
  {
    timestamps: { createdAt: 'created_at', updatedAt: 'updated_at' }
  }
);

subjectAccessSchema.index({ subject_id: 1, lecturer_id: 1 });

module.exports = mongoose.model('SubjectAccess', subjectAccessSchema);

