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

const createUser = async (req, res) => {
  try {
    const { user_code, email, password, full_name, role, department_id } = req.body;

    if (!user_code || !email || !password || !full_name || !role) {
      return res.status(400).json({
        success: false,
        message: 'Vui lòng điền đầy đủ các thông tin bắt buộc'
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

module.exports = {
  login,
  getMe,
  createUser
};

