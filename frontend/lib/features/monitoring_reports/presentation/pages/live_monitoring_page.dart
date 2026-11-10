import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../exam_execution/data/datasources/exam_remote_datasource.dart';

class StudentViolationGroup {
  final String studentId;
  final String attemptId;
  final String fullName;
  final String userCode;
  final String email;
  final String attemptStatus;
  final List<Map<String, dynamic>> logs;

  StudentViolationGroup({
    required this.studentId,
    required this.attemptId,
    required this.fullName,
    required this.userCode,
    required this.email,
    required this.attemptStatus,
    required this.logs,
  });

  bool get isSuspended =>
      attemptStatus == 'DISQUALIFIED' ||
      attemptStatus == 'SUSPENDED' ||
      logs.length >= 3;
}

class LiveMonitoringPage extends StatefulWidget {
  final String examId;
  final String examTitle;

  const LiveMonitoringPage({
    super.key,
    required this.examId,
    required this.examTitle,
  });

  @override
  State<LiveMonitoringPage> createState() => _LiveMonitoringPageState();
}

class _LiveMonitoringPageState extends State<LiveMonitoringPage> {
  final _dataSource = ExamRemoteDataSource();
  final _apiClient = ApiClient();

  List<dynamic> _violations = [];
  bool _isLoading = true;
  String? _errorMessage;

  int _totalRegistered = 0;
  int _activeInExam = 0;
  List<dynamic> _studentStatuses = [];

  // 0: Tất cả thí sinh (Sĩ số), 1: Thí sinh vi phạm, 2: Nhật ký thời gian thực
  int _selectedViewMode = 0;

  // Set lưu các studentId đang được mở rộng xem timeline
  final Set<String> _expandedStudentIds = {};

  @override
  void initState() {
    super.initState();
    _fetchViolations();
  }

  Future<void> _fetchViolations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _dataSource.getExamViolations(widget.examId);
      if (mounted) {
        final list = data['violations'] as List? ?? [];
        setState(() {
          _violations = list;
          _totalRegistered = (data['total_registered'] as num?)?.toInt() ?? 0;
          _activeInExam = (data['active_in_exam'] as num?)?.toInt() ?? 0;
          _studentStatuses = data['student_statuses'] as List? ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
          _isLoading = false;
        });
      }
    }
  }

  List<StudentViolationGroup> _getGroupedViolations() {
    final Map<String, StudentViolationGroup> groups = {};

    for (var v in _violations) {
      final attempt = v['attempt_id'];
      final student = attempt?['student_id'];
      final studentId =
          student?['_id'] ?? (student?['user_code'] ?? 'unknown_${v['_id']}');
      final attemptId = attempt?['_id'] ?? '';
      final fullName = student?['full_name'] ?? 'Thí sinh';
      final userCode = student?['user_code'] ?? '';
      final email = student?['email'] ?? '';
      final attemptStatus = attempt?['status'] ?? 'IN_PROGRESS';

      if (!groups.containsKey(studentId)) {
        groups[studentId] = StudentViolationGroup(
          studentId: studentId,
          attemptId: attemptId,
          fullName: fullName,
          userCode: userCode,
          email: email,
          attemptStatus: attemptStatus,
          logs: [],
        );
      }
      groups[studentId]!.logs.add(Map<String, dynamic>.from(v));
    }

    return groups.values.toList();
  }

  Future<void> _handleSuspendStudent(StudentViolationGroup group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Đình chỉ thi thí sinh'),
          ],
        ),
        content: Text(
          'Bạn có chắc chắn muốn đình chỉ thi trực tiếp đối với thí sinh:\n\n'
          '• ${group.fullName} (${group.userCode})\n'
          '• Đã ghi nhận ${group.logs.length} lần vi phạm\n\n'
          'Thí sinh sẽ bị kết thúc bài thi ngay lập tức.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Đình chỉ ngay'),
          ),
        ],
      ),
    );

    if (confirmed == true && group.attemptId.isNotEmpty) {
      try {
        await _apiClient.post(
          ApiEndpoints.examForceSuspend(group.attemptId),
          body: {
            'reason': 'PROCTOR_MANUAL_SUSPEND',
            'details':
                'Giám thị chủ động đình chỉ do phát hiện vi phạm an toàn',
          },
        );
        await _fetchViolations();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Đã đình chỉ thí sinh ${group.fullName} thành công.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _handleUnlockStudent(
    String attemptId,
    String studentName,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mở khóa thí sinh'),
        content: Text(
          'Xác nhận mở khóa cho thí sinh "$studentName" để tiếp tục làm bài thi?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xác nhận Mở khóa'),
          ),
        ],
      ),
    );

    if (confirmed == true && attemptId.isNotEmpty) {
      try {
        final res = await _dataSource.unlockAttempt(attemptId);
        if (res['success'] == true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Đã mở khóa thành công cho thí sinh $studentName!',
                ),
                backgroundColor: Colors.green,
              ),
            );
          }
          await _fetchViolations();
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(res['message'] ?? 'Mở khóa thất bại'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _handleDirectSuspend(
    String attemptId,
    String studentName,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đình chỉ thi khẩn cấp'),
        content: Text(
          'Bạn có chắc chắn muốn đình chỉ thí sinh "$studentName"? Thí sinh sẽ bị dừng làm bài ngay lập tức.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Đình chỉ ngay'),
          ),
        ],
      ),
    );

    if (confirmed == true && attemptId.isNotEmpty) {
      try {
        await _dataSource.forceSuspendAttempt(
          attemptId,
          reason: 'PROCTOR_MANUAL_SUSPEND',
        );
        await _fetchViolations();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã đình chỉ thí sinh $studentName thành công.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  String _formatViolationType(String? raw) {
    if (raw == null) return 'Vi phạm an toàn';
    final type = raw.toUpperCase().trim();
    switch (type) {
      case 'APP_UNFOCUSED':
      case 'SCREEN_FOCUS_LOST':
        return 'Chuyển ứng dụng / Mất tiêu điểm';
      case 'APP_MINIMIZED':
        return 'Thoát ra màn hình chính';
      case 'BLOCKED_SHORTCUT':
        return 'Phím tắt đa nhiệm bị chặn';
      case 'SCREENSHOT_ATTEMPT':
        return 'Chụp ảnh màn hình bị chặn';
      case 'FORCE_CLOSE':
        return 'Buộc dừng ứng dụng';
      case 'PROCTOR_DISQUALIFIED':
        return 'Giám thị đình chỉ trực tiếp';
      default:
        return raw.replaceAll('_', ' ');
    }
  }

  String _formatTimeOnly(String? detectedAt) {
    if (detectedAt == null || detectedAt.isEmpty) return '';
    try {
      final dt = DateTime.parse(detectedAt).toLocal();
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      final s = dt.second.toString().padLeft(2, '0');
      return '$h:$m:$s';
    } catch (_) {
      return detectedAt;
    }
  }

  String _formatDateOnly(String? detectedAt) {
    if (detectedAt == null || detectedAt.isEmpty) return '';
    try {
      final dt = DateTime.parse(detectedAt).toLocal();
      final d = dt.day.toString().padLeft(2, '0');
      final mo = dt.month.toString().padLeft(2, '0');
      final y = dt.year.toString();
      return '$d/$mo/$y';
    } catch (_) {
      return '';
    }
  }

  String _formatDateTime(String? detectedAt) {
    if (detectedAt == null || detectedAt.isEmpty) return '';
    try {
      final dt = DateTime.parse(detectedAt).toLocal();
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      final s = dt.second.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      final mo = dt.month.toString().padLeft(2, '0');
      final y = dt.year.toString();
      return '$h:$m:$s $d/$mo/$y';
    } catch (_) {
      return detectedAt;
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups = _getGroupedViolations();
    final totalViolations = _violations.length;
    final totalViolatingStudents = groups.length;
    final suspendedCount = groups.where((g) => g.isSuspended).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Giám sát phòng thi',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              widget.examTitle,
              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // 1. Thẻ tóm tắt 3 chỉ số vi phạm trên cùng (Clean Navy Metric Card)
          Container(
            color: const Color(0xFF0F172A),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Row(
                children: [
                  _buildMetricColumn(
                    label: 'Sĩ số vào thi',
                    value: '$_activeInExam/$_totalRegistered',
                    color: _activeInExam > 0
                        ? const Color(0xFF60A5FA)
                        : const Color(0xFF94A3B8),
                    icon: Icons.people_outline,
                  ),
                  _buildMetricDivider(),
                  _buildMetricColumn(
                    label: 'Tổng vi phạm',
                    value: '$totalViolations',
                    color: totalViolations > 0
                        ? const Color(0xFFF87171)
                        : const Color(0xFF34D399),
                    icon: Icons.warning_amber_rounded,
                  ),
                  _buildMetricDivider(),
                  _buildMetricColumn(
                    label: 'Thí sinh vi phạm',
                    value: '$totalViolatingStudents',
                    color: totalViolatingStudents > 0
                        ? const Color(0xFFFBBF24)
                        : const Color(0xFF34D399),
                    icon: Icons.person_off_outlined,
                  ),
                  _buildMetricDivider(),
                  _buildMetricColumn(
                    label: 'Đã đình chỉ',
                    value: '$suspendedCount',
                    color: suspendedCount > 0
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF94A3B8),
                    icon: Icons.lock_person_outlined,
                  ),
                ],
              ),
            ),
          ),

          // 2. Chuyển đổi 3 chế độ xem: Tất cả thí sinh vs Vi phạm vs Dòng sự kiện
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _selectedViewMode = 0),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _selectedViewMode == 0
                            ? const Color(0xFF1E3A5F)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Tất cả (${_studentStatuses.length})',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _selectedViewMode == 0
                              ? Colors.white
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _selectedViewMode = 1),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _selectedViewMode == 1
                            ? const Color(0xFF1E3A5F)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Vi phạm (${groups.length})',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _selectedViewMode == 1
                              ? Colors.white
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _selectedViewMode = 2),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _selectedViewMode == 2
                            ? const Color(0xFF1E3A5F)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Dòng sự kiện (${_violations.length})',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _selectedViewMode == 2
                              ? Colors.white
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

          // 3. Nội dung danh sách
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _fetchViolations,
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  )
                : _selectedViewMode == 0
                ? _buildAllCandidatesList()
                : _selectedViewMode == 1
                ? (groups.isEmpty
                      ? _buildNoViolationState()
                      : _buildGroupedByStudentList(groups))
                : (_violations.isEmpty
                      ? _buildNoViolationState()
                      : _buildLiveTimelineList()),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricColumn({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricDivider() {
    return Container(width: 1, height: 28, color: const Color(0xFF334155));
  }

  // Danh sách Toàn bộ Thí sinh trong ca thi (Theo dõi sĩ số, trạng thái kết nối & đình chỉ/mở khóa)
  Widget _buildAllCandidatesList() {
    if (_studentStatuses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.people_outline,
              size: 56,
              color: Color(0xFF94A3B8),
            ),
            const SizedBox(height: 12),
            const Text(
              'Chưa có dữ liệu danh sách thí sinh',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Thí sinh được phân công vào ca thi sẽ hiển thị tại đây.',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _studentStatuses.length,
      itemBuilder: (context, index) {
        final stu = _studentStatuses[index];
        final name = stu['full_name'] ?? 'Thí sinh';
        final code = stu['user_code'] ?? '';
        final status = stu['status'] ?? 'NOT_STARTED';
        final attemptId = stu['attempt_id']?.toString() ?? '';
        final vCount = stu['violation_count'] ?? 0;

        Color statusColor;
        Color statusBg;
        String statusLabel;
        IconData statusIcon;

        if (status == 'IN_PROGRESS') {
          statusColor = const Color(0xFF047857);
          statusBg = const Color(0xFFECFDF5);
          statusLabel = 'Đang làm bài';
          statusIcon = Icons.laptop_chromebook;
        } else if (status == 'SUBMITTED') {
          statusColor = const Color(0xFF1D4ED8);
          statusBg = const Color(0xFFEFF6FF);
          statusLabel = 'Đã nộp bài';
          statusIcon = Icons.task_alt;
        } else if (status == 'DISQUALIFIED' || status == 'SUSPENDED') {
          statusColor = const Color(0xFFDC2626);
          statusBg = const Color(0xFFFEF2F2);
          statusLabel = 'Bị đình chỉ';
          statusIcon = Icons.block;
        } else {
          statusColor = const Color(0xFFD97706);
          statusBg = const Color(0xFFFFFBEB);
          statusLabel = 'Chưa vào thi';
          statusIcon = Icons.hourglass_empty;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: status == 'DISQUALIFIED' || status == 'SUSPENDED'
                  ? const Color(0xFFFECACA)
                  : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: statusBg,
                radius: 20,
                child: Icon(statusIcon, color: statusColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: statusColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          'MSSV: $code',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (vCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '$vCount vi phạm',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFDC2626),
                              ),
                            ),
                          ),
                        ],
                        if (stu['started_at'] != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            '• Vào thi: ${_formatDateTime(stu['started_at'])}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (status == 'IN_PROGRESS' && attemptId.isNotEmpty) ...[
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => _handleDirectSuspend(attemptId, name),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFFECACA)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text(
                    'Đình chỉ',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
              if ((status == 'DISQUALIFIED' || status == 'SUSPENDED') &&
                  attemptId.isNotEmpty) ...[
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _handleUnlockStudent(attemptId, name),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text(
                    'Mở khóa',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildNoViolationState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 56, color: Color(0xFF10B981)),
          SizedBox(height: 12),
          Text(
            'Chưa ghi nhận vi phạm an toàn nào',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Color(0xFF1E293B),
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Tất cả thí sinh đang tuân thủ tốt quy chế phòng thi',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  // Danh sách Gom nhóm theo Sinh viên (UX chuẩn giám sát)
  Widget _buildGroupedByStudentList(List<StudentViolationGroup> groups) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: groups.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final g = groups[index];
        final isExpanded = _expandedStudentIds.contains(g.studentId);
        final initial = g.fullName.isNotEmpty
            ? g.fullName.trim()[0].toUpperCase()
            : 'S';
        final latestLog = g.logs.isNotEmpty ? g.logs.first : null;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: g.isSuspended
                  ? const Color(0xFFFCA5A5)
                  : const Color(0xFFE2E8F0),
              width: g.isSuspended ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: g.isSuspended
                    ? const Color(0xFFEF4444).withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedStudentIds.remove(g.studentId);
                } else {
                  _expandedStudentIds.add(g.studentId);
                }
              });
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Thẻ Thí sinh
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      // Avatar
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: g.isSuspended
                            ? const Color(0xFFFEF2F2)
                            : const Color(0xFFEFF6FF),
                        child: Text(
                          initial,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: g.isSuspended
                                ? const Color(0xFFDC2626)
                                : const Color(0xFF1D4ED8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Tên & Mã SV
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              g.fullName,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              g.userCode.isNotEmpty
                                  ? 'Mã SV: ${g.userCode}'
                                  : g.email,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Badge Trạng thái
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: g.isSuspended
                              ? const Color(0xFFFEF2F2)
                              : const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: g.isSuspended
                                ? const Color(0xFFFECACA)
                                : const Color(0xFFFED7AA),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              g.isSuspended
                                  ? Icons.lock
                                  : Icons.warning_amber_rounded,
                              size: 13,
                              color: g.isSuspended
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFFEA580C),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              g.isSuspended
                                  ? 'ĐÃ ĐÌNH CHỈ'
                                  : '${g.logs.length} VI PHẠM',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: g.isSuspended
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFFEA580C),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0xFFF1F5F9),
                ),

                // Tóm tắt vi phạm gần nhất & gợi ý ấn vào xem chi tiết
                if (latestLog != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _formatDateTime(latestLog['detected_at']),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _formatViolationType(latestLog['violation_type']),
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF334155),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              isExpanded
                                  ? 'Đóng'
                                  : 'Xem chi tiết (${g.logs.length})',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF2563EB),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Icon(
                              isExpanded
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              size: 16,
                              color: const Color(0xFF2563EB),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                // Timeline chi tiết từng lần vi phạm (khi mở rộng)
                if (isExpanded) ...[
                  Container(
                    color: const Color(0xFFF8FAFC),
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'LỊCH SỬ VI PHẠM CỦA THÍ SINH:',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF64748B),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...g.logs.asMap().entries.map((entry) {
                          final i = entry.key;
                          final log = entry.value;
                          final reverseIndex = g.logs.length - i;
                          final time = _formatDateTime(log['detected_at']);
                          final type = _formatViolationType(
                            log['violation_type'],
                          );
                          final details = log['violation_details'] ?? '';

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFEE2E2),
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '$reverseIndex',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFDC2626),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            time,
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              type,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFFDC2626),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (details.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          details,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF64748B),
                                            height: 1.3,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],

                // Footer: Nút hành động giám thị
                if (!g.isSuspended) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _handleSuspendStudent(g),
                        icon: const Icon(
                          Icons.block,
                          size: 15,
                          color: Color(0xFFDC2626),
                        ),
                        label: const Text(
                          'Đình chỉ thi thí sinh này',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFFECACA)),
                          backgroundColor: const Color(0xFFFEF2F2),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // Danh sách Dòng sự kiện thời gian thực (Live Stream)
  Widget _buildLiveTimelineList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _violations.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final v = _violations[index];
        final student = v['attempt_id']?['student_id'];
        final studentName = student?['full_name'] ?? 'Thí sinh';
        final studentCode = student?['user_code'] ?? '';
        final violationType = v['violation_type'] ?? '';
        final details = v['violation_details'] ?? '';
        final timeStr = _formatTimeOnly(v['detected_at']);
        final dateStr = _formatDateOnly(v['detected_at']);

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      timeStr,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    if (dateStr.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        dateStr,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$studentName ($studentCode)',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _formatViolationType(violationType),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                    if (details.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        details,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
