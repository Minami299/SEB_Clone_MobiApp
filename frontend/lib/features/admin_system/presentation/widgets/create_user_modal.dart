import 'package:flutter/material.dart';

class CreateUserModal extends StatefulWidget {
  final Future<void> Function({
    required String userCode,
    required String email,
    required String password,
    required String fullName,
    required String role,
    required String status,
  }) onSubmit;

  const CreateUserModal({
    super.key,
    required this.onSubmit,
  });

  static Future<void> show(
    BuildContext context, {
    required Future<void> Function({
      required String userCode,
      required String email,
      required String password,
      required String fullName,
      required String role,
      required String status,
    }) onSubmit,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateUserModal(onSubmit: onSubmit),
    );
  }

  @override
  State<CreateUserModal> createState() => _CreateUserModalState();
}

class _CreateUserModalState extends State<CreateUserModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController(text: 'Password@123');
  String _roleVal = 'STUDENT';
  bool _autoActivate = true;
  bool _isSubmitting = false;
  bool _obscurePass = true;
  String? _localError;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xFF334155),
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildLightTextField({
    required TextEditingController controller,
    required String hintText,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
        ),
      ),
      validator: validator,
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _localError = null;
    });

    try {
      await widget.onSubmit(
        userCode: _codeCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        fullName: _nameCtrl.text.trim(),
        password: _passCtrl.text.trim(),
        role: _roleVal,
        status: _autoActivate ? 'ACTIVE' : 'INACTIVE',
      );
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _localError = e.toString().replaceAll('Exception:', '').trim();
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Grab bar
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Header modal
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF4F46E5), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Thêm Người Dùng Mới',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Cấp tài khoản & quyền cấu hình Safe Exam Browser',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF94A3B8), size: 20),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              if (_localError != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Text(
                    _localError!,
                    style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 1. Họ và tên
              _buildFieldLabel('Họ và tên thí sinh / Cán bộ *'),
              const SizedBox(height: 6),
              _buildLightTextField(
                controller: _nameCtrl,
                hintText: 'VD: Nguyễn Văn Hoàng',
                validator: (v) => v == null || v.trim().isEmpty ? 'Vui lòng nhập họ và tên' : null,
              ),
              const SizedBox(height: 14),

              // 2. Hàng: Mã định danh & Vai trò
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('Mã định danh (MSSV / CB) *'),
                        const SizedBox(height: 6),
                        _buildLightTextField(
                          controller: _codeCtrl,
                          hintText: 'VD: SV202611',
                          validator: (v) => v == null || v.trim().isEmpty ? 'Bắt buộc' : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('Vai trò (Role) *'),
                        const SizedBox(height: 6),
                        Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _roleVal,
                              dropdownColor: Colors.white,
                              isExpanded: true,
                              style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
                              items: const [
                                DropdownMenuItem(value: 'STUDENT', child: Text('Thí sinh / Sinh viên')),
                                DropdownMenuItem(value: 'LECTURER', child: Text('Giám thị')),
                                DropdownMenuItem(value: 'HEAD_OF_SUBJECT', child: Text('Trưởng bộ môn')),
                                DropdownMenuItem(value: 'ADMIN', child: Text('Quản trị')),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _roleVal = val);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 3. Email tổ chức / Trường học
              _buildFieldLabel('Email tổ chức / Trường học *'),
              const SizedBox(height: 6),
              _buildLightTextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                hintText: 'VD: hoangnv@university.edu.vn',
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Vui lòng nhập email';
                  if (!v.contains('@')) return 'Email không đúng định dạng';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // 4. Mật khẩu ban đầu
              _buildFieldLabel('Mật khẩu ban đầu *'),
              const SizedBox(height: 6),
              _buildLightTextField(
                controller: _passCtrl,
                obscureText: _obscurePass,
                hintText: 'Mặc định: Password@123',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: const Color(0xFF94A3B8),
                    size: 18,
                  ),
                  onPressed: () {
                    setState(() => _obscurePass = !_obscurePass);
                  },
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Vui lòng nhập mật khẩu';
                  if (v.contains(' ')) return 'Mật khẩu không được chứa khoảng trắng';
                  if (v.length < 6) return 'Mật khẩu phải có ít nhất 6 ký tự';
                  if (!RegExp(r'[a-zA-Z]').hasMatch(v)) return 'Mật khẩu phải chứa ít nhất 1 chữ cái';
                  if (!RegExp(r'[0-9]').hasMatch(v)) return 'Mật khẩu phải chứa ít nhất 1 chữ số';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 5. Tự động kích hoạt tài khoản
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Tự động kích hoạt tài khoản',
                        style: TextStyle(color: Color(0xFF0F172A), fontSize: 13),
                      ),
                    ),
                    Checkbox(
                      value: _autoActivate,
                      activeColor: const Color(0xFF4F46E5),
                      checkColor: Colors.white,
                      onChanged: (val) {
                        setState(() => _autoActivate = val ?? true);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Hàng nút Hủy bỏ & Tạo Tài Khoản
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF475569),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Hủy bỏ', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          elevation: 1,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isSubmitting ? null : _handleSubmit,
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text(
                                'Tạo Tài Khoản',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
