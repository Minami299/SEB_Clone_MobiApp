import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/services/session_service.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../../../auth/presentation/pages/profile_page.dart';
import '../../data/datasources/exam_remote_datasource.dart';
import '../../data/models/exam_model.dart';
import 'exam_lobby_page.dart';
import 'student_home_page.dart';
import '../widgets/exam_card_widget.dart';
import '../../../exam_management/presentation/pages/create_edit_exam_page.dart';

class ExamListPage extends StatefulWidget {
  const ExamListPage({super.key});

  @override
  State<ExamListPage> createState() => _ExamListPageState();
}

class _ExamListPageState extends State<ExamListPage> {
  final _apiClient = ApiClient();
  final _examDataSource = ExamRemoteDataSource();
  final _searchController = TextEditingController();

  List<ExamModel> _exams = [];
  bool _isLoading = true;
  String? _errorMessage;

  String _selectedFilter = 'ALL'; // ALL, PUBLISHED, DRAFT
  int _pingMs = 0;
  bool _isServerConnected = false;
  int _bottomNavIndex = 1;

  @override
  void initState() {
    super.initState();
    _fetchExams();
    _checkServerPing();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkServerPing() async {
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận đăng xuất'),
        content: const Text(
          'Bạn có chắc chắn muốn đăng xuất khỏi tài khoản không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              SessionService().clearSession();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            },
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleEnterExam(ExamModel exam) async {
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

    if (mounted) {
      _fetchExams();
    }
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
                            'Không tìm thấy ca thi nào với mã PIN "$inputPin".',
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

  List<ExamModel> get _filteredExams {
    final query = _searchController.text.trim().toLowerCase();
    return _exams.where((e) {
      if (_selectedFilter == 'PUBLISHED' && e.status != 'PUBLISHED')
        return false;
      if (_selectedFilter == 'DRAFT' && e.status != 'DRAFT') return false;
      if (query.isNotEmpty) {
        final title = e.title.toLowerCase();
        final code = e.subjectCode.toLowerCase();
        final desc = (e.description ?? '').toLowerCase();
        if (!title.contains(query) &&
            !code.contains(query) &&
            !desc.contains(query)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final user = SessionService().currentUser;
    final isProctor =
        user != null &&
        ['LECTURER', 'HEAD_OF_SUBJECT', 'ADMIN'].contains(user.role);
    final isStudent = user != null && user.role == 'STUDENT';
    final filtered = _filteredExams;

    final publishedCount = _exams.where((e) => e.status == 'PUBLISHED').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Hệ thống Khảo thí SEB',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF1E293B)),
            onPressed: () {
              _fetchExams();
              _checkServerPing();
            },
            tooltip: 'Làm mới',
          ),
          IconButton(
            icon: const Icon(
              Icons.account_circle_outlined,
              color: Color(0xFF1E293B),
            ),
            tooltip: 'Hồ sơ cá nhân',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfilePage()),
              ).then((_) => setState(() {}));
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_outlined, color: Color(0xFFEF4444)),
            tooltip: 'Đăng xuất',
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([_fetchExams(), _checkServerPing()]);
        },
        color: const Color(0xFF0F172A),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Thẻ thông tin cá nhân & Thiết bị (Thiết kế đơn nhất, không trùng lặp)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: const Color(0xFF0F172A),
                          child: Text(
                            (user?.fullName.isNotEmpty == true)
                                ? user!.fullName[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.fullName ?? 'Người dùng',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Color(0xFF0F172A),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  if (user?.userCode.isNotEmpty == true) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        user!.userCode,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1D4ED8),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      user?.role == 'STUDENT'
                                          ? 'Sinh viên'
                                          : (user?.role ?? ''),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF475569),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatusIndicator(
                          icon: Icons.wifi,
                          label: _isServerConnected
                              ? '$_pingMs ms'
                              : 'Mất kết nối',
                          color: _isServerConnected
                              ? const Color(0xFF10B981)
                              : Colors.red,
                        ),
                        const Text(
                          '|',
                          style: TextStyle(color: Color(0xFFE2E8F0)),
                        ),
                        _buildStatusIndicator(
                          icon: Icons.security,
                          label: 'SEB Lockdown',
                          color: const Color(0xFF2563EB),
                        ),
                        const Text(
                          '|',
                          style: TextStyle(color: Color(0xFFE2E8F0)),
                        ),
                        _buildStatusIndicator(
                          icon: Icons.task_alt,
                          label: '$publishedCount ca mở',
                          color: publishedCount > 0
                              ? const Color(0xFF10B981)
                              : const Color(0xFF64748B),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // 2. Banner CTA Check-in nhanh dành cho Sinh viên
              if (isStudent) ...[
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _handleQuickCheckIn,
                    borderRadius: BorderRadius.circular(12),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0F172A), Color(0xFF1E3A5F)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A)
                                .withValues(alpha: 0.18),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.qr_code_scanner,
                            color: Colors.white,
                            size: 28,
                          ),
                          SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Quét mã QR / Nhập PIN phòng thi',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Check-in nhanh chóng vào phòng thi của giám thị',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFFCBD5E1),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.white70,
                            size: 14,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
              ],

              // 3. Search & Filter Bar
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Tìm kiếm ca thi, môn học...',
                        hintStyle: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF94A3B8),
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          size: 20,
                          color: Color(0xFF64748B),
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.white,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('ALL', 'Tất cả (${_exams.length})'),
                    const SizedBox(width: 8),
                    _buildFilterChip('PUBLISHED', 'Đang mở ($publishedCount)'),
                    if (isProctor) ...[
                      const SizedBox(width: 8),
                      _buildFilterChip('DRAFT', 'Bản nháp'),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 4. Danh sách ca thi
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isStudent ? 'Ca thi của bạn' : 'Danh sách ca thi',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    '${filtered.length} kết quả',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_errorMessage != null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      children: [
                        Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _fetchExams,
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (filtered.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.event_busy_outlined,
                        size: 48,
                        color: Color(0xFF94A3B8),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Không tìm thấy ca thi nào',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Các ca thi khả dụng sẽ tự động xuất hiện tại đây.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _fetchExams,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Tải lại dữ liệu'),
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  separatorBuilder: (context, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final exam = filtered[index];
                    return ExamCardWidget(
                      exam: exam,
                      isProctor: isProctor,
                      onEnterExam: () => _handleEnterExam(exam),
                      onRefresh: _fetchExams,
                    );
                  },
                ),
            ],
          ),
        ),
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
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text(
                'Tạo ca thi mới',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            )
          : null,
      bottomNavigationBar: isStudent
          ? NavigationBar(
              selectedIndex: _bottomNavIndex,
              height: 64,
              backgroundColor: Colors.white,
              indicatorColor: const Color(0xFFE2E8F0),
              elevation: 4,
              onDestinationSelected: (idx) {
                if (idx == 0) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const StudentHomePage()),
                  );
                } else if (idx == 1) {
                  setState(() => _bottomNavIndex = 1);
                } else if (idx == 2) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfilePage()),
                  ).then((_) {
                    if (mounted) setState(() => _bottomNavIndex = 1);
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
                  selectedIcon: Icon(
                    Icons.calendar_month,
                    color: Color(0xFF0F172A),
                  ),
                  label: 'Lịch thi',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person, color: Color(0xFF0F172A)),
                  label: 'Hồ sơ',
                ),
              ],
            )
          : null,
    );
  }

  Widget _buildStatusIndicator({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFF334155),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: const Color(0xFF0F172A),
      backgroundColor: Colors.white,
      side: BorderSide(
        color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
      ),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected ? Colors.white : const Color(0xFF475569),
      ),
      onSelected: (_) => setState(() => _selectedFilter = value),
    );
  }
}
