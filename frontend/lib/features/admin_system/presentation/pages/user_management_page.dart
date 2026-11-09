import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/services/session_service.dart';
import '../../../auth/data/datasources/auth_remote_datasource.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/presentation/pages/welcome_page.dart';
import '../widgets/create_user_modal.dart';
import '../widgets/user_action_sheet.dart';
import '../widgets/user_card_widget.dart';

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
  Timer? _searchDebounce;

  final Map<String, String> _roleDisplayNames = {
    'STUDENT': 'Thí sinh / Sinh viên',
    'LECTURER': 'Giám thị / Giảng viên',
    'HEAD_OF_SUBJECT': 'Trưởng bộ môn',
    'ADMIN': 'Quản trị viên',
  };

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      _fetchUsers(showLoading: false);
    });
  }

  Future<void> _fetchUsers({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final role = _selectedRoleFilter == 'ALL' ? null : _selectedRoleFilter;
      final search = _searchController.text.trim();
      final users = await _authDataSource.getAllUsers(
        role: role,
        search: search,
      );
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

  // Chuyển đổi trạng thái Khóa / Kích hoạt
  Future<void> _handleToggleStatus(UserModel user) async {
    final newStatus = user.status == 'ACTIVE' ? 'INACTIVE' : 'ACTIVE';
    try {
      await _authDataSource.updateUser(
        userId: user.id,
        status: newStatus,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus == 'ACTIVE'
                ? 'Đã kích hoạt lại tài khoản ${user.userCode}'
                : 'Đã khóa tài khoản ${user.userCode}',
          ),
          backgroundColor: newStatus == 'ACTIVE' ? const Color(0xFF059669) : const Color(0xFFD97706),
        ),
      );
      _fetchUsers(showLoading: false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: const Color(0xFFDC2626)),
      );
    }
  }

  // Cập nhật vai trò
  Future<void> _handleUpdateRoleDialog(UserModel user) async {
    String selectedRole = user.role;

    final updatedRole = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          title: Text(
            'Phân vai trò: ${user.fullName}',
            style: const TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mã: ${user.userCode} | Email: ${user.email}',
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
              ),
              const SizedBox(height: 16),
              const Text(
                'Chọn vai trò mới:',
                style: TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedRole,
                    dropdownColor: Colors.white,
                    isExpanded: true,
                    style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
                    items: _roleDisplayNames.entries
                        .map(
                          (entry) => DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedRole = val);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Hủy', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, selectedRole),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
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
        SnackBar(
          content: Text(
            'Đã cập nhật vai trò ${user.userCode} thành ${_roleDisplayNames[updatedRole] ?? updatedRole}',
          ),
          backgroundColor: const Color(0xFF059669),
        ),
      );
      _fetchUsers(showLoading: false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: const Color(0xFFDC2626)),
      );
    }
  }

  // Xóa tài khoản
  Future<void> _handleDeleteUser(UserModel user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        title: const Text('Xác nhận xóa tài khoản', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
        content: Text(
          'Bạn có chắc chắn muốn xóa tài khoản ${user.fullName} (${user.userCode}) khỏi hệ thống?',
          style: const TextStyle(color: Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
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
        SnackBar(
          content: Text('Đã xóa tài khoản ${user.userCode} thành công'),
          backgroundColor: const Color(0xFF059669),
        ),
      );
      _fetchUsers(showLoading: false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: const Color(0xFFDC2626)),
      );
    }
  }

  // Mở modal thêm người dùng mới
  void _openCreateUserModal() {
    CreateUserModal.show(
      context,
      onSubmit: ({
        required String userCode,
        required String email,
        required String password,
        required String fullName,
        required String role,
        required String status,
      }) async {
        await _authDataSource.createUser(
          userCode: userCode,
          email: email,
          fullName: fullName,
          password: password,
          role: role,
          status: status,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tạo người dùng mới thành công!'),
            backgroundColor: Color(0xFF059669),
          ),
        );
        _fetchUsers(showLoading: false);
      },
    );
  }

  // Chip bộ lọc
  Widget _buildFilterChip({
    required String label,
    required String roleKey,
    required int count,
  }) {
    final isSelected = _selectedRoleFilter == roleKey;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedRoleFilter = roleKey;
        });
        _fetchUsers();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4F46E5) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Text(
          '$label ($count)',
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF64748B),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final studentCount = _users.where((u) => u.role == 'STUDENT').length;
    final lecturerCount = _users.where((u) => u.role == 'LECTURER').length;
    final adminCount = _users.where((u) => u.role == 'ADMIN').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Top Dynamic Island Indicator
            const SizedBox(height: 8),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFC7D2FE).withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF4F46E5),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'SEB Admin',
                      style: TextStyle(
                        color: Color(0xFF475569),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 2. Header: Title, Total Count, Button "+ Tạo mới"
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.groups_2_rounded, color: Color(0xFF4F46E5), size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Quản lý Người Dùng',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Tổng cộng: ${_users.length} tài khoản trong hệ thống',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _openCreateUserModal,
                    icon: const Icon(Icons.person_add_alt_1, size: 16),
                    label: const Text('Tạo mới', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      elevation: 1,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    height: 36,
                    width: 36,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 18),
                      tooltip: 'Đăng xuất',
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            title: const Text('Đăng xuất', style: TextStyle(fontWeight: FontWeight.bold)),
                            content: const Text('Bạn có chắc chắn muốn đăng xuất khỏi hệ thống?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Hủy', style: TextStyle(color: Color(0xFF64748B))),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFDC2626),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  SessionService().clearSession();
                                  Navigator.pushAndRemoveUntil(
                                    context,
                                    MaterialPageRoute(builder: (_) => const WelcomePage()),
                                    (route) => false,
                                  );
                                },
                                child: const Text('Đăng xuất'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 3. Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Tìm tên, email, MSSV hoặc Mã cán bộ...',
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8), size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Color(0xFF94A3B8), size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _fetchUsers();
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  onChanged: _onSearchChanged,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // 4. Horizontal Filter Chips
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                children: [
                  _buildFilterChip(label: 'Tất cả', roleKey: 'ALL', count: _users.length),
                  const SizedBox(width: 8),
                  _buildFilterChip(label: 'Sinh viên', roleKey: 'STUDENT', count: studentCount),
                  const SizedBox(width: 8),
                  _buildFilterChip(label: 'Giám thị', roleKey: 'LECTURER', count: lecturerCount),
                  const SizedBox(width: 8),
                  _buildFilterChip(label: 'Quản trị', roleKey: 'ADMIN', count: adminCount),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 5. User List
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
                    )
                  : _errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _errorMessage!,
                                style: const TextStyle(color: Color(0xFFDC2626)),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: _fetchUsers,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4F46E5),
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Thử lại'),
                              ),
                            ],
                          ),
                        )
                      : _users.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.search_off_rounded, size: 48, color: Color(0xFFCBD5E1)),
                                  SizedBox(height: 12),
                                  Text(
                                    'Không tìm thấy tài khoản nào',
                                    style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
                              itemCount: _users.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final user = _users[index];
                                return UserCardWidget(
                                  user: user,
                                  onTap: () {
                                    UserActionSheet.show(
                                      context,
                                      user: user,
                                      onUpdateRole: () => _handleUpdateRoleDialog(user),
                                      onToggleStatus: () => _handleToggleStatus(user),
                                      onDelete: () => _handleDeleteUser(user),
                                    );
                                  },
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreateUserModal,
        backgroundColor: const Color(0xFF4F46E5),
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }
}
