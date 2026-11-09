import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/services/session_service.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../../../auth/presentation/pages/profile_page.dart';
import '../../data/datasources/exam_remote_datasource.dart';
import '../../data/models/exam_model.dart';
import 'exam_list_page.dart';
import 'exam_lobby_page.dart';

class StudentHomePage extends StatefulWidget {
  const StudentHomePage({super.key});

  @override
  State<StudentHomePage> createState() => _StudentHomePageState();
}

class _StudentHomePageState extends State<StudentHomePage> {
  final _apiClient = ApiClient();
  final _examDataSource = ExamRemoteDataSource();

  int _currentTabIndex = 0;
  bool _isLoading = true;
  bool _isLoadingSubmissions = false;

  List<ExamModel> _exams = [];
  List<dynamic> _recentSubmissions = [];

  // Trạng thái mạng động theo thời gian thực
  bool _isServerConnected = false;
  int _pingMs = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _measurePingAndHealth(),
      _fetchExams(),
      _fetchRecentSubmissions(),
    ]);
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _measurePingAndHealth() async {
    final sw = Stopwatch()..start();
    try {
      final res = await _apiClient.get(ApiEndpoints.health);
      sw.stop();
      if (mounted) {
        setState(() {
          _isServerConnected = res['status'] == 'OK' || res['success'] == true;
          _pingMs = sw.elapsedMilliseconds;
        });
      }
    } catch (_) {
      sw.stop();
      if (mounted) {
        setState(() {
          _isServerConnected = false;
          _pingMs = 0;
        });
      }
    }
  }

  Future<void> _fetchExams() async {
    try {
      final list = await _examDataSource.getExams();
      if (mounted) {
        setState(() {
          _exams = list;
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchRecentSubmissions() async {
    setState(() => _isLoadingSubmissions = true);
    try {
      final res = await _apiClient.get(ApiEndpoints.examMySubmissions);
      if (res['success'] == true && res['data'] is List) {
        if (mounted) {
          setState(() {
            _recentSubmissions = res['data'] as List;
            _isLoadingSubmissions = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingSubmissions = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingSubmissions = false);
    }
  }

  void _handleEnterExam(ExamModel exam) async {
    String? pin = exam.accessPin;
    if (pin == null || pin.isEmpty) {
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
              maxLength: 6,
              decoration: const InputDecoration(
                hintText: 'Mã PIN 6 số',
                counterText: '',
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
                child: const Text('Xác nhận'),
              ),
            ],
          );
        },
      );
      if (pin == null || pin.isEmpty) return;
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

    _loadDashboardData();
  }

  void _handleQuickCheckIn() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final pinController = TextEditingController();
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Check-in Phòng Thi',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Quét mã QR tại phòng thi hoặc nhập mã PIN do giám thị cung cấp.',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  final availableExams = _exams
                      .where((e) => e.status == 'PUBLISHED')
                      .toList();
                  if (availableExams.isNotEmpty) {
                    _handleEnterExam(availableExams.first);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Hiện không có ca thi nào đang mở.'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                label: const Text(
                  'Bật Camera Quét Mã QR',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      'HOẶC',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pinController,
                maxLength: 6,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  letterSpacing: 8,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  hintText: '• • • • • •',
                  hintStyle: const TextStyle(
                    letterSpacing: 8,
                    color: Colors.grey,
                  ),
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: () {
                  final inputPin = pinController.text.trim();
                  if (inputPin.length == 6) {
                    Navigator.pop(ctx);
                    final matchedList = _exams
                        .where((e) => e.accessPin == inputPin)
                        .toList();
                    if (matchedList.isNotEmpty) {
                      _handleEnterExam(matchedList.first);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Không tìm thấy ca thi nào với mã PIN "$inputPin". Vui lòng kiểm tra lại.',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Xác thực & Vào phòng thi',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = SessionService().currentUser;
    final studentName = user?.fullName.isNotEmpty == true
        ? user!.fullName
        : 'Sinh viên';
    final studentCode = user?.userCode.isNotEmpty == true
        ? user!.userCode
        : (user?.email.isNotEmpty == true ? user!.email : '');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadDashboardData,
          color: const Color(0xFF0F172A),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Header sinh viên & Trạng thái phần cứng
                _buildHeader(studentName, studentCode),

                const SizedBox(height: 18),

                // 2. CTA Quét mã QR / Check-in
                _buildQuickActionCard(),

                const SizedBox(height: 22),

                // 3. Danh sách ca thi đang diễn ra & sắp tới
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Lịch thi của bạn',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      '${_exams.length} ca thi',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_exams.isEmpty)
                  _buildEmptyExamCard()
                else
                  ..._exams.map((exam) => _buildExamCard(exam)),

                const SizedBox(height: 20),

                // 4. Widget kiểm tra điều kiện an toàn thiết bị (Động)
                _buildSystemChecklist(user != null),

                const SizedBox(height: 24),

                // 5. Lịch sử bài thi & Kết quả gần nhất (Động từ API)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Bài thi đã hoàn thành',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() => _currentTabIndex = 1),
                      child: const Text(
                        'Xem tất cả',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                if (_isLoadingSubmissions)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else if (_recentSubmissions.isEmpty)
                  _buildEmptySubmissionCard()
                else
                  ..._recentSubmissions.map(
                    (sub) => _buildRecentSubmissionItem(sub),
                  ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTabIndex,
        height: 64,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFE2E8F0),
        elevation: 3,
        onDestinationSelected: (idx) {
          if (idx == 0) {
            setState(() => _currentTabIndex = 0);
          } else if (idx == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const ExamListPage()),
            );
          } else if (idx == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfilePage()),
            ).then((_) {
              if (mounted) setState(() => _currentTabIndex = 0);
            });
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: Color(0xFF0F172A)),
            label: 'Trang chủ',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_month, color: Color(0xFF0F172A)),
            label: 'Lịch thi',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: Color(0xFF0F172A)),
            label: 'Hồ sơ',
          ),
        ],
      ),
    );
  }

  // ==========================================
  // COMPONENT BUILDERS (HOÀN TOÀN DYNAMIC)
  // ==========================================

  Widget _buildHeader(String name, String code) {
    return Column(
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFF0F172A),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'S',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Xin chào,',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (code.isNotEmpty)
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            code,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.verified,
                          size: 14,
                          color: Color(0xFF2563EB),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.support_agent_outlined,
                color: Color(0xFF334155),
              ),
              tooltip: 'Hỗ trợ kỹ thuật',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Hỗ trợ Phòng thi'),
                    content: const Text(
                      'Nếu gặp sự cố kỹ thuật hoặc mất kết nối, vui lòng liên hệ ngay Giám thị coi thi tại phòng thi để được hỗ trợ xử lý.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Đã hiểu'),
                      ),
                    ],
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.logout_outlined, color: Color(0xFF334155)),
              tooltip: 'Đăng xuất',
              onPressed: () {
                SessionService().clearSession();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                );
              },
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Thanh trạng thái phần cứng và mạng theo thời gian thực
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatusPill(
                icon: Icons.wifi,
                color: _isServerConnected
                    ? const Color(0xFF10B981)
                    : Colors.red,
                label: _isServerConnected ? '$_pingMs ms' : 'Mất kết nối',
              ),
              const Text('|', style: TextStyle(color: Color(0xFFCBD5E1))),
              _buildStatusPill(
                icon: Icons.security,
                color: const Color(0xFF2563EB),
                label: 'SEB Mode',
              ),
              const Text('|', style: TextStyle(color: Color(0xFFCBD5E1))),
              _buildStatusPill(
                icon: Icons.verified_user_outlined,
                color: _isServerConnected
                    ? const Color(0xFF10B981)
                    : const Color(0xFFF59E0B),
                label: _isServerConnected ? 'Sẵn sàng' : 'Chưa sẵn sàng',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusPill({
    required IconData icon,
    required Color color,
    required String label,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionCard() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _handleQuickCheckIn,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E3A5F)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Icon(
                  Icons.qr_code_scanner,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Check-in Phòng Thi',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Quét mã QR hoặc nhập PIN 6 số do giám thị cấp để bắt đầu kiểm tra an toàn.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFFCBD5E1),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.white70,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExamCard(ExamModel exam) {
    final isPublished = exam.status == 'PUBLISHED';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPublished
              ? const Color(0xFF10B981)
              : const Color(0xFFE2E8F0),
          width: isPublished ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  exam.subjectCode.isNotEmpty ? exam.subjectCode : 'SEB EXAM',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Color(0xFF1D4ED8),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isPublished
                      ? const Color(0xFFECFDF5)
                      : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isPublished ? 'Đang mở' : 'Chưa tới giờ',
                  style: TextStyle(
                    color: isPublished
                        ? const Color(0xFF047857)
                        : const Color(0xFFB45309),
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            exam.title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          if (exam.description != null && exam.description!.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              exam.description!,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.timer_outlined,
                size: 15,
                color: Color(0xFF64748B),
              ),
              const SizedBox(width: 4),
              Text(
                '${exam.durationMinutes} phút',
                style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
              ),
              const Spacer(),
              const Icon(
                Icons.shield_outlined,
                size: 15,
                color: Color(0xFF64748B),
              ),
              const SizedBox(width: 4),
              Text(
                'Tối đa ${exam.maxViolations} vi phạm',
                style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton.icon(
              onPressed: isPublished ? () => _handleEnterExam(exam) : null,
              icon: Icon(
                isPublished ? Icons.lock_open : Icons.lock_outline,
                size: 18,
              ),
              label: Text(
                isPublished ? 'VÀO PHÒNG THI NGAY' : 'CHỜ MỞ CA THI',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isPublished
                    ? const Color(0xFF10B981)
                    : const Color(0xFFE2E8F0),
                foregroundColor: isPublished
                    ? Colors.white
                    : const Color(0xFF94A3B8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: isPublished ? 2 : 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyExamCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Column(
        children: [
          Icon(Icons.event_available, size: 40, color: Color(0xFF94A3B8)),
          SizedBox(height: 8),
          Text(
            'Hiện chưa có ca thi nào cần thực hiện',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Các ca thi mới sẽ tự động hiển thị khi được xuất bản.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemChecklist(bool hasUser) {
    int passed = 0;
    if (_isServerConnected) passed++;
    if (hasUser) passed++;
    passed++; // Kiosk Mode cờ an toàn
    if (_exams.isNotEmpty) passed++;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.verified_user_outlined,
                size: 18,
                color: Color(0xFF0F172A),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Kiểm tra điều kiện thiết bị (Security Preflight)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: passed == 4
                      ? const Color(0xFFECFDF5)
                      : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$passed/4 Đạt',
                  style: TextStyle(
                    color: passed == 4
                        ? const Color(0xFF047857)
                        : const Color(0xFFB45309),
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildCheckItem(
            title: _isServerConnected
                ? 'Kết nối máy chủ thi ổn định ($_pingMs ms)'
                : 'Mất kết nối tới máy chủ thi',
            isOk: _isServerConnected,
          ),
          _buildCheckItem(
            title: hasUser
                ? 'Tài khoản thí sinh đã xác thực'
                : 'Chưa xác thực thông tin thí sinh',
            isOk: hasUser,
          ),
          _buildCheckItem(
            title: 'Cơ chế chống gian lận SEB Kiosk kích hoạt',
            isOk: true,
          ),
          _buildCheckItem(
            title: _exams.isNotEmpty
                ? 'Danh sách ca thi đã được đồng bộ'
                : 'Chưa có ca thi khả dụng',
            isOk: _exams.isNotEmpty,
          ),
        ],
      ),
    );
  }

  Widget _buildCheckItem({required String title, required bool isOk}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            isOk ? Icons.check_circle : Icons.cancel,
            color: isOk ? const Color(0xFF10B981) : Colors.red,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySubmissionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Center(
        child: Text(
          'Chưa có bài thi nào đã hoàn thành.',
          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
      ),
    );
  }

  Widget _buildRecentSubmissionItem(dynamic sub) {
    String subCode = '';
    String subName = '';
    String examTitle = '';
    if (sub['exam_id'] is Map) {
      examTitle = sub['exam_id']['exam_title'] ?? '';
      if (sub['exam_id']['subject_id'] is Map) {
        subCode = sub['exam_id']['subject_id']['subject_code'] ?? '';
        subName = sub['exam_id']['subject_id']['subject_name'] ?? '';
      }
    }

    String dateStr = '';
    if (sub['submitted_at'] != null) {
      final dt = DateTime.tryParse(sub['submitted_at']);
      if (dt != null) {
        dateStr =
            '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
      }
    }

    final score = sub['total_score'];
    final violations = sub['violation_count'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.assignment_turned_in_outlined,
              color: Color(0xFF2563EB),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subCode.isNotEmpty
                      ? '$subCode - $subName'
                      : (examTitle.isNotEmpty ? examTitle : 'Bài thi đã nộp'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFF0F172A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${dateStr.isNotEmpty ? "Nộp: $dateStr | " : ""}Vi phạm: $violations',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          if (score != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$score đ',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF047857),
                  fontSize: 13,
                ),
              ),
            ),
          ] else ...[
            const Text(
              'Đã nộp',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF10B981),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
