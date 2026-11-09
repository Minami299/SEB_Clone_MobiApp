const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const nodemailer = require('nodemailer');
const config = require('../config');
const { User } = require('../models');

const generateOtp = () => {
  return Math.floor(100000 + Math.random() * 900000).toString();
};

const maskEmail = (email) => {
  if (!email || !email.includes('@')) return email;
  const [name, domain] = email.split('@');
  if (name.length <= 2) return `${name[0]}***@${domain}`;
  return `${name.slice(0, 2)}***${name.slice(-1)}@${domain}`;
};

const sendOtpEmail = async (email, otp, purpose = 'xác thực tài khoản') => {
  const host = process.env.SMTP_HOST || 'smtp.gmail.com';
  const port = process.env.SMTP_PORT || 587;
  const user = process.env.SMTP_USER || process.env.EMAIL_USER;
  const rawPass = process.env.SMTP_PASS || process.env.EMAIL_PASS;
  const pass = rawPass ? rawPass.replace(/[<>]/g, '').trim() : '';
  const fromEmail = process.env.SMTP_FROM || process.env.EMAIL_FROM || (user && user.includes('@') ? user : 'no-reply@seb-security.com');

  console.log(`[AUTH-OTP] Mã OTP cho ${email} (${purpose}) là: ${otp}`);

  if (user && pass) {
    try {
      const transporter = nodemailer.createTransport({
        host,
        port: Number(port),
        secure: Number(port) === 465,
        auth: { user, pass }
      });

      const info = await transporter.sendMail({
        from: `"SEB Exam Security" <${fromEmail}>`,
        to: email,
        subject: `[SEB Clone] Mã OTP ${purpose.toUpperCase()}`,
        html: `
          <div style="font-family: Arial, sans-serif; padding: 24px; color: #1e293b; max-width: 500px; margin: 0 auto; border: 1px solid #e2e8f0; border-radius: 12px; background-color: #ffffff;">
            <h2 style="color: #0062FF; text-align: center; margin-bottom: 8px;">Safe Exam Browser</h2>
            <p style="font-size: 14px; text-align: center; color: #64748b; margin-top: 0;">Hệ thống kiểm tra & khảo thí an toàn</p>
            <hr style="border: none; border-top: 1px solid #f1f5f9; margin: 16px 0;" />
            <p style="font-size: 14px;">Xin chào,</p>
            <p style="font-size: 14px; line-height: 1.5;">Bạn đã yêu cầu <strong>${purpose}</strong> trên ứng dụng SEB Clone Mobile. Dưới đây là mã xác thực OTP của bạn:</p>
            <div style="text-align: center; margin: 28px 0;">
              <span style="font-size: 32px; font-weight: bold; letter-spacing: 8px; color: #0062FF; background: #eff6ff; padding: 14px 28px; border-radius: 10px; border: 1px dashed #bfdbfe; display: inline-block;">
                ${otp}
              </span>
            </div>
            <p style="font-size: 13px; color: #ef4444; text-align: center; margin-bottom: 4px;">Mã OTP có hiệu lực trong vòng <strong>5 phút</strong>.</p>
            <p style="font-size: 12px; color: #94a3b8; text-align: center;">Vì lý do an toàn, tuyệt đối không chia sẻ mã này cho bất kỳ ai khác.</p>
            <hr style="border: none; border-top: 1px solid #f1f5f9; margin: 20px 0;" />
            <p style="font-size: 11px; color: #94a3b8; text-align: center;">Đây là email tự động từ máy chủ SEB. Vui lòng không trả lời thư này.</p>
          </div>
        `
      });
      console.log(`[AUTH-OTP-SUCCESS] Email OTP đã gửi thành công tới ${email}:`, info.response);
      return { sent: true };
    } catch (err) {
      console.error('[AUTH-OTP-ERROR] Gửi email qua SMTP thất bại:', err.message);
      return { sent: false, error: err.message };
    }
  }

  return { sent: false, note: 'Chưa cấu hình SMTP_USER / EMAIL_USER trong .env. OTP đã được log ra console server.' };
};

const login = async (req, res) => {
  try {
    const { identifier, password } = req.body;
    if (!identifier || !password) {
      return res.status(400).json({
        success: false,
        message: 'Vui lòng cung cấp mã người dùng/email và mật khẩu'
      });
    }

    const trimmedIdentifier = identifier.trim();
    const user = await User.findOne({
      $or: [
        { email: trimmedIdentifier.toLowerCase() },
        { user_code: trimmedIdentifier }
      ]
    });

    if (!user) {
      return res.status(401).json({
        success: false,
        message: 'Thông tin đăng nhập không chính xác'
      });
    }

    const isMatch = await bcrypt.compare(password, user.password_hash);
    if (!isMatch) {
      return res.status(401).json({
        success: false,
        message: 'Thông tin đăng nhập không chính xác'
      });
    }

    if (user.status !== 'ACTIVE') {
      return res.status(403).json({
        success: false,
        message: 'Tài khoản đang bị tạm khóa'
      });
    }

    const token = jwt.sign(
      {
        id: user._id,
        user_code: user.user_code,
        role: user.role
      },
      config.jwt.secret,
      { expiresIn: config.jwt.expiresIn }
    );

    res.status(200).json({
      success: true,
      message: 'Đăng nhập thành công',
      data: {
        token,
        user: {
          id: user._id,
          user_code: user.user_code,
          full_name: user.full_name,
          email: user.email,
          role: user.role,
          department_id: user.department_id,
          status: user.status
        }
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

const getMe = async (req, res) => {
  try {
    const user = await User.findById(req.user._id)
      .select('-password_hash')
      .populate('department_id', 'department_code department_name');

    res.status(200).json({
      success: true,
      data: user
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

const updateProfile = async (req, res) => {
  try {
    const { full_name, email, current_password, new_password, password, otp } = req.body;
    const user = await User.findById(req.user._id);

    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'Người dùng không tồn tại'
      });
    }

    if (full_name && full_name.trim()) {
      user.full_name = full_name.trim();
    }

    if (email && email.trim().toLowerCase() !== user.email) {
      const emailExists = await User.findOne({
        email: email.trim().toLowerCase(),
        _id: { $ne: user._id }
      });
      if (emailExists) {
        return res.status(400).json({
          success: false,
          message: 'Email này đã được sử dụng bởi tài khoản khác'
        });
      }
      user.email = email.trim().toLowerCase();
    }

    const targetNewPassword = new_password || password;
    if (targetNewPassword && targetNewPassword.trim().length > 0) {
      if (otp) {
        // Xác thực qua OTP gửi về mail
        if (!user.otp_code || !user.otp_expires_at) {
          return res.status(400).json({
            success: false,
            message: 'Vui lòng nhấn "Gửi mã OTP" về email trước khi xác nhận đổi mật khẩu'
          });
        }
        if (Date.now() > new Date(user.otp_expires_at).getTime()) {
          return res.status(400).json({
            success: false,
            message: 'Mã OTP đã hết hạn (5 phút). Vui lòng gửi lại mã mới.'
          });
        }
        if (user.otp_code !== otp.trim()) {
          return res.status(400).json({
            success: false,
            message: 'Mã OTP không chính xác'
          });
        }
        // Xóa mã OTP sau khi dùng thành công
        user.otp_code = null;
        user.otp_expires_at = null;
      } else if (current_password) {
        const isMatch = await bcrypt.compare(current_password, user.password_hash);
        if (!isMatch) {
          return res.status(400).json({
            success: false,
            message: 'Mật khẩu hiện tại không chính xác'
          });
        }
      } else {
        return res.status(400).json({
          success: false,
          message: 'Vui lòng cung cấp mã OTP gửi qua email hoặc mật khẩu hiện tại'
        });
      }

      const cleanNewPassword = targetNewPassword.trim();
      if (cleanNewPassword.length < 6) {
        return res.status(400).json({
          success: false,
          message: 'Mật khẩu mới phải có ít nhất 6 ký tự'
        });
      }
      if (/\s/.test(targetNewPassword)) {
        return res.status(400).json({
          success: false,
          message: 'Mật khẩu không được chứa khoảng trắng'
        });
      }
      if (!/[a-zA-Z]/.test(cleanNewPassword) || !/[0-9]/.test(cleanNewPassword)) {
        return res.status(400).json({
          success: false,
          message: 'Mật khẩu mới phải bao gồm cả chữ cái và chữ số'
        });
      }

      const salt = await bcrypt.genSalt(10);
      user.password_hash = await bcrypt.hash(targetNewPassword.trim(), salt);
    }

    await user.save();

    const updatedUser = await User.findById(user._id)
      .select('-password_hash')
      .populate('department_id', 'department_code department_name');

    res.status(200).json({
      success: true,
      message: 'Cập nhật thông tin cá nhân thành công',
      data: updatedUser
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

const getAllUsers = async (req, res) => {
  try {
    const { role, department_id, status, search } = req.query;
    const filter = {};

    if (role) filter.role = role;
    if (department_id) filter.department_id = department_id;
    if (status) filter.status = status;
    if (search) {
      const searchRegex = new RegExp(search.trim(), 'i');
      filter.$or = [
        { full_name: searchRegex },
        { user_code: searchRegex },
        { email: searchRegex }
      ];
    }

    const users = await User.find(filter)
      .select('-password_hash')
      .populate('department_id', 'department_code department_name')
      .sort({ created_at: -1 });

    res.status(200).json({
      success: true,
      total: users.length,
      data: users
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

const getUserById = async (req, res) => {
  try {
    const { id } = req.params;
    const user = await User.findById(id)
      .select('-password_hash')
      .populate('department_id', 'department_code department_name');

    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'Người dùng không tồn tại'
      });
    }

    res.status(200).json({
      success: true,
      data: user
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

const createUser = async (req, res) => {
  try {
    const { user_code, email, password, full_name, role, department_id } = req.body;

    if (!user_code || !email || !password || !full_name || !role) {
      return res.status(400).json({
        success: false,
        message: 'Vui lòng điền đầy đủ các thông tin bắt buộc'
      });
    }

    const validRoles = ['ADMIN', 'HEAD_OF_SUBJECT', 'LECTURER', 'STUDENT'];
    if (!validRoles.includes(role)) {
      return res.status(400).json({
        success: false,
        message: `Vai trò (role) không hợp lệ. Cho phép: ${validRoles.join(', ')}`
      });
    }

    const existingUser = await User.findOne({
      $or: [{ email: email.toLowerCase() }, { user_code }]
    });

    if (existingUser) {
      return res.status(400).json({
        success: false,
        message: 'Email hoặc Mã người dùng đã tồn tại trên hệ thống'
      });
    }

    const salt = await bcrypt.genSalt(10);
    const password_hash = await bcrypt.hash(password, salt);

    const newUser = await User.create({
      user_code,
      email: email.toLowerCase(),
      password_hash,
      full_name,
      role,
      department_id: department_id || null,
      status: req.body.status || 'ACTIVE'
    });

    res.status(201).json({
      success: true,
      message: 'Tạo tài khoản thành công',
      data: {
        id: newUser._id,
        user_code: newUser.user_code,
        full_name: newUser.full_name,
        email: newUser.email,
        role: newUser.role
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

const updateUser = async (req, res) => {
  try {
    const { id } = req.params;
    const { full_name, email, role, department_id, status, password } = req.body;

    const user = await User.findById(id);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'Người dùng không tồn tại'
      });
    }

    if (email && email.toLowerCase() !== user.email) {
      const emailExists = await User.findOne({
        email: email.toLowerCase(),
        _id: { $ne: id }
      });
      if (emailExists) {
        return res.status(400).json({
          success: false,
          message: 'Email này đã được sử dụng bởi tài khoản khác'
        });
      }
      user.email = email.toLowerCase();
    }

    if (full_name) user.full_name = full_name.trim();

    if (role) {
      const validRoles = ['ADMIN', 'HEAD_OF_SUBJECT', 'LECTURER', 'STUDENT'];
      if (!validRoles.includes(role)) {
        return res.status(400).json({
          success: false,
          message: `Vai trò (role) không hợp lệ. Cho phép: ${validRoles.join(', ')}`
        });
      }
      user.role = role;
    }

    if (department_id !== undefined) user.department_id = department_id || null;
    if (status) user.status = status;

    if (password && password.trim().length > 0) {
      const salt = await bcrypt.genSalt(10);
      user.password_hash = await bcrypt.hash(password.trim(), salt);
    }

    await user.save();

    res.status(200).json({
      success: true,
      message: 'Cập nhật tài khoản thành công',
      data: {
        id: user._id,
        user_code: user.user_code,
        full_name: user.full_name,
        email: user.email,
        role: user.role,
        department_id: user.department_id,
        status: user.status
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

const updateUserRole = async (req, res) => {
  try {
    const { id } = req.params;
    const { role } = req.body;

    const validRoles = ['ADMIN', 'HEAD_OF_SUBJECT', 'LECTURER', 'STUDENT'];
    if (!role || !validRoles.includes(role)) {
      return res.status(400).json({
        success: false,
        message: `Vai trò (role) phải là một trong: ${validRoles.join(', ')}`
      });
    }

    const user = await User.findByIdAndUpdate(
      id,
      { role },
      { new: true }
    ).select('-password_hash');

    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'Người dùng không tồn tại'
      });
    }

    res.status(200).json({
      success: true,
      message: `Phân vai trò ${role} thành công`,
      data: user
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

const deleteUser = async (req, res) => {
  try {
    const { id } = req.params;

    if (req.user._id.toString() === id) {
      return res.status(400).json({
        success: false,
        message: 'Quản trị viên không thể tự xóa tài khoản của chính mình'
      });
    }

    const user = await User.findByIdAndDelete(id);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'Người dùng không tồn tại'
      });
    }

    res.status(200).json({
      success: true,
      message: `Đã xóa tài khoản ${user.user_code} thành công`
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

const sendForgotOtp = async (req, res) => {
  try {
    const { identifier } = req.body;
    if (!identifier || !identifier.trim()) {
      return res.status(400).json({
        success: false,
        message: 'Vui lòng cung cấp mã người dùng hoặc email'
      });
    }

    const trimmed = identifier.trim();
    const user = await User.findOne({
      $or: [
        { email: trimmed.toLowerCase() },
        { user_code: trimmed }
      ]
    });

    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'Không tìm thấy tài khoản với thông tin đã cung cấp'
      });
    }

    const otp = generateOtp();
    user.otp_code = otp;
    user.otp_expires_at = new Date(Date.now() + 5 * 60 * 1000); // 5 phút
    await user.save();

    await sendOtpEmail(user.email, otp, 'đặt lại mật khẩu');

    res.status(200).json({
      success: true,
      message: `Mã OTP xác thực đã được gửi đến email ${maskEmail(user.email)}. Vui lòng kiểm tra hòm thư.`,
      data: {
        email: maskEmail(user.email),
        full_email: user.email,
        user_code: user.user_code,
        dev_otp: !process.env.SMTP_USER && !process.env.EMAIL_USER ? otp : undefined
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

const verifyForgotOtpAndReset = async (req, res) => {
  try {
    const { identifier, otp, new_password } = req.body;
    if (!identifier || !otp || !new_password) {
      return res.status(400).json({
        success: false,
        message: 'Vui lòng điền đầy đủ mã người dùng/email, mã OTP và mật khẩu mới'
      });
    }

    const trimmed = identifier.trim();
    const user = await User.findOne({
      $or: [
        { email: trimmed.toLowerCase() },
        { user_code: trimmed }
      ]
    });

    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'Không tìm thấy tài khoản với thông tin đã cung cấp'
      });
    }

    if (!user.otp_code || !user.otp_expires_at) {
      return res.status(400).json({
        success: false,
        message: 'Chưa có yêu cầu OTP nào được gửi. Vui lòng bấm "Gửi mã OTP" trước.'
      });
    }

    if (Date.now() > new Date(user.otp_expires_at).getTime()) {
      return res.status(400).json({
        success: false,
        message: 'Mã OTP đã hết hạn (5 phút). Vui lòng yêu cầu mã mới.'
      });
    }

    if (user.otp_code !== otp.trim()) {
      return res.status(400).json({
        success: false,
        message: 'Mã OTP không chính xác'
      });
    }

    const cleanNewPassword = new_password.trim();
    if (cleanNewPassword.length < 6) {
      return res.status(400).json({
        success: false,
        message: 'Mật khẩu mới phải có ít nhất 6 ký tự'
      });
    }
    if (/\s/.test(new_password)) {
      return res.status(400).json({
        success: false,
        message: 'Mật khẩu không được chứa khoảng trắng'
      });
    }
    if (!/[a-zA-Z]/.test(cleanNewPassword) || !/[0-9]/.test(cleanNewPassword)) {
      return res.status(400).json({
        success: false,
        message: 'Mật khẩu mới phải bao gồm cả chữ cái và chữ số'
      });
    }

    const salt = await bcrypt.genSalt(10);
    user.password_hash = await bcrypt.hash(new_password.trim(), salt);
    user.otp_code = null;
    user.otp_expires_at = null;
    await user.save();

    res.status(200).json({
      success: true,
      message: 'Đặt lại mật khẩu thành công! Bạn có thể đăng nhập bằng mật khẩu mới.'
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

const sendProfileOtp = async (req, res) => {
  try {
    const user = await User.findById(req.user._id);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'Người dùng không tồn tại'
      });
    }

    const otp = generateOtp();
    user.otp_code = otp;
    user.otp_expires_at = new Date(Date.now() + 5 * 60 * 1000); // 5 phút
    await user.save();

    await sendOtpEmail(user.email, otp, 'đổi mật khẩu hồ sơ');

    res.status(200).json({
      success: true,
      message: `Mã OTP xác thực đã được gửi đến email ${maskEmail(user.email)}. Vui lòng kiểm tra hòm thư.`,
      data: {
        email: maskEmail(user.email),
        full_email: user.email,
        dev_otp: !process.env.SMTP_USER && !process.env.EMAIL_USER ? otp : undefined
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

module.exports = {
  login,
  sendForgotOtp,
  verifyForgotOtpAndReset,
  sendProfileOtp,
  getMe,
  updateProfile,
  getAllUsers,
  getUserById,
  createUser,
  updateUser,
  updateUserRole,
  deleteUser
};

