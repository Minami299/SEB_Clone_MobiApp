const mongoose = require('mongoose');

const userSchema = new mongoose.Schema(
  {
    user_code: {
      type: String,
      required: true,
      unique: true,
      trim: true,
      maxlength: 20
    },
    email: {
      type: String,
      required: true,
      unique: true,
      trim: true,
      lowercase: true,
      maxlength: 100
    },
    password_hash: {
      type: String,
      required: true
    },
    full_name: {
      type: String,
      required: true,
      trim: true,
      maxlength: 100
    },
    role: {
      type: String,
      required: true,
      maxlength: 20,
      default: 'STUDENT'
    },
    department_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Department',
      default: null
    },
    status: {
      type: String,
      maxlength: 20,
      default: 'ACTIVE'
    }
  },
  {
    timestamps: { createdAt: 'created_at', updatedAt: 'updated_at' }
  }
);

module.exports = mongoose.model('User', userSchema);

