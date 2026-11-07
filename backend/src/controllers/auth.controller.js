const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const config = require('../config');
const { User } = require('../models');

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
      status: 'ACTIVE'
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

module.exports = {
  login,
  getMe,
  getAllUsers,
  getUserById,
  createUser,
  updateUser,
  updateUserRole,
  deleteUser
};

