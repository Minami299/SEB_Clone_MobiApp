const mongoose = require('mongoose');

const systemLogSchema = new mongoose.Schema({
  user_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  action: {
    type: String,
    required: true,
    maxlength: 255
  },
  created_at: {
    type: Date,
    default: Date.now
  }
});

module.exports = mongoose.model('SystemLog', systemLogSchema);

