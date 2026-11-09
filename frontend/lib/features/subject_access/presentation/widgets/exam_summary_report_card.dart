import 'package:flutter/material.dart';
import '../../../monitoring_reports/presentation/pages/exam_report_detail_page.dart';

class ExamSummaryReportCard extends StatelessWidget {
  final Map<String, dynamic> exam;

  const ExamSummaryReportCard({
    super.key,
    required this.exam,
  });

  @override
  Widget build(BuildContext context) {
    final id = exam['_id'] ?? '';
    final title = exam['exam_title'] ?? 'Ca thi';
    final status = exam['status'] ?? 'DRAFT';
    final subjectName = exam['subject_id']?['subject_name'] ?? '';
    final subjectCode = exam['subject_id']?['subject_code'] ?? '';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFF173A5E),
          child: Icon(
            Icons.analytics_outlined,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          '${subjectCode.isNotEmpty ? "$subjectCode - " : ""}$subjectName\nTrạng thái: ${_statusLabel(status)}',
          style: const TextStyle(fontSize: 12),
        ),
        isThreeLine: true,
        trailing: ElevatedButton.icon(
          icon: const Icon(Icons.bar_chart, size: 16),
          label: const Text(
            'Phổ điểm',
            style: TextStyle(fontSize: 12),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF173A5E),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ExamReportDetailPage(
                  examId: id,
                  examTitle: title,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'DRAFT':
        return 'Bản nháp';
      case 'PUBLISHED':
        return 'Đã công bố';
      case 'ONGOING':
        return 'Đang diễn ra';
      case 'COMPLETED':
        return 'Đã kết thúc';
      default:
        return status;
    }
  }
}
