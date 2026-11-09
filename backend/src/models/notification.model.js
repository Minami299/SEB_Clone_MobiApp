const mongoose = require('mongoose');

const notificationSchema = new mongoose.Schema({
  recipient_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true
  },
  sender_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User'
  },
  title: {
    type: String,
    required: true
  },
  message: {
    type: String,
    required: true
  },
  type: {
    type: String,
    enum: ['SUBJECT_ACCESS_REQUEST', 'SUBJECT_ACCESS_REVIEW', 'EXAM_ALERT', 'GENERAL'],
    default: 'GENERAL'
  },
  reference_id: {
    type: mongoose.Schema.Types.ObjectId
  },
  data: {
    type: mongoose.Schema.Types.Mixed
  },
  is_read: {
    type: Boolean,
    default: false
  },
  created_at: {
    type: Date,
    default: Date.now
  }
});

notificationSchema.index({ recipient_id: 1, created_at: -1 });

module.exports = mongoose.model('Notification', notificationSchema);

