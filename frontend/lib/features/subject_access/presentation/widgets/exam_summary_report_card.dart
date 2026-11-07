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
    final pin = exam['access_pin'] ?? exam['exam_pin'] ?? '';
    final subjectName = exam['subject_id']?['subject_name'] ?? '';
    final subjectCode = exam['subject_id']?['subject_code'] ?? '';

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFF1E3A5F),
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
          '${subjectCode.isNotEmpty ? "$subjectCode - " : ""}$subjectName\nTrạng thái: $status | PIN: $pin',
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
            backgroundColor: const Color(0xFF1E3A5F),
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
}
