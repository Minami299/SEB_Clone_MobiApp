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
    final isPublished = exam.status == 'PUBLISHED';
    final subjectLabel = exam.subjectCode.isNotEmpty ? exam.subjectCode : 'SEB EXAM';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPublished ? const Color(0xFF10B981).withOpacity(0.5) : const Color(0xFFE2E8F0),
          width: isPublished ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isPublished
                ? const Color(0xFF10B981).withOpacity(0.06)
                : Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Subject badge & Status badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  subjectLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1D4ED8),
                  ),
                ),
              ),
              _buildStatusBadge(exam.status),
            ],
          ),

          const SizedBox(height: 10),

          // Row 2: Exam Title
          Text(
            exam.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
              height: 1.3,
            ),
          ),

          if (exam.description != null && exam.description!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              exam.description!,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          const SizedBox(height: 12),

          // Row 3: Metadata chips (Thời lượng, Số lỗi, PIN)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Row(
              children: [
                _buildInfoItem(
                  icon: Icons.schedule,
                  label: '${exam.durationMinutes} phút',
                ),
                const SizedBox(width: 14),
                _buildInfoItem(
                  icon: Icons.shield_outlined,
                  label: 'Tối đa ${exam.maxViolations} vi phạm',
                ),
                if (exam.accessPin != null && exam.accessPin!.isNotEmpty && isProctor) ...[
                  const Spacer(),
                  _buildInfoItem(
                    icon: Icons.pin_outlined,
                    label: 'PIN: ${exam.accessPin}',
                    isHighlight: true,
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Row 4: Actions (Proctor buttons / Student Enter button)
          if (isProctor) ...[
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20, color: Color(0xFF1E3A5F)),
                  tooltip: 'Sửa ca thi',
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F5F9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    final updated = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(builder: (_) => CreateEditExamPage(examId: exam.id)),
                    );
                    if (updated == true) onRefresh();
                  },
                ),
                const SizedBox(width: 6),
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
                  label: const Text('Báo cáo', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    foregroundColor: const Color(0xFF1E3A5F),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
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
                  icon: const Icon(Icons.monitor_heart_outlined, size: 16),
                  label: const Text('Giám sát', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    foregroundColor: const Color(0xFF1E3A5F),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: onEnterExam,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A5F),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  icon: const Icon(Icons.login, size: 16),
                  label: const Text('Vào ca', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: isPublished ? onEnterExam : null,
                icon: Icon(isPublished ? Icons.play_arrow : Icons.lock_outline, size: 18),
                label: Text(
                  isPublished ? 'VÀO LÀM BÀI THI' : 'CHƯA TỚI GIỜ MỞ CA',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isPublished ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                  foregroundColor: isPublished ? Colors.white : const Color(0xFF94A3B8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: isPublished ? 2 : 0,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    if (status == 'PUBLISHED') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF10B981)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(radius: 3, backgroundColor: Color(0xFF10B981)),
            SizedBox(width: 5),
            Text(
              'Đang diễn ra',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF047857),
              ),
            ),
          ],
        ),
      );
    }

    if (status == 'DRAFT') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFF59E0B)),
        ),
        child: const Text(
          'Bản nháp',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Color(0xFFB45309),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Color(0xFF475569),
        ),
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    bool isHighlight = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: isHighlight ? const Color(0xFF2563EB) : const Color(0xFF64748B)),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
            color: isHighlight ? const Color(0xFF1E3A8A) : const Color(0xFF475569),
          ),
        ),
      ],
    );
  }
}
