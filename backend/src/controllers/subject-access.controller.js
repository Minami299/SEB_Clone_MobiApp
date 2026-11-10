const { SubjectAccess, Subject, Notification, User, Class } = require('../models');

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

const getSubjectAccessRecords = async (req, res) => {
  try {
    const { id } = req.params;
    if (!await canManageSubject(req.user, id)) {
      return res.status(403).json({ success: false, message: 'Bạn không phụ trách môn học này' });
    }
    const records = await SubjectAccess.find({ subject_id: id })
      .populate('lecturer_id', 'full_name email user_code status department_id')
      .populate('approved_by', 'full_name user_code')
      .sort({ updated_at: -1 });
    res.status(200).json({ success: true, data: records });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

const getGrantableLecturers = async (req, res) => {
  try {
    if (req.user.role !== 'ADMIN' && !req.user.department_id) {
      return res.status(403).json({ success: false, message: 'Tài khoản chưa được gán khoa' });
    }
    const filter = { role: 'LECTURER', status: 'ACTIVE' };
    if (req.user.role !== 'ADMIN') filter.department_id = req.user.department_id;
    const lecturers = await User.find(filter)
      .select('full_name email user_code department_id')
      .populate('department_id', 'department_name department_code')
      .sort({ full_name: 1 });
    res.status(200).json({ success: true, data: lecturers });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

const grantLecturerAccess = async (req, res) => {
  try {
    const { id } = req.params;
    const { lecturer_id, grant_type = 'INVITATION' } = req.body;
    if (!lecturer_id) return res.status(400).json({ success: false, message: 'Giảng viên là bắt buộc' });
    if (grant_type !== 'INVITATION') {
      return res.status(400).json({ success: false, message: 'Loại quyền không hợp lệ' });
    }
    if (!await canManageSubject(req.user, id)) {
      return res.status(403).json({ success: false, message: 'Bạn không phụ trách môn học này' });
    }
    const lecturer = await User.findOne({ _id: lecturer_id, role: 'LECTURER', status: 'ACTIVE' });
    if (!lecturer) return res.status(404).json({ success: false, message: 'Không tìm thấy giảng viên đang hoạt động' });
    if (req.user.role !== 'ADMIN' && lecturer.department_id?.toString() !== req.user.department_id.toString()) {
      return res.status(403).json({ success: false, message: 'Chỉ có thể cấp quyền cho giảng viên trong khoa phụ trách' });
    }

    const existing = await SubjectAccess.findOne({ subject_id: id, lecturer_id }).sort({ updated_at: -1 });
    if (existing?.status === 'APPROVED') {
      return res.status(409).json({ success: false, message: 'Giảng viên đã có quyền với môn học này' });
    }
    if (existing) {
      existing.status = 'APPROVED';
      existing.grant_type = grant_type;
      existing.approved_by = req.user._id;
      await existing.save();
      await existing.populate('lecturer_id', 'full_name email user_code status');
      return res.status(200).json({ success: true, message: 'Đã cấp lại quyền cho giảng viên', data: existing });
    }

    const access = await SubjectAccess.create({
      subject_id: id,
      lecturer_id,
      grant_type,
      status: 'APPROVED',
      approved_by: req.user._id
    });
    await access.populate('lecturer_id', 'full_name email user_code status');
    res.status(201).json({ success: true, message: 'Đã cấp quyền cho giảng viên', data: access });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

const revokeLecturerAccess = async (req, res) => {
  try {
    const { id, accessId } = req.params;
    if (!await canManageSubject(req.user, id)) {
      return res.status(403).json({ success: false, message: 'Bạn không phụ trách môn học này' });
    }
    const access = await SubjectAccess.findOne({ _id: accessId, subject_id: id });
    if (!access) return res.status(404).json({ success: false, message: 'Không tìm thấy quyền truy cập' });
    if (access.status !== 'APPROVED') {
      return res.status(409).json({ success: false, message: 'Quyền này hiện không ở trạng thái đã cấp' });
    }
    access.status = 'REVOKED';
    access.approved_by = req.user._id;
    await access.save();
    res.status(200).json({ success: true, message: 'Đã thu hồi quyền truy cập' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
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

    const existingApproved = await SubjectAccess.exists({
      subject_id,
      lecturer_id,
      status: 'APPROVED'
    });
    if (existingApproved) {
      return res.status(409).json({ success: false, message: 'Bạn đã được cấp quyền cho môn học này' });
    }

    if (existingPending) {
      return res.status(400).json({
        success: false,
        message: 'Bạn đã có một yêu cầu đang chờ phê duyệt cho môn học này'
      });
    }

    const newRequest = await SubjectAccess.create({
      subject_id,
      lecturer_id,
      grant_type: grant_type || 'REQUEST',
      status: 'PENDING'
    });

    // Tạo thông báo gửi tới Trưởng bộ môn phụ trách và Admin
    try {
      const targetQuery = {
        $or: [
          { role: 'ADMIN' }
        ]
      };
      if (subject.department_id) {
        targetQuery.$or.push({
          role: 'HEAD_OF_SUBJECT',
          department_id: subject.department_id
        });
      } else {
        targetQuery.$or.push({ role: 'HEAD_OF_SUBJECT' });
      }

      const heads = await User.find(targetQuery).select('_id');
      const notifs = heads.map((h) => ({
        recipient_id: h._id,
        sender_id: lecturer_id,
        title: 'Yêu cầu đăng ký giảng dạy mới',
        message: `Giảng viên ${req.user.full_name || req.user.email} đã gửi yêu cầu đăng ký giảng dạy môn ${subject.subject_code} - ${subject.subject_name}.`,
        type: 'SUBJECT_ACCESS_REQUEST',
        reference_id: newRequest._id,
        data: {
          subject_id: subject._id,
          subject_code: subject.subject_code,
          subject_name: subject.subject_name,
          grant_type: newRequest.grant_type
        }
      }));

      if (notifs.length > 0) {
        await Notification.insertMany(notifs);
      }
    } catch (notifErr) {
      console.error('Lỗi tạo thông báo cho Trưởng bộ môn:', notifErr.message);
    }

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

    const request = await SubjectAccess.findById(id);

    if (!request) {
      return res.status(404).json({
        success: false,
        message: 'Không tìm thấy yêu cầu'
      });
    }

    if (request.status !== 'PENDING') {
      return res.status(409).json({ success: false, message: 'Yêu cầu này đã được xử lý' });
    }

    const subject = await Subject.findById(request.subject_id);

    if (req.user.role !== 'ADMIN' && (!req.user.department_id ||
        subject?.department_id?.toString() !== req.user.department_id.toString())) {
      return res.status(403).json({ success: false, message: 'Bạn không phụ trách môn học của yêu cầu này' });
    }

    request.status = status;
    request.approved_by = req.user._id;
    const updated = await request.save();

    // Tạo thông báo phản hồi gửi về cho Giảng viên
    try {
      const isApproved = status === 'APPROVED';
      const subCode = subject?.subject_code || 'môn học';
      const subName = subject?.subject_name || '';

      await Notification.create({
        recipient_id: request.lecturer_id,
        sender_id: req.user._id,
        title: isApproved ? 'Đã phê duyệt đăng ký giảng dạy' : 'Yêu cầu giảng dạy bị từ chối',
        message: isApproved
          ? `Trưởng bộ môn đã phê duyệt yêu cầu giảng dạy môn ${subCode} (${subName}) của bạn. Bạn đã có thể truy cập Ngân hàng câu hỏi.`
          : `Yêu cầu đăng ký giảng dạy môn ${subCode} (${subName}) của bạn đã bị từ chối.`,
        type: 'SUBJECT_ACCESS_REVIEW',
        reference_id: request._id,
        data: {
          subject_id: request.subject_id,
          subject_code: subCode,
          subject_name: subName,
          status
        }
      });
    } catch (notifErr) {
      console.error('Lỗi tạo thông báo cho Giảng viên:', notifErr.message);
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
    const { status, only_authorized, only_approved } = req.query;
    const filter = getSubjectScope(req.user);
    if (status) {
      filter.status = status;
    } else if (req.user && (req.user.role === 'LECTURER' || req.user.role === 'STUDENT')) {
      filter.status = 'ACTIVE';
    }

    // Nếu lọc theo quyền giảng dạy (dành cho màn tạo ca thi / chọn môn)
    if (req.user && req.user.role === 'LECTURER' && (only_authorized === 'true' || only_approved === 'true')) {
      const approvedAccess = await SubjectAccess.find({
        lecturer_id: req.user._id,
        status: 'APPROVED'
      }).select('subject_id');
      const approvedSubjectIds = approvedAccess.map((a) => a.subject_id.toString());

      const taughtClasses = await Class.find({
        lecturer_id: req.user._id
      }).select('subject_id');
      const taughtSubjectIds = taughtClasses.map((c) => c.subject_id.toString());

      const allowedIds = [...new Set([...approvedSubjectIds, ...taughtSubjectIds])];
      filter._id = { $in: allowedIds };
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
  updateSubjectStatus,
  getSubjectAccessRecords,
  getGrantableLecturers,
  grantLecturerAccess,
  revokeLecturerAccess
};

