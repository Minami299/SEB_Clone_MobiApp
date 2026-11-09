import 'package:flutter/material.dart';
import '../../../auth/data/models/user_model.dart';

class UserCardWidget extends StatelessWidget {
  final UserModel user;
  final VoidCallback onTap;

  const UserCardWidget({
    super.key,
    required this.user,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = user.status == 'ACTIVE';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar with status indicator dot
            Stack(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFFEEF2FF),
                  child: Text(
                    user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      color: Color(0xFF4F46E5),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),

            // Information
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          user.fullName,
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildRoleBadge(user.role),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${user.userCode} • ${user.email}',
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Status badge
            _buildStatusBadge(user.status),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    String label = 'Thí sinh';
    Color bg = const Color(0xFFEEF2FF);
    Color text = const Color(0xFF4F46E5);
    Color border = const Color(0xFFC7D2FE);

    switch (role) {
      case 'ADMIN':
        label = 'Quản trị';
        bg = const Color(0xFFFCE7F3);
        text = const Color(0xFFBE185D);
        border = const Color(0xFFFBCFE8);
        break;
      case 'LECTURER':
        label = 'Giám thị';
        bg = const Color(0xFFFEF3C7);
        text = const Color(0xFFB45309);
        border = const Color(0xFFFDE68A);
        break;
      case 'HEAD_OF_SUBJECT':
        label = 'Trưởng bộ môn';
        bg = const Color(0xFFF3E8FF);
        text = const Color(0xFF7E22CE);
        border = const Color(0xFFE9D5FF);
        break;
      case 'STUDENT':
      default:
        label = 'Thí sinh';
        bg = const Color(0xFFEEF2FF);
        text = const Color(0xFF4F46E5);
        border = const Color(0xFFC7D2FE);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border, width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(color: text, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final isActive = status == 'ACTIVE';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isActive ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isActive ? Icons.check : Icons.lock_outline,
            size: 11,
            color: isActive ? const Color(0xFF059669) : const Color(0xFFDC2626),
          ),
          const SizedBox(width: 4),
          Text(
            isActive ? 'Hoạt động' : 'Khóa',
            style: TextStyle(
              color: isActive ? const Color(0xFF059669) : const Color(0xFFDC2626),
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
