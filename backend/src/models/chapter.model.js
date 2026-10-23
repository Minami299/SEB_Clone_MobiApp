const mongoose = require('mongoose');

const chapterSchema = new mongoose.Schema(
  {
    subject_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Subject',
      required: true
    },
    chapter_number: {
      type: Number,
      required: true
    },
    chapter_title: {
      type: String,
      required: true,
      trim: true,
      maxlength: 200
    }
  },
  {
    timestamps: { createdAt: 'created_at', updatedAt: 'updated_at' }
  }
);

chapterSchema.index({ subject_id: 1, chapter_number: 1 });

module.exports = mongoose.model('Chapter', chapterSchema);

