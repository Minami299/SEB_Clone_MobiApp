import 'package:flutter/material.dart';

class ViolationHistoryList extends StatelessWidget {
  final List<dynamic> violations;

  const ViolationHistoryList({
    super.key,
    required this.violations,
  });

  String _formatViolationType(String? type) {
    switch (type) {
      case 'APP_UNFOCUSED':
        return 'Mất tiêu điểm màn hình thi';
      case 'APP_MINIMIZED':
        return 'Thoát ứng dụng về màn hình Home';
      case 'BLOCKED_SHORTCUT':
        return 'Mở danh sách ứng dụng gần đây (Recent Apps)';
      case 'SCREENSHOT_ATTEMPT':
        return 'Cố gắng chụp hoặc quay màn hình';
      case 'FORCE_CLOSE':
        return 'Tắt ứng dụng đột ngột';
      case 'PROCTOR_DISQUALIFIED':
        return 'Giám thị trực tiếp đình chỉ thi';
      default:
        return type ?? 'Vi phạm quy chế thi';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (violations.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: const Text(
          'Hệ thống phát hiện thiết bị vượt quá ngưỡng vi phạm quy chế an toàn thi trực tuyến hoặc bị giám thị ra lệnh đình chỉ.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Color(0xFF991B1B), height: 1.4),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Lịch sử các lần vi phạm được ghi nhận:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF991B1B)),
        ),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(maxHeight: 180),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.all(8),
            itemCount: violations.length,
            separatorBuilder: (context, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final v = violations[index];
              final type = v['type'] ?? v['violation_type'];
              final time = v['time'] != null
                  ? DateTime.tryParse(v['time'].toString())?.toLocal().toString().substring(11, 19)
                  : 'Vừa xong';

              return ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                leading: Text(
                  '#${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                ),
                title: Text(
                  _formatViolationType(type),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                ),
                trailing: Text(
                  time ?? '',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
