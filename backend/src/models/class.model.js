const mongoose = require('mongoose');

const classSchema = new mongoose.Schema(
  {
    class_code: {
      type: String,
      required: true,
      unique: true,
      trim: true,
      maxlength: 30
    },
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
    semester: {
      type: String,
      required: true,
      trim: true,
      maxlength: 20
    }
  },
  {
    timestamps: { createdAt: 'created_at', updatedAt: 'updated_at' }
  }
);

module.exports = mongoose.model('Class', classSchema);

