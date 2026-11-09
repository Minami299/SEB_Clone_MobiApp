import 'package:flutter/material.dart';
import '../../../auth/data/models/user_model.dart';

class UserActionSheet extends StatelessWidget {
  final UserModel user;
  final VoidCallback onUpdateRole;
  final VoidCallback onToggleStatus;
  final VoidCallback onDelete;

  const UserActionSheet({
    super.key,
    required this.user,
    required this.onUpdateRole,
    required this.onToggleStatus,
    required this.onDelete,
  });

  static Future<void> show(
    BuildContext context, {
    required UserModel user,
    required VoidCallback onUpdateRole,
    required VoidCallback onToggleStatus,
    required VoidCallback onDelete,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => UserActionSheet(
        user: user,
        onUpdateRole: onUpdateRole,
        onToggleStatus: onToggleStatus,
        onDelete: onDelete,
      ),
    );
  }

  String _getRoleDisplayName(String role) {
    switch (role) {
      case 'ADMIN':
        return 'Quản trị viên';
      case 'LECTURER':
        return 'Giám thị / Giảng viên';
      case 'HEAD_OF_SUBJECT':
        return 'Trưởng bộ môn';
      case 'STUDENT':
      default:
        return 'Thí sinh / Sinh viên';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isActive = user.status == 'ACTIVE';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFFEEF2FF),
                  child: Text(
                    user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'U',
                    style: const TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.fullName,
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${user.userCode} • ${user.email}',
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(color: Color(0xFFF1F5F9), height: 28),
            ListTile(
              leading: const Icon(Icons.badge_outlined, color: Color(0xFF4F46E5)),
              title: const Text('Phân lại vai trò', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600)),
              subtitle: Text(
                'Hiện tại: ${_getRoleDisplayName(user.role)}',
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(context);
                onUpdateRole();
              },
            ),
            ListTile(
              leading: Icon(
                isActive ? Icons.lock_outline : Icons.lock_open_outlined,
                color: isActive ? const Color(0xFFD97706) : const Color(0xFF059669),
              ),
              title: Text(
                isActive ? 'Khóa tài khoản này' : 'Mở khóa tài khoản',
                style: TextStyle(
                  color: isActive ? const Color(0xFFD97706) : const Color(0xFF059669),
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                isActive
                    ? 'Chuyển trạng thái sang Khóa (INACTIVE)'
                    : 'Kích hoạt lại tài khoản (ACTIVE)',
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(context);
                onToggleStatus();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
              title: const Text('Xóa tài khoản', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w600)),
              subtitle: const Text(
                'Hành động này không thể hoàn tác',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(context);
                onDelete();
              },
            ),
          ],
        ),
      ),
    );
  }
}
