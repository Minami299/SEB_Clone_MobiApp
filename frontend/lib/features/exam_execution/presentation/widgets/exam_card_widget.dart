import 'package:flutter/material.dart';
import '../../data/models/exam_model.dart';
import '../../../exam_management/presentation/pages/create_edit_exam_page.dart';
import '../../../monitoring_reports/presentation/pages/live_monitoring_page.dart';
import '../../../monitoring_reports/presentation/pages/exam_report_detail_page.dart';

class ExamCardWidget extends StatelessWidget {
  final ExamModel exam;
  final bool isProctor;
  final VoidCallback onEnterExam;
  final VoidCallback onRefresh;

  const ExamCardWidget({
    super.key,
    required this.exam,
    required this.isProctor,
    required this.onEnterExam,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    exam.title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: exam.status == 'PUBLISHED'
                        ? Colors.green[50]
                        : Colors.orange[50],
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: exam.status == 'PUBLISHED'
                          ? Colors.green
                          : Colors.orange,
                    ),
                  ),
                  child: Text(
                    exam.status,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: exam.status == 'PUBLISHED'
                          ? Colors.green[800]
                          : Colors.orange[800],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Thời lượng: ${exam.durationMinutes} phút | Số lỗi tối đa: ${exam.maxViolations}',
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
            if (exam.description != null && exam.description!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                exam.description!,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isProctor) ...[
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20, color: Color(0xFF1E3A5F)),
                    tooltip: 'Sửa ca thi',
                    onPressed: () async {
                      final updated = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(builder: (_) => CreateEditExamPage(examId: exam.id)),
                      );
                      if (updated == true) onRefresh();
                    },
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ExamReportDetailPage(
                            examId: exam.id,
                            examTitle: exam.title,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.analytics_outlined, size: 16),
                    label: const Text('Báo cáo'),
                  ),
                  const SizedBox(width: 6),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LiveMonitoringPage(
                            examId: exam.id,
                            examTitle: exam.title,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.monitor_heart, size: 18),
                    label: const Text('Giám sát'),
                  ),
                  const SizedBox(width: 6),
                ],
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: onEnterExam,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text('Vào làm bài'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
