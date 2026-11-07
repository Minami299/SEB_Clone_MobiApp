import 'package:flutter/material.dart';
import '../../../../core/services/session_service.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../../../auth/presentation/pages/profile_page.dart';
import '../../data/datasources/exam_remote_datasource.dart';
import '../../data/models/exam_model.dart';
import 'exam_taking_page.dart';
import 'exam_lobby_page.dart';
import '../widgets/exam_card_widget.dart';
import '../../../exam_management/presentation/pages/create_edit_exam_page.dart';

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

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExamLobbyPage(
          examId: exam.id,
          accessPin: pin ?? '',
          examTitle: exam.title,
          subjectCode: exam.subjectCode,
          durationMinutes: exam.durationMinutes,
          maxViolations: exam.maxViolations,
        ),
      ),
    );

    if (mounted) {
      _fetchExams();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = SessionService().currentUser;
    final isProctor = user != null && ['LECTURER', 'HEAD_OF_SUBJECT'].contains(user.role);

    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfilePage()),
            ).then((_) => setState(() {}));
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.white24,
                  child: Text(
                    (user?.fullName.isNotEmpty == true) ? user!.fullName[0].toUpperCase() : 'U',
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        user?.fullName ?? 'Kỳ thi',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        user?.role ?? '',
                        style: const TextStyle(fontSize: 11, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchExams,
            tooltip: 'Làm mới',
          ),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'Thông tin cá nhân',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfilePage()),
              ).then((_) => setState(() {}));
            },
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
                              return ExamCardWidget(
                                exam: exam,
                                isProctor: isProctor,
                                onEnterExam: () => _handleEnterExam(exam),
                                onRefresh: _fetchExams,
                              );
                            },
                          ),
          ),
        ],
      ),
      floatingActionButton: isProctor
          ? FloatingActionButton.extended(
              onPressed: () async {
                final created = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateEditExamPage()),
                );
                if (created == true) _fetchExams();
              },
              backgroundColor: const Color(0xFF1E3A5F),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Tạo ca thi mới'),
            )
          : null,
    );
  }
}

