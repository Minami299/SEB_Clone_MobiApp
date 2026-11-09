import 'package:flutter/material.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../widgets/top_wave_clipper.dart';
import '../../../exam_execution/presentation/pages/exam_list_page.dart';
import '../../../exam_execution/presentation/pages/student_home_page.dart';
import '../../../admin_system/presentation/pages/user_management_page.dart';
import '../../../subject_access/presentation/pages/head_of_subject_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  final _authDataSource = AuthRemoteDataSource();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _identifierController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await _authDataSource.login(
        identifier: _identifierController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đăng nhập thành công: ${user.fullName} (${user.role})'),
          backgroundColor: Colors.green,
        ),
      );

      if (user.role == 'ADMIN') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const UserManagementPage()),
        );
      } else if (user.role == 'HEAD_OF_SUBJECT') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HeadOfSubjectPage()),
        );
      } else if (user.role == 'STUDENT') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const StudentHomePage()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ExamListPage()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      String msg = e.toString().replaceAll('Exception:', '').trim();
      if (msg.contains('Connection refused') ||
          msg.contains('Failed host lookup') ||
          msg.contains('Network Connection Error')) {
        msg = 'Không thể kết nối đến máy chủ (${ApiEndpoints.baseUrl}).\n'
            'Hãy kiểm tra backend hoặc bấm Cài đặt để cập nhật Host IP.';
      }
      setState(() {
        _errorMessage = msg;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showForgotPasswordSheet() {
    final formKey = GlobalKey<FormState>();
    final identifierCtrl = TextEditingController(text: _identifierController.text.trim());
    final otpCtrl = TextEditingController();
    final newPasswordCtrl = TextEditingController();
    final confirmPasswordCtrl = TextEditingController();
    int currentStep = 1; // 1 = Gửi OTP, 2 = Nhập OTP và Mật khẩu mới
    String? maskedEmail;
    String? devOtpHint;
    bool isSubmitting = false;
    bool obscureNew = true;
    bool obscureConfirm = true;
    String? localError;
    String? localSuccess;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(modalContext).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.mark_email_read_outlined, color: Color(0xFF0062FF), size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Quên mật khẩu',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  currentStep == 1
                                      ? 'Bước 1: Xác nhận tài khoản và nhận mã OTP'
                                      : 'Bước 2: Nhập mã OTP và tạo mật khẩu mới',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      if (localError != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Text(
                            localError!,
                            style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      if (localSuccess != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Text(
                            localSuccess!,
                            style: TextStyle(color: Colors.green.shade800, fontSize: 13),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      if (currentStep == 1) ...[
                        TextFormField(
                          controller: identifierCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Mã số sinh viên / Email',
                            hintText: 'Nhập mã số hoặc email đã đăng ký',
                            prefixIcon: Icon(Icons.person_outline, color: Color(0xFF0066FF)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Vui lòng nhập mã số hoặc email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0062FF),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: isSubmitting
                                ? null
                                : () async {
                                    if (!formKey.currentState!.validate()) return;
                                    setModalState(() {
                                      isSubmitting = true;
                                      localError = null;
                                      localSuccess = null;
                                    });

                                    try {
                                      final res = await _authDataSource.sendForgotOtp(identifierCtrl.text.trim());
                                      setModalState(() {
                                        maskedEmail = res['data']?['email'] ?? identifierCtrl.text.trim();
                                        devOtpHint = res['data']?['dev_otp'];
                                        currentStep = 2;
                                        localSuccess = res['message'] ?? 'Mã OTP đã được gửi đến email.';
                                      });
                                    } catch (e) {
                                      setModalState(() {
                                        localError = e.toString().replaceAll('Exception:', '').trim();
                                      });
                                    } finally {
                                      setModalState(() {
                                        isSubmitting = false;
                                      });
                                    }
                                  },
                            child: isSubmitting
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Text('Gửi mã OTP qua Email', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.email, color: Color(0xFF0062FF), size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Gửi đến: ${maskedEmail ?? identifierCtrl.text}',
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1E293B)),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  setModalState(() {
                                    currentStep = 1;
                                    localError = null;
                                    localSuccess = null;
                                  });
                                },
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(40, 24),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text('Đổi email', style: TextStyle(fontSize: 12, color: Color(0xFF0062FF))),
                              ),
                            ],
                          ),
                        ),
                        if (devOtpHint != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Mã OTP thử nghiệm: $devOtpHint',
                            style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold),
                          ),
                        ],
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: otpCtrl,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          decoration: InputDecoration(
                            labelText: 'Mã xác thực OTP (6 chữ số)',
                            hintText: 'Nhập mã 6 số từ email',
                            counterText: '',
                            prefixIcon: const Icon(Icons.shield_outlined, color: Color(0xFF0062FF)),
                            suffixIcon: TextButton(
                              onPressed: isSubmitting
                                  ? null
                                  : () async {
                                      setModalState(() {
                                        isSubmitting = true;
                                        localError = null;
                                        localSuccess = null;
                                      });
                                      try {
                                        final res = await _authDataSource.sendForgotOtp(identifierCtrl.text.trim());
                                        setModalState(() {
                                          devOtpHint = res['data']?['dev_otp'];
                                          localSuccess = 'Đã gửi lại mã OTP mới vào hòm thư!';
                                        });
                                      } catch (e) {
                                        setModalState(() {
                                          localError = e.toString().replaceAll('Exception:', '').trim();
                                        });
                                      } finally {
                                        setModalState(() {
                                          isSubmitting = false;
                                        });
                                      }
                                    },
                              child: const Text('Gửi lại mã', style: TextStyle(fontSize: 12, color: Color(0xFF0062FF))),
                            ),
                            border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().length != 6) {
                              return 'Vui lòng nhập đủ 6 chữ số OTP';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: newPasswordCtrl,
                          obscureText: obscureNew,
                          decoration: InputDecoration(
                            labelText: 'Mật khẩu mới',
                            hintText: 'Tối thiểu 6 ký tự',
                            prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF0062FF)),
                            suffixIcon: IconButton(
                              icon: Icon(
                                obscureNew ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                color: const Color(0xFF94A3B8),
                              ),
                              onPressed: () {
                                setModalState(() {
                                  obscureNew = !obscureNew;
                                });
                              },
                            ),
                            border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          ),
                          validator: (val) {
                            if (val == null || val.isEmpty) {
                              return 'Vui lòng nhập mật khẩu mới';
                            }
                            if (val.trim().length < 6) {
                              return 'Mật khẩu phải có ít nhất 6 ký tự';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: confirmPasswordCtrl,
                          obscureText: obscureConfirm,
                          decoration: InputDecoration(
                            labelText: 'Xác nhận mật khẩu mới',
                            hintText: 'Nhập lại mật khẩu mới',
                            prefixIcon: const Icon(Icons.lock_reset, color: Color(0xFF0062FF)),
                            suffixIcon: IconButton(
                              icon: Icon(
                                obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                color: const Color(0xFF94A3B8),
                              ),
                              onPressed: () {
                                setModalState(() {
                                  obscureConfirm = !obscureConfirm;
                                });
                              },
                            ),
                            border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          ),
                          validator: (val) {
                            if (val == null || val.isEmpty) {
                              return 'Vui lòng xác nhận mật khẩu mới';
                            }
                            if (val != newPasswordCtrl.text) {
                              return 'Mật khẩu xác nhận không trùng khớp';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0062FF),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: isSubmitting
                                ? null
                                : () async {
                                    if (!formKey.currentState!.validate()) return;
                                    setModalState(() {
                                      isSubmitting = true;
                                      localError = null;
                                      localSuccess = null;
                                    });

                                    try {
                                      final msg = await _authDataSource.verifyForgotOtpAndReset(
                                        identifier: identifierCtrl.text.trim(),
                                        otp: otpCtrl.text.trim(),
                                        newPassword: newPasswordCtrl.text.trim(),
                                      );
                                      if (!mounted) return;
                                      Navigator.pop(ctx);
                                      setState(() {
                                        _identifierController.text = identifierCtrl.text.trim();
                                        _passwordController.clear();
                                      });
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(msg),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    } catch (e) {
                                      setModalState(() {
                                        localError = e.toString().replaceAll('Exception:', '').trim();
                                      });
                                    } finally {
                                      setModalState(() {
                                        isSubmitting = false;
                                      });
                                    }
                                  },
                            child: isSubmitting
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Text('Xác nhận đặt lại mật khẩu', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Đóng', style: TextStyle(color: Color(0xFF64748B))),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasValidIdentifier = _identifierController.text.trim().length >= 3;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. Phần trên: Header lượn sóng xanh (Fluid Wave Header)
            ClipPath(
              clipper: TopWaveClipper(),
              child: Container(
                height: 300,
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF0066FF), Color(0xFF004BD6)],
                  ),
                ),
                child: Stack(
                  children: [
                    // Các bóng tròn bọt khí trang trí
                    Positioned(
                      right: 20,
                      top: 60,
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: const Color(0xFF003CB3).withOpacity(0.55),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 90,
                      top: 130,
                      child: Container(
                        width: 55,
                        height: 55,
                        decoration: BoxDecoration(
                          color: const Color(0xFF003CB3).withOpacity(0.45),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 40,
                      top: 190,
                      child: Container(
                        width: 35,
                        height: 35,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A75FF).withOpacity(0.4),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),

                    // Nội dung Header: Nút back & Chữ "Welcome Back"
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                              padding: EdgeInsets.zero,
                              alignment: Alignment.centerLeft,
                              onPressed: () {
                                if (Navigator.canPop(context)) {
                                  Navigator.pop(context);
                                }
                              },
                            ),
                            const SizedBox(height: 28),
                            const Text(
                              'Welcome\nBack',
                              style: TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                height: 1.15,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 2. Phần dưới: Form đăng nhập nền trắng
            Padding(
              padding: const EdgeInsets.fromLTRB(28.0, 10.0, 28.0, 32.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Thông báo lỗi nếu có
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade800, fontSize: 13, height: 1.3),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Trường 1: Email / Mã số sinh viên
                    TextFormField(
                      controller: _identifierController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        hintText: 'Mã số sinh viên / Email',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                        prefixIcon: const Icon(Icons.mail_outline, color: Color(0xFF0066FF), size: 22),
                        suffixIcon: hasValidIdentifier
                            ? const Icon(Icons.check, color: Color(0xFF0066FF), size: 20)
                            : null,
                        enabledBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
                        ),
                        focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF0066FF), width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Vui lòng nhập mã số hoặc email';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    // Trường 2: Mật khẩu
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        hintText: 'Mật khẩu',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                        prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF94A3B8), size: 22),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: const Color(0xFF94A3B8),
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        enabledBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
                        ),
                        focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF0066FF), width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Vui lòng nhập mật khẩu';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 12),

                    // Quên mật khẩu
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _showForgotPasswordSheet,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Forgot password?',
                          style: TextStyle(
                            color: Color(0xFF0066FF),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Nút Đăng nhập màu xanh nổi bật (Solid Blue Button)
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0062FF),
                          foregroundColor: Colors.white,
                          elevation: 3,
                          shadowColor: const Color(0xFF0062FF).withOpacity(0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                          : const Text(
                              'Log in',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
