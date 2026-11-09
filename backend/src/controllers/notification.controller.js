const { Notification } = require('../models');

const getMyNotifications = async (req, res) => {
  try {
    const notifications = await Notification.find({ recipient_id: req.user._id })
      .populate('sender_id', 'full_name email user_code role')
      .sort({ created_at: -1 })
      .limit(50);

    const unreadCount = await Notification.countDocuments({
      recipient_id: req.user._id,
      is_read: false
    });

    res.status(200).json({
      success: true,
      data: notifications,
      unreadCount
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

const getUnreadCount = async (req, res) => {
  try {
    const unreadCount = await Notification.countDocuments({
      recipient_id: req.user._id,
      is_read: false
    });

    res.status(200).json({
      success: true,
      unreadCount
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

const markAsRead = async (req, res) => {
  try {
    const { id } = req.params;
    await Notification.findOneAndUpdate(
      { _id: id, recipient_id: req.user._id },
      { is_read: true }
    );

    res.status(200).json({
      success: true,
      message: 'Đã đánh dấu thông báo là đã đọc'
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

const markAllAsRead = async (req, res) => {
  try {
    await Notification.updateMany(
      { recipient_id: req.user._id, is_read: false },
      { is_read: true }
    );

    res.status(200).json({
      success: true,
      message: 'Đã đánh dấu tất cả thông báo là đã đọc'
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

module.exports = {
  getMyNotifications,
  getUnreadCount,
  markAsRead,
  markAllAsRead
};

