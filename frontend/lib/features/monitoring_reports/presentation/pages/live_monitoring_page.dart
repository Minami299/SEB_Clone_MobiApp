import 'package:flutter/material.dart';
import '../../../exam_execution/data/datasources/exam_remote_datasource.dart';

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
  List<dynamic> _violations = [];
  bool _isLoading = true;
  String? _errorMessage;

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
        setState(() {
          _violations = data['violations'] as List? ?? [];
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Giám sát: ${widget.examTitle}'),
        backgroundColor: Colors.red[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchViolations,
            tooltip: 'Làm mới nhật ký',
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
                      ElevatedButton(onPressed: _fetchViolations, child: const Text('Thử lại')),
                    ],
                  ),
                )
              : _violations.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                          SizedBox(height: 12),
                          Text('Chưa ghi nhận vi phạm an toàn nào trong ca thi này'),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _violations.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final v = _violations[index];
                        final student = v['attempt_id']?['student_id'];
                        final studentName = student?['full_name'] ?? 'Thí sinh';
                        final studentCode = student?['user_code'] ?? '';
                        final violationType = v['violation_type'] ?? 'VI PHẠM';
                        final details = v['violation_details'] ?? '';
                        final time = v['detected_at'] != null
                            ? DateTime.tryParse(v['detected_at'])?.toLocal().toString().split('.')[0]
                            : '';

                        return Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Colors.red,
                              child: Icon(Icons.warning, color: Colors.white, size: 20),
                            ),
                            title: Text(
                              '$studentName ($studentCode)',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Hành vi: $violationType', style: const TextStyle(color: Colors.redAccent)),
                                if (details.isNotEmpty) Text('Chi tiết: $details'),
                                Text('Thời điểm: $time', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}

