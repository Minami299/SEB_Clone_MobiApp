import 'package:flutter/material.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../exam_execution/data/datasources/exam_remote_datasource.dart';
import '../widgets/report_metric_card.dart';
import '../widgets/score_histogram_widget.dart';
import '../widgets/student_report_tile.dart';

class ExamReportDetailPage extends StatefulWidget {
  final String examId;
  final String? examTitle;

  const ExamReportDetailPage({
    super.key,
    required this.examId,
    this.examTitle,
  });

  @override
  State<ExamReportDetailPage> createState() => _ExamReportDetailPageState();
}

class _ExamReportDetailPageState extends State<ExamReportDetailPage> {
  final _apiClient = ApiClient();
  final _examDataSource = ExamRemoteDataSource();

  Map<String, dynamic>? _reportData;
  bool _isLoading = true;
  String? _errorMessage;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchStatistics();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchStatistics() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _apiClient.get(ApiEndpoints.examStatistics(widget.examId));
      if (response['success'] == true && response['data'] != null) {
        if (mounted) {
          setState(() {
            _reportData = response['data'] as Map<String, dynamic>;
            _isLoading = false;
          });
        }
      } else {
        throw Exception(response['message'] ?? 'Không thể tải báo cáo thống kê');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(widget.examTitle ?? 'Báo cáo & Phổ điểm Ca thi', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0.5,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _fetchStatistics, child: const Text('Thử lại')),
                    ],
                  ),
                )
              : _reportData == null
                  ? const Center(child: Text('Không có dữ liệu báo cáo'))
                  : _buildReportContent(),
    );
  }

  Widget _buildReportContent() {
    final summary = _reportData!['summary'] as Map<String, dynamic>? ?? {};
    final histogram = _reportData!['histogram'] as Map<String, dynamic>? ?? {};
    final students = _reportData!['students'] as List? ?? [];

    final query = _searchController.text.trim().toLowerCase();
    final filteredStudents = students.where((s) {
      final name = (s['full_name'] ?? '').toString().toLowerCase();
      final code = (s['user_code'] ?? '').toString().toLowerCase();
      return query.isEmpty || name.contains(query) || code.contains(query);
    }).toList();

    final submitted = summary['submitted_count'] ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: 3 Thẻ thống kê căn bằng nhau trên 1 hàng (Đăng ký | Đã nộp | Đình chỉ)
          Row(
            children: [
              Expanded(
                child: ReportMetricCard(
                  label: 'Đăng ký',
                  value: '${summary['total_registered'] ?? 0}',
                  color: const Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ReportMetricCard(
                  label: 'Đã nộp',
                  value: '$submitted',
                  color: const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ReportMetricCard(
                  label: 'Đình chỉ',
                  value: '${summary['suspended_count'] ?? 0}',
                  color: const Color(0xFFEF4444),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Row 2: Card Tổng quan Điểm số & Tỷ lệ Đạt (Gồm Vòng tròn tiến trình + 3 thông số điểm)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
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
                // Vòng tròn tiến trình Tỷ lệ Đạt
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 58,
                      height: 58,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: ((summary['pass_rate'] ?? 0) as num).toDouble() / 100.0,
                            strokeWidth: 6,
                            backgroundColor: const Color(0xFFF1F5F9),
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                          ),
                          Text(
                            '${summary['pass_rate'] ?? 0}%',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Tỷ lệ Đạt',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                    ),
                  ],
                ),

                const SizedBox(width: 16),
                const SizedBox(height: 60, child: VerticalDivider(color: Color(0xFFE2E8F0))),
                const SizedBox(width: 12),

                // 3 cột điểm: Điểm TB | Cao nhất | Thấp nhất
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      ScoreMiniCard(
                        label: 'Điểm TB',
                        value: '${summary['average_score'] ?? 0} đ',
                        color: const Color(0xFF1E3A5F),
                      ),
                      ScoreMiniCard(
                        label: 'Cao nhất',
                        value: '${summary['highest_score'] ?? 0} đ',
                        color: const Color(0xFF10B981),
                      ),
                      ScoreMiniCard(
                        label: 'Thấp nhất',
                        value: '${summary['lowest_score'] ?? 0} đ',
                        color: const Color(0xFFF59E0B),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Visual Histogram (Extracted)
          const Text(
            'Phổ điểm ca thi (Score Distribution):',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 10),

          ScoreHistogramWidget(
            histogram: histogram,
            totalSubmitted: submitted,
          ),

          const SizedBox(height: 20),

          // Student List Header & Search
          Text(
            'Danh sách thí sinh (${filteredStudents.length}):',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 8),

          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Tìm kiếm thí sinh theo tên, mã SV...',
              prefixIcon: const Icon(Icons.search, size: 18),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    )
                  : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              filled: true,
              fillColor: Colors.white,
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),

          const SizedBox(height: 10),

          // Students Table / List (Extracted)
          if (filteredStudents.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text('Không tìm thấy thí sinh nào phù hợp'),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredStudents.length,
              separatorBuilder: (context, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final student = filteredStudents[index] as Map<String, dynamic>;
                return StudentReportTile(
                  student: student,
                  onTap: () => _showStudentDetailSheet(student),
                );
              },
            ),
        ],
      ),
    );
  }

  void _showStudentDetailSheet(Map<String, dynamic> student) {
    final name = student['full_name'] ?? 'Sinh viên';
    final code = student['user_code'] ?? '';
    final email = student['email'] ?? '';
    final status = (student['status'] ?? 'NOT_STARTED').toString().toUpperCase();
    final isDisqualified = status == 'DISQUALIFIED' || status == 'SUSPENDED';
    final isSubmitted = status == 'SUBMITTED';
    final score = student['score'];
    final violationCount = student['violation_count'] ?? 0;
    final attemptId = student['attempt_id']?.toString() ?? student['_id']?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: isDisqualified ? const Color(0xFFFEE2E2) : const Color(0xFFEFF6FF),
                  child: Icon(
                    isDisqualified ? Icons.block : (isSubmitted ? Icons.check_circle : Icons.person),
                    color: isDisqualified ? const Color(0xFFDC2626) : const Color(0xFF1D4ED8),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      const SizedBox(height: 2),
                      Text('MSSV: $code ${email.isNotEmpty ? "• $email" : ""}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 14),
            Row(
              children: [
                _buildSheetInfo('Trạng thái', status == 'SUBMITTED' ? 'Đã nộp bài' : (status == 'IN_PROGRESS' ? 'Đang thi' : (isDisqualified ? 'Bị đình chỉ' : 'Chưa thi'))),
                _buildSheetInfo('Điểm số', score != null ? '$score đ' : 'Chưa có'),
                _buildSheetInfo('Vi phạm', '$violationCount lần'),
              ],
            ),
            const SizedBox(height: 20),
            if (isDisqualified && attemptId.isNotEmpty) ...[
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    try {
                      final res = await _examDataSource.unlockAttempt(attemptId);
                      if (res['success'] == true) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Đã mở khóa / cho thi lại thí sinh $name thành công!'), backgroundColor: Colors.green),
                        );
                        _fetchStatistics();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(res['message'] ?? 'Mở khóa thất bại'), backgroundColor: Colors.red),
                        );
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
                      );
                    }
                  },
                  icon: const Icon(Icons.lock_open, size: 18),
                  label: const Text('Mở khóa / Cho phép thi lại', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                ),
              ),
              const SizedBox(height: 10),
            ],
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                child: const Text('Đóng'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSheetInfo(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        ],
      ),
    );
  }
}
