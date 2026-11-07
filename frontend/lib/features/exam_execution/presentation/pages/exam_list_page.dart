import 'package:flutter/material.dart';
import '../../../../core/services/session_service.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../../data/datasources/exam_remote_datasource.dart';
import '../../data/models/exam_model.dart';
import 'exam_taking_page.dart';
import '../../../monitoring_reports/presentation/pages/live_monitoring_page.dart';
import '../../../admin_system/presentation/pages/user_management_page.dart';

class ExamListPage extends StatefulWidget {
  const ExamListPage({super.key});

  @override
  State<ExamListPage> createState() => _ExamListPageState();
}

class _ExamListPageState extends State<ExamListPage> {
  final _examDataSource = ExamRemoteDataSource();
  List<ExamModel> _exams = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchExams();
  }

  Future<void> _fetchExams() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await _examDataSource.getExams();
      if (mounted) {
        setState(() {
          _exams = list;
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

  void _handleLogout() {
    SessionService().clearSession();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  Future<void> _handleEnterExam(ExamModel exam) async {
    String? pin;
    if (exam.accessPin != null && exam.accessPin!.isNotEmpty) {
      pin = await showDialog<String>(
        context: context,
        builder: (ctx) {
          final pinController = TextEditingController();
          return AlertDialog(
            title: const Text('Nhập mã PIN ca thi'),
            content: TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: 'Mã PIN bảo mật',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, pinController.text.trim()),
                child: const Text('Vào thi'),
              ),
            ],
          );
        },
      );

      if (pin == null) return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final examData = await _examDataSource.startAttempt(
        examId: exam.id,
        accessPin: pin,
      );

      if (!mounted) return;
      Navigator.pop(context); // Đóng loading

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ExamTakingPage(
            examId: exam.id,
            attemptId: examData['attempt_id'],
            examTitle: examData['exam_title'],
            durationMinutes: examData['duration_minutes'],
            maxViolations: examData['max_violations'],
            questions: examData['questions'],
          ),
        ),
      );
      if (mounted) {
        _fetchExams();
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Đóng loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception:', '').trim()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = SessionService().currentUser;
    final isProctor = user != null && ['LECTURER', 'HEAD_OF_SUBJECT', 'ADMIN'].contains(user.role);
    final isAdmin = user != null && user.role == 'ADMIN';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Danh sách Kỳ thi'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.manage_accounts),
              tooltip: 'Quản trị Người dùng & Phân quyền',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UserManagementPage()),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchExams,
            tooltip: 'Làm mới',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
            tooltip: 'Đăng xuất',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue[50],
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blueAccent,
                  child: Text(
                    user != null && user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'U',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.fullName ?? 'Người dùng',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        'Mã số: ${user?.userCode ?? ""} | Vai trò: ${user?.role ?? ""}',
                        style: const TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _fetchExams,
                              child: const Text('Thử lại'),
                            ),
                          ],
                        ),
                      )
                    : _exams.isEmpty
                        ? const Center(child: Text('Hiện tại không có kỳ thi nào khả dụng'))
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _exams.length,
                            separatorBuilder: (context, _) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final exam = _exams[index];
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
                                          if (isProctor)
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
                                              label: const Text('Giám sát vi phạm'),
                                            ),
                                          const SizedBox(width: 8),
                                          ElevatedButton.icon(
                                            onPressed: () => _handleEnterExam(exam),
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
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

