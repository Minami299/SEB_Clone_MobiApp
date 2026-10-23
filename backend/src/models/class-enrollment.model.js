const mongoose = require('mongoose');

const classEnrollmentSchema = new mongoose.Schema(
  {
    class_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Class',
      required: true
    },
    student_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true
    }
  },
  {
    timestamps: { createdAt: 'created_at', updatedAt: 'updated_at' }
  }
);

classEnrollmentSchema.index({ class_id: 1, student_id: 1 }, { unique: true });

module.exports = mongoose.model('ClassEnrollment', classEnrollmentSchema);

