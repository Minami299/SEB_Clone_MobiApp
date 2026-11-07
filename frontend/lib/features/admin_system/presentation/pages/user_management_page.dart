import 'package:flutter/material.dart';
import '../../../../core/services/session_service.dart';
import '../../../auth/data/datasources/auth_remote_datasource.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/presentation/pages/login_page.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  final _authDataSource = AuthRemoteDataSource();
  List<UserModel> _users = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedRoleFilter = 'ALL';
  final _searchController = TextEditingController();

  final List<String> _roles = ['ADMIN', 'HEAD_OF_SUBJECT', 'LECTURER', 'STUDENT'];

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final role = _selectedRoleFilter == 'ALL' ? null : _selectedRoleFilter;
      final search = _searchController.text.trim();
      final users = await _authDataSource.getAllUsers(role: role, search: search);
      if (mounted) {
        setState(() {
          _users = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleUpdateRole(UserModel user) async {
    String selectedRole = user.role;

    final updatedRole = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Phân vai trò: ${user.fullName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Mã: ${user.userCode} | Email: ${user.email}'),
              const SizedBox(height: 16),
              const Text('Chọn vai trò mới:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: selectedRole,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: _roles
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() => selectedRole = val);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Hủy')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, selectedRole),
              child: const Text('Cập nhật'),
            ),
          ],
        ),
      ),
    );

    if (updatedRole == null || updatedRole == user.role) return;

    try {
      await _authDataSource.updateUserRole(userId: user.id, role: updatedRole);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã cập nhật vai trò ${user.userCode} thành $updatedRole'), backgroundColor: Colors.green),
      );
      _fetchUsers();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _handleDeleteUser(UserModel user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa tài khoản'),
        content: Text('Bạn có chắc chắn muốn xóa tài khoản ${user.fullName} (${user.userCode})?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _authDataSource.deleteUser(user.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã xóa tài khoản ${user.userCode}'), backgroundColor: Colors.green),
      );
      _fetchUsers();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _handleCreateUser() async {
    final codeCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    String roleVal = 'STUDENT';
    final formKey = GlobalKey<FormState>();

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Thêm tài khoản mới'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: codeCtrl,
                    decoration: const InputDecoration(labelText: 'Mã người dùng (User Code)'),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Bắt buộc nhập' : null,
                  ),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Họ và tên'),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Bắt buộc nhập' : null,
                  ),
                  TextFormField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Bắt buộc nhập' : null,
                  ),
                  TextFormField(
                    controller: passCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Mật khẩu'),
                    validator: (v) => v == null || v.isEmpty ? 'Bắt buộc nhập' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: roleVal,
                    decoration: const InputDecoration(labelText: 'Vai trò (Role)'),
                    items: _roles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                    onChanged: (v) {
                      if (v != null) setDialogState(() => roleVal = v);
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('Tạo mới'),
            ),
          ],
        ),
      ),
    );

    if (created == true) {
      try {
        await _authDataSource.createUser(
          userCode: codeCtrl.text.trim(),
          email: emailCtrl.text.trim(),
          fullName: nameCtrl.text.trim(),
          password: passCtrl.text,
          role: roleVal,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tạo người dùng thành công'), backgroundColor: Colors.green),
        );
        _fetchUsers();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    }
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

  String _getUserCodeLabel(String role) {
    switch (role) {
      case 'STUDENT':
        return 'Mã học sinh';
      case 'LECTURER':
        return 'Mã giảng viên';
      case 'HEAD_OF_SUBJECT':
        return 'Mã trưởng bộ môn';
      case 'ADMIN':
        return 'Mã quản trị viên';
      default:
        return 'Mã định danh';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Tài khoản & Phân quyền'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchUsers,
            tooltip: 'Làm mới',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Đăng xuất',
            onPressed: () {
              SessionService().clearSession();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _handleCreateUser,
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        tooltip: 'Thêm tài khoản',
        child: const Icon(Icons.person_add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Tìm theo tên, mã số, email...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _fetchUsers();
                        },
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onSubmitted: (_) => _fetchUsers(),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _selectedRoleFilter,
                  items: ['ALL', ..._roles]
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedRoleFilter = val);
                      _fetchUsers();
                    }
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                            const SizedBox(height: 8),
                            ElevatedButton(onPressed: _fetchUsers, child: const Text('Thử lại')),
                          ],
                        ),
                      )
                    : _users.isEmpty
                        ? const Center(child: Text('Không tìm thấy tài khoản nào'))
                        : ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: _users.length,
                            separatorBuilder: (context, _) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final user = _users[index];
                              return Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                child: ListTile(
                                  onTap: () => _handleUpdateRole(user),
                                  title: Text(
                                    user.fullName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  subtitle: Text(
                                    '${_getUserCodeLabel(user.role)}: ${user.userCode}',
                                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _getRoleColor(user.role).withAlpha(30),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: _getRoleColor(user.role)),
                                        ),
                                        child: Text(
                                          user.role,
                                          style: TextStyle(
                                            color: _getRoleColor(user.role),
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                        tooltip: 'Xóa tài khoản',
                                        onPressed: () => _handleDeleteUser(user),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
