const mongoose = require('mongoose');

const importBatchSchema = new mongoose.Schema(
  {
    imported_by: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true
    },
    file_name: {
      type: String,
      required: true,
      maxlength: 255
    },
    total_rows: {
      type: Number,
      default: 0
    },
    valid_rows: {
      type: Number,
      default: 0
    },
    duplicate_rows: {
      type: Number,
      default: 0
    },
    error_rows: {
      type: Number,
      default: 0
    },
    error_details: [
      {
        _id: false,
        row: Number,
        message: String
      }
    ],
    status: {
      type: String,
      maxlength: 20,
      default: 'PREVIEW'
    }
  },
  {
    timestamps: { createdAt: 'created_at', updatedAt: 'updated_at' }
  }
);

module.exports = mongoose.model('ImportBatch', importBatchSchema);
