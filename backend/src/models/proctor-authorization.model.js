const mongoose = require('mongoose');

const proctorAuthorizationSchema = new mongoose.Schema(
  {
    attempt_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'ExamAttempt',
      required: true
    },
    proctor_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true
    },
    reason: {
      type: String,
      required: true,
      maxlength: 30
    },
    auth_method: {
      type: String,
      required: true,
      maxlength: 10
    },
    action: {
      type: String,
      required: true,
      maxlength: 20
    },
    notes: {
      type: String,
      default: ''
    },
    authorized_at: {
      type: Date,
      default: Date.now
    }
  },
  {
    timestamps: { createdAt: 'created_at', updatedAt: 'updated_at' }
  }
);

proctorAuthorizationSchema.index({ attempt_id: 1 });

module.exports = mongoose.model('ProctorAuthorization', proctorAuthorizationSchema);
