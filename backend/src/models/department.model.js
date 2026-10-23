const mongoose = require('mongoose');

const departmentSchema = new mongoose.Schema(
  {
    department_code: {
      type: String,
      required: true,
      unique: true,
      trim: true,
      maxlength: 20
    },
    department_name: {
      type: String,
      required: true,
      trim: true,
      maxlength: 100
    }
  },
  {
    timestamps: { createdAt: 'created_at', updatedAt: 'updated_at' }
  }
);

module.exports = mongoose.model('Department', departmentSchema);

