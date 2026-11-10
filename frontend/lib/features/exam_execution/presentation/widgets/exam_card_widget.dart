import 'package:flutter/material.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../domain/entities/exam_entity.dart';
import '../../../exam_management/presentation/pages/create_edit_exam_page.dart';
import '../../../monitoring_reports/presentation/pages/live_monitoring_page.dart';
import '../../../monitoring_reports/presentation/pages/exam_report_detail_page.dart';

class ExamCardWidget extends StatelessWidget {
  final ExamEntity exam;
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

  Future<void> _handleToggleStatus(BuildContext context) async {
    final s = exam.status.toUpperCase().trim();
    final isCurrentlyOpen = (s == 'PUBLISHED' || s == 'ONGOING' || s == 'IN_PROGRESS' || s == 'ACTIVE');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isCurrentlyOpen ? Icons.stop_circle_outlined : Icons.play_circle_outline,
              color: isCurrentlyOpen ? Colors.red : const Color(0xFF10B981),
            ),
            const SizedBox(width: 8),
            Text(isCurrentlyOpen ? 'Kết thúc ca thi' : 'Mở lại ca thi'),
          ],
        ),
        content: Text(
          isCurrentlyOpen
              ? 'Bạn có chắc chắn muốn kết thúc ca thi "${exam.title}" không?\n\nSau khi kết thúc, sinh viên sẽ không thể vào làm bài được nữa. Trạng thái ca thi sẽ chuyển thành "Đã kết thúc".'
              : 'Bạn có muốn mở lại ca thi "${exam.title}" để sinh viên có thể tiếp tục vào thi không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isCurrentlyOpen ? Colors.red : const Color(0xFF10B981),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isCurrentlyOpen ? 'Kết thúc ca thi' : 'Mở ca thi'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final apiClient = ApiClient();
        if (isCurrentlyOpen) {
          await apiClient.patch(ApiEndpoints.examClose(exam.id));
        } else {
          await apiClient.patch(ApiEndpoints.examPublish(exam.id));
        }
        onRefresh();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isCurrentlyOpen ? 'Đã kết thúc ca thi thành công.' : 'Đã mở lại ca thi thành công.'),
              backgroundColor: isCurrentlyOpen ? Colors.orange : Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = exam.status.toUpperCase().trim();
    final isPublished = (s == 'PUBLISHED' || s == 'ONGOING' || s == 'IN_PROGRESS' || s == 'ACTIVE');
    final isEnded = (s == 'ENDED' || s == 'COMPLETED' || s == 'CLOSED');
    final subjectLabel = exam.subjectCode.isNotEmpty ? exam.subjectCode : 'SEB EXAM';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPublished
              ? const Color(0xFF10B981).withValues(alpha: 0.5)
              : const Color(0xFFE2E8F0),
          width: isPublished ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isPublished
                ? const Color(0xFF10B981).withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Subject badge, Edit button (nếu là Giám thị) & Status badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildStatusBadge(exam.status),
                  if (isProctor && !isEnded) ...[
                    const SizedBox(width: 6),
                    // Nút Sửa ca thi (Chỉ cho sửa khi chưa kết thúc ca thi)
                    Tooltip(
                      message: 'Chỉnh sửa ca thi',
                      child: InkWell(
                        onTap: () async {
                          final updated = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(builder: (_) => CreateEditExamPage(examId: exam.id)),
                          );
                          if (updated == true) onRefresh();
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF1E3A5F)),
                        ),
                      ),
                    ),
                    if (isPublished) ...[
                      const SizedBox(width: 6),
                      // Nút Kết thúc ca thi (Chỉ hiện khi ca đang mở)
                      Tooltip(
                        message: 'Kết thúc ca thi',
                        child: InkWell(
                          onTap: () => _handleToggleStatus(context),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFFECACA)),
                            ),
                            child: const Icon(
                              Icons.power_settings_new,
                              size: 16,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
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
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          const SizedBox(height: 12),

          // Row 3: Metadata chips (Thời lượng, Số lỗi, Giờ bắt đầu)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Wrap(
              spacing: 14,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildInfoItem(
                  icon: Icons.schedule,
                  label: '${exam.durationMinutes} phút',
                ),
                _buildInfoItem(
                  icon: Icons.shield_outlined,
                  label: 'Tối đa ${exam.maxViolations} lỗi',
                ),
                if (exam.startTime != null)
                  _buildInfoItem(
                    icon: Icons.event_note_outlined,
                    label: _formatDateTime(exam.startTime!),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Row 4: Actions (Thao tác cho Giám thị / Nút Vào thi cho Sinh viên)
          if (isProctor) ...[
            if (isEnded) ...[
              // Khi ca thi Đã kết thúc: hiện nút Xem báo cáo & Nhật ký giám sát
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: ElevatedButton.icon(
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
                      label: const Text('Xem Báo cáo & Điểm thi', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A5F),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: OutlinedButton.icon(
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
                      icon: const Icon(Icons.history_edu, size: 16),
                      label: const Text('Nhật ký', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        foregroundColor: const Color(0xFF1E3A5F),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Khi ca thi đang mở hoặc bản nháp: Hiện nút Báo cáo, Giám sát
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
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
                      label: const Text('Báo cáo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        foregroundColor: const Color(0xFF1E3A5F),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
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
                      label: const Text('Giám sát', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        foregroundColor: const Color(0xFF1E3A5F),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ] else ...[
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: isPublished ? onEnterExam : null,
                icon: Icon(
                  isPublished ? Icons.play_arrow : Icons.lock_outline,
                  size: 18,
                ),
                label: Text(
                  isPublished
                      ? 'VÀO LÀM BÀI THI'
                      : (s == 'COMPLETED' || s == 'ENDED' ? 'CA THI ĐÃ KẾT THÚC' : 'CHƯA TỚI GIỜ MỞ CA'),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isPublished
                      ? const Color(0xFF10B981)
                      : const Color(0xFFE2E8F0),
                  foregroundColor: isPublished
                      ? Colors.white
                      : const Color(0xFF94A3B8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
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
    final s = status.toUpperCase().trim();

    // 1. Đang diễn ra
    if (s == 'PUBLISHED' || s == 'ONGOING' || s == 'IN_PROGRESS' || s == 'ACTIVE') {
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

    // 2. Bản nháp
    if (s == 'DRAFT') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: const Text(
          'Bản nháp',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Color(0xFF475569),
          ),
        ),
      );
    }

    // 3. Sắp diễn ra
    if (s == 'UPCOMING' || s == 'SCHEDULED') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF3B82F6)),
        ),
        child: const Text(
          'Sắp diễn ra',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1D4ED8),
          ),
        ),
      );
    }

    // 4. Đã kết thúc
    if (s == 'ENDED' || s == 'COMPLETED' || s == 'CLOSED') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFEF4444)),
        ),
        child: const Text(
          'Đã kết thúc',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Color(0xFFB91C1C),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final mo = local.month.toString().padLeft(2, '0');
    final y = local.year.toString();
    return '$h:$m $d/$mo/$y';
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    bool isHighlight = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 15,
          color: isHighlight
              ? const Color(0xFF2563EB)
              : const Color(0xFF64748B),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
            color: isHighlight
                ? const Color(0xFF1E3A8A)
                : const Color(0xFF475569),
          ),
        ),
      ],
    );
  }
}
