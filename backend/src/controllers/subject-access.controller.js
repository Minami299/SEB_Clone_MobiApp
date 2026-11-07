const { SubjectAccess, Subject } = require('../models');

const requestAccess = async (req, res) => {
  try {
    const { subject_id, grant_type } = req.body;
    const lecturer_id = req.user._id;

    if (!subject_id) {
      return res.status(400).json({
        success: false,
        message: 'Môn học (subject_id) là bắt buộc'
      });
    }

    const subject = await Subject.findById(subject_id);
    if (!subject) {
      return res.status(404).json({
        success: false,
        message: 'Môn học không tồn tại'
      });
    }

    const existingPending = await SubjectAccess.findOne({
      subject_id,
      lecturer_id,
      status: 'PENDING'
    });

    if (existingPending) {
      return res.status(400).json({
        success: false,
        message: 'Bạn đã có một yêu cầu đang chờ phê duyệt cho môn học này'
      });
    }

    const newRequest = await SubjectAccess.create({
      subject_id,
      lecturer_id,
      grant_type: grant_type || 'QUESTION_CONTRIBUTION',
      status: 'PENDING'
    });

    res.status(201).json({
      success: true,
      message: 'Gửi yêu cầu truy cập thành công',
      data: newRequest
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

const getMyRequests = async (req, res) => {
  try {
    const requests = await SubjectAccess.find({ lecturer_id: req.user._id })
      .populate('subject_id', 'subject_code subject_name description')
      .populate('approved_by', 'full_name email user_code')
      .sort({ created_at: -1 });

    res.status(200).json({
      success: true,
      data: requests
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

const getPendingRequests = async (req, res) => {
  try {
    const requests = await SubjectAccess.find({ status: 'PENDING' })
      .populate('subject_id', 'subject_code subject_name')
      .populate('lecturer_id', 'full_name email user_code')
      .sort({ created_at: -1 });

    res.status(200).json({
      success: true,
      data: requests
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

const reviewRequest = async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body;

    if (!['APPROVED', 'REJECTED'].includes(status)) {
      return res.status(400).json({
        success: false,
        message: 'Trạng thái xét duyệt phải là APPROVED hoặc REJECTED'
      });
    }

    const updated = await SubjectAccess.findByIdAndUpdate(
      id,
      {
        status,
        approved_by: req.user._id
      },
      { new: true }
    );

    if (!updated) {
      return res.status(404).json({
        success: false,
        message: 'Không tìm thấy yêu cầu'
      });
    }

    res.status(200).json({
      success: true,
      message: `Đã ${status === 'APPROVED' ? 'phê duyệt' : 'từ chối'} yêu cầu`,
      data: updated
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

const getAllSubjects = async (req, res) => {
  try {
    const { status } = req.query;
    const filter = {};
    if (status) {
      filter.status = status;
    } else if (req.user && (req.user.role === 'LECTURER' || req.user.role === 'STUDENT')) {
      filter.status = 'ACTIVE';
    }

    const subjects = await Subject.find(filter)
      .populate('department_id', 'department_code department_name')
      .populate('created_by', 'full_name email')
      .sort({ subject_code: 1 });

    res.status(200).json({
      success: true,
      data: subjects
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

const updateSubjectStatus = async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body;

    if (!['ACTIVE', 'INACTIVE'].includes(status)) {
      return res.status(400).json({
        success: false,
        message: 'Trạng thái môn học không hợp lệ (phải là ACTIVE hoặc INACTIVE)'
      });
    }

    const updated = await Subject.findByIdAndUpdate(
      id,
      { status },
      { new: true }
    )
      .populate('department_id', 'department_code department_name')
      .populate('created_by', 'full_name email');

    if (!updated) {
      return res.status(404).json({
        success: false,
        message: 'Không tìm thấy môn học'
      });
    }

    res.status(200).json({
      success: true,
      message: `Đã cập nhật trạng thái môn học thành ${status}`,
      data: updated
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

module.exports = {
  requestAccess,
  getMyRequests,
  getPendingRequests,
  reviewRequest,
  getAllSubjects,
  updateSubjectStatus
};

