const { SubjectAccess, Subject } = require('../models');

const getSubjectScope = (user) => user.role === 'ADMIN'
  ? {}
  : { department_id: user.department_id };

const canManageSubject = async (user, subjectId) => {
  if (user.role === 'ADMIN') return true;
  if (!user.department_id) return false;
  return !!(await Subject.exists({
    _id: subjectId,
    department_id: user.department_id
  }));
};

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
    const subjectIds = req.user.role === 'ADMIN'
      ? null
      : (req.user.department_id
        ? (await Subject.find({ department_id: req.user.department_id }).select('_id')).map((s) => s._id)
        : []);
    const filter = { status: 'PENDING' };
    if (subjectIds) filter.subject_id = { $in: subjectIds };
    const requests = await SubjectAccess.find(filter)
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

    const request = await SubjectAccess.findById(id).populate('subject_id', 'department_id');

    if (!request) {
      return res.status(404).json({
        success: false,
        message: 'Không tìm thấy yêu cầu'
      });
    }

    if (request.status !== 'PENDING') {
      return res.status(409).json({ success: false, message: 'Yêu cầu này đã được xử lý' });
    }
    if (req.user.role !== 'ADMIN' && (!req.user.department_id ||
        request.subject_id?.department_id?.toString() !== req.user.department_id.toString())) {
      return res.status(403).json({ success: false, message: 'Bạn không phụ trách môn học của yêu cầu này' });
    }

    request.status = status;
    request.approved_by = req.user._id;
    const updated = await request.save();

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
    const filter = getSubjectScope(req.user);
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

    if (!await canManageSubject(req.user, id)) {
      return res.status(403).json({ success: false, message: 'Bạn không phụ trách môn học này' });
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

