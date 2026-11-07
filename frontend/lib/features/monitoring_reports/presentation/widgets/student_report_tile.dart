import 'package:flutter/material.dart';

class StudentReportTile extends StatelessWidget {
  final Map<String, dynamic> student;

  const StudentReportTile({
    super.key,
    required this.student,
  });

  @override
  Widget build(BuildContext context) {
    final status = student['status'] ?? 'NOT_STARTED';
    final isDisqualified = status == 'DISQUALIFIED' || status == 'SUSPENDED';
    final isSubmitted = status == 'SUBMITTED';

    Color statusColor = Colors.grey;
    String statusText = 'Chưa thi';
    if (isSubmitted) {
      statusColor = student['is_passed'] == true ? Colors.green : Colors.orange;
      statusText = student['is_passed'] == true ? 'Đạt' : 'Trượt';
    } else if (isDisqualified) {
      statusColor = Colors.red;
      statusText = 'Đình chỉ';
    } else if (status == 'IN_PROGRESS') {
      statusColor = Colors.blue;
      statusText = 'Đang thi';
    }

    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: ListTile(
        dense: true,
        title: Text(
          student['full_name'] ?? '',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          '${student['user_code']} | Vi phạm: ${student['violation_count'] ?? 0} lần',
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSubmitted && student['score'] != null)
              Text(
                '${student['score']} đ',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: student['is_passed'] == true ? Colors.green : Colors.red,
                ),
              ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withAlpha(25),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: statusColor),
              ),
              child: Text(
                statusText,
                style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
