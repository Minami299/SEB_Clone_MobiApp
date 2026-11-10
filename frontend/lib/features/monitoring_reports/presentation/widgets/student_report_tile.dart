import 'package:flutter/material.dart';

class StudentReportTile extends StatelessWidget {
  final Map<String, dynamic> student;
  final VoidCallback? onTap;

  const StudentReportTile({super.key, required this.student, this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = (student['status'] ?? 'NOT_STARTED')
        .toString()
        .toUpperCase();
    final isDisqualified = status == 'DISQUALIFIED' || status == 'SUSPENDED';
    final isSubmitted = status == 'SUBMITTED';

    final fullName = student['full_name'] ?? 'Sinh viên';
    final initial = fullName.trim().isNotEmpty
        ? fullName.trim().split(' ').last[0].toUpperCase()
        : 'S';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDisqualified
                ? const Color(0xFFFECACA)
                : const Color(0xFFE2E8F0),
            width: isDisqualified ? 1.2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            // CircleAvatar thí sinh
            CircleAvatar(
              radius: 20,
              backgroundColor: isDisqualified
                  ? const Color(0xFFFEE2E2)
                  : const Color(0xFFEFF6FF),
              child: Text(
                initial,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: isDisqualified
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF1D4ED8),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Thông tin sinh viên
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fullName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        '${student['user_code'] ?? ""}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Text(
                        ' • ',
                        style: TextStyle(color: Color(0xFF94A3B8)),
                      ),
                      Text(
                        'Vi phạm: ${student['violation_count'] ?? 0} lần',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: (student['violation_count'] ?? 0) > 0
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: (student['violation_count'] ?? 0) > 0
                              ? const Color(0xFFDC2626)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Điểm và Trạng thái
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSubmitted && student['score'] != null) ...[
                  Text(
                    '${student['score']} đ',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: student['is_passed'] == true
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                _buildStatusBadge(isDisqualified, isSubmitted, status),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: Color(0xFF94A3B8),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(
    bool isDisqualified,
    bool isSubmitted,
    String status,
  ) {
    if (isDisqualified) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFFCA5A5)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 12, color: Color(0xFFDC2626)),
            SizedBox(width: 4),
            Text(
              'Đã đình chỉ',
              style: TextStyle(
                color: Color(0xFFDC2626),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    if (isSubmitted) {
      final isPassed = student['is_passed'] == true;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isPassed ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isPassed ? const Color(0xFF10B981) : const Color(0xFFEF4444),
          ),
        ),
        child: Text(
          isPassed ? 'Đạt' : 'Trượt',
          style: TextStyle(
            color: isPassed ? const Color(0xFF047857) : const Color(0xFFB91C1C),
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    if (status == 'IN_PROGRESS') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF3B82F6)),
        ),
        child: const Text(
          'Đang thi',
          style: TextStyle(
            color: Color(0xFF1D4ED8),
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: const Text(
        'Chưa thi',
        style: TextStyle(
          color: Color(0xFF475569),
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
