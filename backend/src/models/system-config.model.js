const mongoose = require('mongoose');

const systemConfigSchema = new mongoose.Schema(
  {
    config_key: {
      type: String,
      required: true,
      unique: true,
      trim: true,
      maxlength: 50
    },
    config_value: {
      type: String,
      required: true,
      maxlength: 255
    },
    description: {
      type: String,
      default: ''
    },
    updated_by: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      default: null
    }
  },
  {
    timestamps: { createdAt: false, updatedAt: 'updated_at' }
  }
);

module.exports = mongoose.model('SystemConfig', systemConfigSchema);

