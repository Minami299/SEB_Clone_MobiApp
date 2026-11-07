import 'package:flutter/material.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
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

  Future<void> _handleExportCsv() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đang tạo và tải file CSV bảng điểm...')),
      );

      final csvUrl = ApiEndpoints.examExport(widget.examId);
      await _apiClient.get(csvUrl);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Xuất bảng điểm thành công từ $csvUrl'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi xuất file: $e'), backgroundColor: Colors.red),
      );
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
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Xuất CSV / Excel',
            onPressed: _handleExportCsv,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
            onPressed: _fetchStatistics,
          ),
        ],
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
          // Row 1: Key Metrics Cards (Extracted)
          Row(
            children: [
              Expanded(child: ReportMetricCard(label: 'Đăng ký', value: '${summary['total_registered'] ?? 0}', color: Colors.blueGrey)),
              const SizedBox(width: 8),
              Expanded(child: ReportMetricCard(label: 'Đã nộp', value: '$submitted', color: Colors.green)),
              const SizedBox(width: 8),
              Expanded(child: ReportMetricCard(label: 'Đình chỉ', value: '${summary['suspended_count'] ?? 0}', color: Colors.red)),
              const SizedBox(width: 8),
              Expanded(child: ReportMetricCard(label: 'Tỷ lệ Đạt', value: '${summary['pass_rate'] ?? 0}%', color: const Color(0xFF1E3A5F))),
            ],
          ),

          const SizedBox(height: 12),

          // Row 2: Score Metrics Card (Extracted)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ScoreMiniCard(label: 'Điểm TB', value: '${summary['average_score'] ?? 0} đ', color: const Color(0xFF1E3A5F)),
                ScoreMiniCard(label: 'Điểm cao nhất', value: '${summary['highest_score'] ?? 0} đ', color: Colors.green),
                ScoreMiniCard(label: 'Điểm thấp nhất', value: '${summary['lowest_score'] ?? 0} đ', color: Colors.orange),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Danh sách thí sinh (${filteredStudents.length}):',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              TextButton.icon(
                onPressed: _handleExportCsv,
                icon: const Icon(Icons.download, size: 16),
                label: const Text('Xuất CSV'),
              ),
            ],
          ),
          const SizedBox(height: 6),

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
                return StudentReportTile(
                  student: filteredStudents[index] as Map<String, dynamic>,
                );
              },
            ),
        ],
      ),
    );
  }
}
