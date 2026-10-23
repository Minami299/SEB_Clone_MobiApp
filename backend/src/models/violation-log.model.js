const mongoose = require('mongoose');

const violationLogSchema = new mongoose.Schema({
  attempt_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'ExamAttempt',
    required: true
  },
  violation_type: {
    type: String,
    required: true,
    maxlength: 50
  },
  violation_details: {
    type: String,
    maxlength: 255,
    default: ''
  },
  detected_at: {
    type: Date,
    default: Date.now
  }
});

violationLogSchema.index({ attempt_id: 1 });

module.exports = mongoose.model('ViolationLog', violationLogSchema);

