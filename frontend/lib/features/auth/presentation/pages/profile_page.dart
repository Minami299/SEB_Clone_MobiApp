import 'package:flutter/material.dart';

import '../../../../core/services/session_service.dart';
import '../../../../core/utils/smooth_page_route.dart';
import '../../../admin_system/presentation/pages/user_management_page.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/models/user_model.dart';
import 'login_page.dart';

class ProfilePage extends StatefulWidget {
  final bool showAppBar;
  const ProfilePage({super.key, this.showAppBar = true});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _authDataSource = AuthRemoteDataSource();

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isChangingPassword = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _isSendingOtp = false;
  String? _otpSentMessage;
  String? _devOtpHint;
  UserModel? _user;

  @override
  void initState() {
    super.initState();
    _user = SessionService().currentUser;
    _nameController = TextEditingController(text: _user?.fullName ?? '');
    _emailController = TextEditingController(text: _user?.email ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSendOtp() async {
    setState(() {
      _isSendingOtp = true;
    });

    try {
      final res = await _authDataSource.sendProfileOtp();
      if (!mounted) return;
      setState(() {
        _isSendingOtp = false;
        _otpSentMessage = res['message'] as String? ?? 'Mã OTP đã được gửi đến email.';
        _devOtpHint = res['data']?['dev_otp'] as String?;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_otpSentMessage!),
          backgroundColor: Colors.blue.shade700,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSendingOtp = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi gửi OTP: ${e.toString().replaceAll("Exception:", "").trim()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    if (_isChangingPassword) {
      if (_otpController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng gửi và nhập mã OTP xác thực trước khi lưu mật khẩu mới'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      if (_newPasswordController.text != _confirmPasswordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mật khẩu xác nhận không trùng khớp'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final updatedUser = await _authDataSource.updateProfile(
        fullName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        newPassword: _isChangingPassword && _newPasswordController.text.isNotEmpty
            ? _newPasswordController.text.trim()
            : null,
        otp: _isChangingPassword && _otpController.text.isNotEmpty
            ? _otpController.text.trim()
            : null,
      );

      if (!mounted) return;
      setState(() {
        _user = updatedUser;
        _otpController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        _isChangingPassword = false;
        _otpSentMessage = null;
        _devOtpHint = null;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cập nhật thông tin thành công'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: ${e.toString().replaceAll("Exception:", "").trim()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc chắn muốn đăng xuất khỏi tài khoản này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              SessionService().clearSession();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
              );
            },
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'ADMIN':
        return Colors.red;
      case 'HEAD_OF_SUBJECT':
        return Colors.purple;
      case 'LECTURER':
        return Colors.blue;
      case 'STUDENT':
      default:
        return Colors.teal;
    }
  }

  String _getRoleDisplayName(String role) {
    switch (role) {
      case 'ADMIN':
        return 'Quản trị viên (Admin)';
      case 'HEAD_OF_SUBJECT':
        return 'Trưởng bộ môn';
      case 'LECTURER':
        return 'Giảng viên';
      case 'STUDENT':
        return 'Sinh viên';
      default:
        return role;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _user ?? SessionService().currentUser;
    final role = user?.role ?? '';
    final roleColor = _getRoleColor(role);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text(
                'Thông tin cá nhân',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF1E293B),
              elevation: 0.5,
              automaticallyImplyLeading: role != 'ADMIN',
            )
          : null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar & Role Info Card
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 38,
                      backgroundColor: const Color(0xFF1E3A5F),
                      child: Text(
                        (user?.fullName.isNotEmpty == true) ? user!.fullName[0].toUpperCase() : 'U',
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      user?.fullName ?? '',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Mã định danh: ${user?.userCode ?? ""}',
                      style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: roleColor.withAlpha(25),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: roleColor),
                      ),
                      child: Text(
                        _getRoleDisplayName(role),
                        style: TextStyle(
                          color: roleColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Edit Form Card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Cập nhật thông tin',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Họ và tên',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Vui lòng nhập họ và tên';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Vui lòng nhập email';
                        }
                        if (!value.contains('@')) {
                          return 'Email không hợp lệ';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    if (!_isChangingPassword)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _isChangingPassword = true;
                            });
                          },
                          icon: const Icon(Icons.lock_reset, size: 20),
                          label: const Text('Cập nhật mật khẩu mới (qua OTP Email)'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF1E3A5F),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      )
                    else ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: const [
                                    Icon(Icons.shield_outlined, color: Color(0xFF0062FF), size: 18),
                                    SizedBox(width: 6),
                                    Text(
                                      'Đổi mật khẩu qua OTP Email',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
                                    ),
                                  ],
                                ),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _isChangingPassword = false;
                                      _otpController.clear();
                                      _newPasswordController.clear();
                                      _confirmPasswordController.clear();
                                      _otpSentMessage = null;
                                      _devOtpHint = null;
                                    });
                                  },
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(40, 30),
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    foregroundColor: Colors.red,
                                  ),
                                  child: const Text('Hủy'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Nhấn nút bên dưới để nhận mã OTP gửi về email ${_user?.email ?? ""}:',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _isSendingOtp ? null : _handleSendOtp,
                                icon: _isSendingOtp
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.send_outlined, size: 16),
                                label: Text(_isSendingOtp ? 'Đang gửi...' : 'Gửi mã OTP về email'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF0062FF),
                                  side: const BorderSide(color: Color(0xFF93C5FD)),
                                  backgroundColor: const Color(0xFFEFF6FF),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                            if (_otpSentMessage != null) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.green.shade200),
                                ),
                                child: Text(
                                  _otpSentMessage!,
                                  style: TextStyle(fontSize: 12, color: Colors.green.shade800),
                                ),
                              ),
                            ],
                            if (_devOtpHint != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Mã OTP thử nghiệm: $_devOtpHint',
                                style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold),
                              ),
                            ],
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _otpController,
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              decoration: const InputDecoration(
                                labelText: 'Mã xác thực OTP (6 số)',
                                hintText: 'Nhập mã OTP nhận từ email',
                                counterText: '',
                                prefixIcon: Icon(Icons.key_outlined),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(),
                              ),
                              validator: (val) {
                                if (_isChangingPassword && (val == null || val.trim().length != 6)) {
                                  return 'Vui lòng nhập đủ 6 số OTP';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _newPasswordController,
                              obscureText: _obscureNewPassword,
                              decoration: InputDecoration(
                                labelText: 'Mật khẩu mới',
                                hintText: 'Tối thiểu 6 ký tự',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscureNewPassword ? Icons.visibility : Icons.visibility_off),
                                  onPressed: () {
                                    setState(() => _obscureNewPassword = !_obscureNewPassword);
                                  },
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                border: const OutlineInputBorder(),
                              ),
                              validator: (val) {
                                if (_isChangingPassword) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Vui lòng nhập mật khẩu mới';
                                  }
                                  if (val.contains(' ')) {
                                    return 'Mật khẩu không được chứa khoảng trắng';
                                  }
                                  if (val.length < 6) {
                                    return 'Mật khẩu mới phải có ít nhất 6 ký tự';
                                  }
                                  if (!RegExp(r'[a-zA-Z]').hasMatch(val)) {
                                    return 'Mật khẩu phải chứa ít nhất 1 chữ cái';
                                  }
                                  if (!RegExp(r'[0-9]').hasMatch(val)) {
                                    return 'Mật khẩu phải chứa ít nhất 1 chữ số';
                                  }
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: _obscureConfirmPassword,
                              decoration: InputDecoration(
                                labelText: 'Xác nhận mật khẩu mới',
                                hintText: 'Nhập lại mật khẩu mới',
                                prefixIcon: const Icon(Icons.lock_reset),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscureConfirmPassword ? Icons.visibility : Icons.visibility_off),
                                  onPressed: () {
                                    setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                                  },
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                border: const OutlineInputBorder(),
                              ),
                              validator: (val) {
                                if (_isChangingPassword) {
                                  if (val == null || val.isEmpty) {
                                    return 'Vui lòng xác nhận mật khẩu mới';
                                  }
                                  if (val != _newPasswordController.text) {
                                    return 'Mật khẩu xác nhận không khớp';
                                  }
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E3A5F),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('Lưu thay đổi', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Logout Button
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: _handleLogout,
                  icon: const Icon(Icons.logout, color: Colors.red),
                  label: const Text('Đăng xuất tài khoản', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: role == 'ADMIN'
          ? NavigationBar(
              selectedIndex: 1,
              height: 64,
              backgroundColor: Colors.white,
              indicatorColor: const Color(0xFFE2E8F0),
              elevation: 3,
              onDestinationSelected: (idx) {
                if (idx == 0) {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  } else {
                    Navigator.pushReplacement(
                      context,
                      smoothPageRoute(const UserManagementPage()),
                    );
                  }
                }
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.people_outline),
                  selectedIcon: Icon(Icons.people, color: Color(0xFF0F172A)),
                  label: 'Người dùng',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person, color: Color(0xFF0F172A)),
                  label: 'Cá nhân',
                ),
              ],
            )
          : null,
    );
  }
}
