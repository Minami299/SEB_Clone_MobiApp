import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import 'question_list_page.dart';

class LecturerQuestionBankView extends StatefulWidget {
  final VoidCallback? onExamTabRequested;

  const LecturerQuestionBankView({
    super.key,
    this.onExamTabRequested,
  });

  @override
  State<LecturerQuestionBankView> createState() => _LecturerQuestionBankViewState();
}

class _LecturerQuestionBankViewState extends State<LecturerQuestionBankView> {
  final _apiClient = ApiClient();
  final _searchController = TextEditingController();

  List<dynamic> _subjects = [];
  List<dynamic> _myRequests = [];
  List<dynamic> _notifications = [];
  bool _isLoading = true;
  String? _errorMessage;

  // 0: Danh sách môn học & Question Bank, 1: Yêu cầu làm giảng viên
  int _currentTab = 0;

  Map<String, dynamic>? get _latestReviewNotification {
    for (var n in _notifications) {
      if (n['is_read'] == false && n['type'] == 'SUBJECT_ACCESS_REVIEW') {
        return n as Map<String, dynamic>;
      }
    }
    return null;
  }

  Future<void> _markNotificationRead(String notifId) async {
    try {
      await _apiClient.patch(ApiEndpoints.notificationMarkRead(notifId));
      setState(() {
        final notif = _notifications.firstWhere(
          (n) => n['_id'] == notifId,
          orElse: () => null,
        );
        if (notif != null) notif['is_read'] = true;
      });
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _apiClient.get(ApiEndpoints.subjectAccessSubjects),
        _apiClient.get(ApiEndpoints.subjectAccessMyRequests),
      ]);

      final subRes = results[0];
      final reqRes = results[1];

      List<dynamic> notifData = [];
      try {
        final notifRes = await _apiClient.get(ApiEndpoints.notifications);
        if (notifRes['success'] == true && notifRes['data'] is List) {
          notifData = notifRes['data'] as List;
        }
      } catch (_) {
        // Lỗi thông báo không làm gián đoạn danh sách môn học
      }

      if (mounted) {
        setState(() {
          if (subRes['success'] == true && subRes['data'] is List) {
            _subjects = subRes['data'] as List;
          } else {
            _subjects = [];
          }

          if (reqRes['success'] == true && reqRes['data'] is List) {
            _myRequests = reqRes['data'] as List;
          } else {
            _myRequests = [];
          }

          _notifications = notifData;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
        });
      }
    }
  }

  String _getSubjectAccessStatus(String subjectId) {
    for (var r in _myRequests) {
      final sId = r['subject_id'] is Map ? r['subject_id']['_id'] : r['subject_id'];
      if (sId == subjectId) {
        return (r['status'] ?? 'PENDING').toString().toUpperCase();
      }
    }
    return 'NONE';
  }

  Future<void> _showRequestAccessDialog({String? preselectedSubjectId}) async {
    String? selectedSubId = preselectedSubjectId;
    if (selectedSubId == null && _subjects.isNotEmpty) {
      selectedSubId = _subjects.first['_id'];
    }

    String selectedGrantType = 'QUESTION_CONTRIBUTION';
    final grantTypes = [
      {'value': 'QUESTION_CONTRIBUTION', 'label': 'Đóng góp câu hỏi & Soạn đề'},
      {'value': 'EXAM_CREATION', 'label': 'Tổ chức & Giám sát ca thi'},
      {'value': 'FULL', 'label': 'Toàn quyền (Đề thi + Ca thi)'},
    ];

    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Row(
            children: [
              Icon(Icons.assignment_ind_outlined, color: Color(0xFF1E3A5F)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Đăng ký giảng dạy môn học',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Chọn môn học đăng ký *',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedSubId,
                      isExpanded: true,
                      items: _subjects.map((s) {
                        return DropdownMenuItem<String>(
                          value: s['_id'],
                          child: Text(
                            '${s['subject_code']} - ${s['subject_name']}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedSubId = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                const Text(
                  'Quyền hạn đề xuất *',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedGrantType,
                      isExpanded: true,
                      items: grantTypes.map((g) {
                        return DropdownMenuItem<String>(
                          value: g['value'],
                          child: Text(g['label']!, style: const TextStyle(fontSize: 13)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedGrantType = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Color(0xFF1D4ED8)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Yêu cầu sẽ được gửi tới Trưởng bộ môn xem xét và phê duyệt trước khi bạn có thể truy cập ngân hàng câu hỏi.',
                          style: TextStyle(fontSize: 11.5, color: Color(0xFF1E40AF), height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (selectedSubId == null) return;
                try {
                  final res = await _apiClient.post(
                    ApiEndpoints.subjectAccessRequest,
                    body: {
                      'subject_id': selectedSubId,
                      'grant_type': selectedGrantType,
                    },
                  );
                  if (res['success'] == true) {
                    if (ctx.mounted) Navigator.pop(ctx, true);
                  } else {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text(res['message'] ?? 'Gửi yêu cầu thất bại')),
                      );
                    }
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Lỗi: $e')),
                    );
                  }
                }
              },
              child: const Text('Gửi đăng ký'),
            ),
          ],
        ),
      ),
    );

    if (submitted == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã gửi đăng ký giảng dạy môn học tới Trưởng bộ môn!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
      _loadData();
    }
  }

  List<dynamic> get _filteredSubjects {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _subjects;
    return _subjects.where((s) {
      final code = (s['subject_code'] ?? '').toString().toLowerCase();
      final name = (s['subject_name'] ?? '').toString().toLowerCase();
      return code.contains(query) || name.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _loadData, child: const Text('Tải lại')),
          ],
        ),
      );
    }

    final pendingCount = _myRequests.where((r) => r['status'] == 'PENDING').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // 1. Tab Bar chuyển đổi giữa "Danh sách Môn học" và "Đăng ký giảng dạy"
          _buildTopTabs(pendingCount),

          // Banner thông báo phê duyệt từ Trưởng bộ môn (nếu có)
          if (_latestReviewNotification != null)
            _buildNotificationBanner(_latestReviewNotification!),

          // 2. Nội dung theo từng tab
          Expanded(
            child: _currentTab == 0
                ? _buildSubjectListView()
                : _buildMyRequestsListView(),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationBanner(Map<String, dynamic> notif) {
    final isApproved = (notif['title'] ?? '').toString().contains('phê duyệt') ||
        (notif['data'] != null && notif['data']['status'] == 'APPROVED');
    final notifId = notif['_id'] ?? '';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isApproved ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isApproved ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isApproved ? Icons.check_circle_outline : Icons.cancel_outlined,
            color: isApproved ? const Color(0xFF059669) : const Color(0xFFDC2626),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notif['title'] ?? 'Thông báo xét duyệt',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isApproved ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  notif['message'] ?? '',
                  style: TextStyle(
                    fontSize: 12,
                    color: isApproved ? const Color(0xFF047857) : const Color(0xFFB91C1C),
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () => _markNotificationRead(notifId),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: Icon(
                Icons.close,
                size: 16,
                color: isApproved ? const Color(0xFF047857) : const Color(0xFFB91C1C),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopTabs(int pendingCount) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _currentTab = 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: _currentTab == 0 ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: _currentTab == 0
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      'Môn học (${_subjects.length})',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: _currentTab == 0 ? FontWeight.bold : FontWeight.w500,
                        color: _currentTab == 0 ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _currentTab = 1),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: _currentTab == 1 ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: _currentTab == 1
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Đăng ký giảng dạy',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: _currentTab == 1 ? FontWeight.bold : FontWeight.w500,
                            color: _currentTab == 1 ? const Color(0xFF4F46E5) : const Color(0xFF64748B),
                          ),
                        ),
                        if (pendingCount > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$pendingCount',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // TAB 1: Danh sách môn học & Truy cập Question Bank
  Widget _buildSubjectListView() {
    final list = _filteredSubjects;

    return Column(
      children: [
        // Thanh tìm kiếm môn học
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Tìm kiếm môn học...',
              hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
          ),
        ),

        // Danh sách các môn
        Expanded(
          child: list.isEmpty
              ? const Center(
                  child: Text('Không tìm thấy môn học nào', style: TextStyle(color: Color(0xFF64748B))),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final s = list[index];
                    final sId = s['_id'];
                    final code = s['subject_code'] ?? '';
                    final name = s['subject_name'] ?? '';
                    final desc = s['description'] ?? '';
                    final status = _getSubjectAccessStatus(sId);

                    return _buildSubjectCard(sId, code, name, desc, status);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSubjectCard(String subjectId, String code, String name, String desc, String accessStatus) {
    final isApproved = accessStatus == 'APPROVED';
    final isPending = accessStatus == 'PENDING';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isApproved ? const Color(0xFFC7D2FE) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    code,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Badge trạng thái
                if (isApproved)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: const Text(
                      '✓ Đã phê duyệt giảng dạy',
                      style: TextStyle(
                        color: Color(0xFF059669),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else if (isPending)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: const Text(
                      '⏳ Chờ phê duyệt',
                      style: TextStyle(
                        color: Color(0xFFD97706),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else if (accessStatus == 'REJECTED')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: const Text(
                      'Bị từ chối',
                      style: TextStyle(
                        color: Color(0xFFDC2626),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Chưa đăng ký',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            Text(
              name,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            if (desc.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                desc,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
            const SizedBox(height: 12),

            // Nút hành động: Phân quyền rõ ràng
            if (isApproved)
              // Chỉ người có quyền APPROVED mới được mở ngân hàng câu hỏi
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => QuestionListPage(
                          subjectId: subjectId,
                          subjectCode: code,
                          subjectName: name,
                        ),
                      ),
                    ).then((_) => _loadData());
                  },
                  icon: const Icon(Icons.menu_book_outlined, size: 16),
                  label: const Text(
                    'Mở ngân hàng câu hỏi',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              )
            else if (isPending)
              // Đang chờ duyệt: Thông báo rõ ràng, không thể vào kho câu hỏi
              InkWell(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      title: const Row(
                        children: [
                          Icon(Icons.hourglass_top, color: Color(0xFFD97706)),
                          SizedBox(width: 8),
                          Text('Đang chờ phê duyệt', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      content: Text(
                        'Yêu cầu đăng ký giảng dạy môn $code ($name) của bạn đang được Trưởng bộ môn xem xét.\n\nSau khi được phê duyệt, bạn mới có thể truy cập ngân hàng câu hỏi và tạo đề thi.',
                        style: const TextStyle(fontSize: 13, height: 1.4),
                      ),
                      actions: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Đã hiểu'),
                        ),
                      ],
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.hourglass_top, size: 16, color: Color(0xFFD97706)),
                      SizedBox(width: 8),
                      Text(
                        'Đang chờ Trưởng bộ môn phê duyệt',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFD97706),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              // Chưa đăng ký / Bị từ chối: Chỉ hiển thị nút Đăng ký giảng dạy
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showRequestAccessDialog(preselectedSubjectId: subjectId),
                  icon: const Icon(Icons.person_add_alt_1_outlined, size: 16),
                  label: Text(
                    accessStatus == 'REJECTED' ? 'Gửi lại yêu cầu đăng ký' : 'Đăng ký giảng dạy môn này',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2563EB),
                    side: const BorderSide(color: Color(0xFF93C5FD)),
                    backgroundColor: const Color(0xFFEFF6FF),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // TAB 2: Danh sách và Đăng ký giảng dạy môn học
  Widget _buildMyRequestsListView() {
    return Column(
      children: [
        // Nút Đăng ký giảng dạy môn mới
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showRequestAccessDialog(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Đăng ký giảng dạy môn học mới', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ),

        Expanded(
          child: _myRequests.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.inbox_outlined, size: 48, color: Color(0xFF94A3B8)),
                      const SizedBox(height: 10),
                      const Text(
                        'Bạn chưa gửi đăng ký môn học nào',
                        style: TextStyle(fontSize: 14, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Nhấn nút phía trên để đăng ký môn học bạn muốn phụ trách.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  itemCount: _myRequests.length,
                  itemBuilder: (context, index) {
                    final r = _myRequests[index];
                    final sub = r['subject_id'] is Map ? r['subject_id'] : {};
                    final sId = sub['_id'] ?? (r['subject_id'] is String ? r['subject_id'] : '');
                    final code = sub['subject_code'] ?? '';
                    final name = sub['subject_name'] ?? 'Môn học';
                    final status = (r['status'] ?? 'PENDING').toString().toUpperCase();
                    final grantType = r['grant_type'] ?? 'QUESTION_CONTRIBUTION';
                    final date = r['created_at'] != null ? r['created_at'].toString().substring(0, 10) : '';

                    Color statusColor;
                    String statusText;
                    if (status == 'APPROVED') {
                      statusColor = const Color(0xFF10B981);
                      statusText = 'ĐÃ PHÊ DUYỆT';
                    } else if (status == 'REJECTED') {
                      statusColor = const Color(0xFFEF4444);
                      statusText = 'BỊ TỪ CHỐI';
                    } else {
                      statusColor = const Color(0xFFF59E0B);
                      statusText = 'ĐANG CHỜ DUYỆT';
                    }

                    String grantLabel;
                    if (grantType == 'FULL') {
                      grantLabel = 'Toàn quyền (Đề thi & Ca thi)';
                    } else if (grantType == 'EXAM_CREATION') {
                      grantLabel = 'Tổ chức & Giám sát ca thi';
                    } else {
                      grantLabel = 'Đóng góp câu hỏi & Soạn đề';
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  code,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  statusText,
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            name,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Quyền đề xuất: $grantLabel',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                          ),
                          if (date.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Ngày gửi: $date',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                            ),
                          ],
                          if (status == 'APPROVED' && sId.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => QuestionListPage(
                                        subjectId: sId,
                                        subjectCode: code,
                                        subjectName: name,
                                      ),
                                    ),
                                  ).then((_) => _loadData());
                                },
                                icon: const Icon(Icons.menu_book_outlined, size: 14),
                                label: const Text('Mở ngân hàng câu hỏi', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF0F172A),
                                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
