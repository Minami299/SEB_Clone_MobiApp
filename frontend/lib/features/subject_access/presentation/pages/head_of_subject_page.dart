import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/services/session_service.dart';
import '../../../auth/presentation/pages/profile_page.dart';
import '../../../question_bank/presentation/pages/question_list_page.dart';
import '../widgets/subject_card_widget.dart';
import '../widgets/pending_access_request_card.dart';
import '../widgets/exam_summary_report_card.dart';

class SubjectItem {
  final String id;
  final String code;
  final String name;
  final String description;
  final bool allowAutoGrading;
  String status; // 'ACTIVE' or 'INACTIVE'
  final String? departmentName;
  final String? creatorName;

  SubjectItem({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.allowAutoGrading,
    required this.status,
    this.departmentName,
    this.creatorName,
  });

  factory SubjectItem.fromJson(Map<String, dynamic> json) {
    String? dept;
    if (json['department_id'] is Map) {
      dept =
          json['department_id']['department_name'] ??
          json['department_id']['department_code'];
    }
    String? creator;
    if (json['created_by'] is Map) {
      creator = json['created_by']['full_name'];
    }

    return SubjectItem(
      id: json['_id'] ?? '',
      code: json['subject_code'] ?? '',
      name: json['subject_name'] ?? '',
      description: json['description'] ?? '',
      allowAutoGrading: json['allow_auto_grading'] == true,
      status: (json['status'] ?? 'ACTIVE').toString().toUpperCase(),
      departmentName: dept,
      creatorName: creator,
    );
  }

  bool get isActive => status == 'ACTIVE';
}

class HeadOfSubjectPage extends StatefulWidget {
  const HeadOfSubjectPage({super.key});

  @override
  State<HeadOfSubjectPage> createState() => _HeadOfSubjectPageState();
}

class _HeadOfSubjectPageState extends State<HeadOfSubjectPage> {
  final _apiClient = ApiClient();
  int _currentTabIndex = 0;

  List<SubjectItem> _subjects = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Requests tab data
  List<dynamic> _pendingRequests = [];
  bool _isLoadingRequests = false;
  String? _requestsError;

  // Reports / Exams tab data
  List<dynamic> _exams = [];
  bool _isLoadingExams = false;
  String? _examsError;

  Future<void> _fetchExams() async {
    setState(() {
      _isLoadingExams = true;
      _examsError = null;
    });
    try {
      final res = await _apiClient.get(ApiEndpoints.exams);
      if (res['success'] == true && res['data'] is List) {
        if (mounted) {
          setState(() {
            _exams = res['data'] as List;
            _isLoadingExams = false;
          });
        }
      } else {
        throw Exception(res['message'] ?? 'Không thể tải danh sách kỳ thi');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingExams = false;
          _examsError = e.toString().replaceAll('Exception:', '').trim();
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchSubjects();
  }

  Future<void> _fetchSubjects() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _apiClient.get(ApiEndpoints.subjectAccessSubjects);
      if (response['success'] == true && response['data'] is List) {
        final list = (response['data'] as List)
            .map((item) => SubjectItem.fromJson(item as Map<String, dynamic>))
            .toList();
        if (mounted) {
          setState(() {
            _subjects = list;
            _isLoading = false;
          });
        }
      } else {
        throw Exception(
          response['message'] ?? 'Không thể tải danh sách môn học',
        );
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

  Future<void> _toggleSubjectStatus(
    SubjectItem subject,
    bool nextActive,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(nextActive ? 'Kích hoạt môn học?' : 'Ngừng hoạt động môn học?'),
        content: Text(
          nextActive
              ? 'Bạn có chắc muốn kích hoạt ${subject.code} - ${subject.name}?'
              : 'Bạn có chắc muốn chuyển ${subject.code} - ${subject.name} sang ngừng hoạt động?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final originalStatus = subject.status;
    final nextStatus = nextActive ? 'ACTIVE' : 'INACTIVE';

    setState(() {
      subject.status = nextStatus;
    });

    try {
      final response = await _apiClient.patch(
        ApiEndpoints.subjectStatus(subject.id),
        body: {'status': nextStatus},
      );

      if (response['success'] != true) {
        throw Exception(response['message'] ?? 'Cập nhật trạng thái thất bại');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Đã chuyển ${subject.code} sang ${nextActive ? "đang hoạt động" : "ngừng hoạt động"}',
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: nextActive ? Colors.green : Colors.blueGrey,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          subject.status = originalStatus;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Lỗi: ${e.toString().replaceAll("Exception:", "").trim()}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _fetchPendingRequests() async {
    setState(() {
      _isLoadingRequests = true;
      _requestsError = null;
    });

    try {
      final response = await _apiClient.get(ApiEndpoints.subjectAccessPending);
      if (response['success'] == true && response['data'] is List) {
        if (mounted) {
          setState(() {
            _pendingRequests = response['data'] as List;
            _isLoadingRequests = false;
          });
        }
      } else {
        throw Exception(response['message'] ?? 'Không thể tải yêu cầu duyệt');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingRequests = false;
          _requestsError = e.toString().replaceAll('Exception:', '').trim();
        });
      }
    }
  }

  Future<void> _reviewRequest(String requestId, String status) async {
    try {
      final response = await _apiClient.patch(
        ApiEndpoints.subjectAccessReview(requestId),
        body: {'status': status},
      );
      if (response['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                status == 'APPROVED'
                    ? 'Đã phê duyệt yêu cầu'
                    : 'Đã từ chối yêu cầu',
              ),
              backgroundColor: status == 'APPROVED' ? Colors.green : Colors.red,
            ),
          );
        }
        await _fetchPendingRequests();
      } else {
        throw Exception(response['message'] ?? 'Không thể xử lý yêu cầu');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showSubjectDetails(SubjectItem subject) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  subject.code,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: subject.isActive
                        ? Colors.green.withAlpha(30)
                        : Colors.grey.withAlpha(40),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _subjectStatusLabel(subject.status),
                    style: TextStyle(
                      color: subject.isActive ? Colors.green : Colors.grey[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              subject.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155),
              ),
            ),
            const Divider(height: 24),
            _buildDetailRow(
              'Khoa / Bộ môn:',
              subject.departmentName ?? 'Chưa cập nhật',
            ),
            const SizedBox(height: 8),
            _buildDetailRow(
              'Người tạo môn:',
              subject.creatorName ?? 'Trưởng bộ môn',
            ),
            const SizedBox(height: 8),
            _buildDetailRow(
              'Chấm tự động:',
              subject.allowAutoGrading ? 'Cho phép' : 'Không',
            ),
            const SizedBox(height: 8),
            _buildDetailRow(
              'Mô tả:',
              subject.description.isNotEmpty
                  ? subject.description
                  : 'Không có mô tả',
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A5F),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Đóng'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: const TextStyle(color: Colors.black54, fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          ),
        ),
      ],
    );
  }

  String _subjectStatusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'ACTIVE':
        return 'Đang hoạt động';
      case 'INACTIVE':
        return 'Ngừng hoạt động';
      default:
        return status;
    }
  }

  Widget _buildPageHeading(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E293B),
              ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF64748B),
              ),
        ),
      ],
    );
  }

  Widget _buildSubjectsView() {
    final activeCount = _subjects.where((s) => s.isActive).length;
    final inactiveCount = _subjects.length - activeCount;

    return RefreshIndicator(
      onRefresh: _fetchSubjects,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header section matching the mockup
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPageHeading(
                  'Môn học',
                  'Quản lý trạng thái môn học và phân công giảng dạy.',
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_subjects.length} môn học',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      '$activeCount đang hoạt động · $inactiveCount ngừng hoạt động',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // Subject cards list
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
                          onPressed: _fetchSubjects,
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  )
                : _subjects.isEmpty
                ? const Center(child: Text('Không có môn học nào'))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: _subjects.length,
                    separatorBuilder: (context, _) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final subject = _subjects[index];
                      return _buildSubjectCard(subject);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectCard(SubjectItem subject) {
    return SubjectCardWidget(
      code: subject.code,
      name: subject.name,
      isActive: subject.isActive,
      onToggleStatus: (val) => _toggleSubjectStatus(subject, val),
      onViewDetails: () => _showSubjectDetails(subject),
    );
  }

  Widget _buildQBankView() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPageHeading(
            'Ngân hàng câu hỏi',
            'Quản lý ngân hàng câu hỏi theo từng môn học.',
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _subjects.isEmpty
                ? const Center(child: Text('Chưa có môn học nào'))
                : ListView.separated(
                    itemCount: _subjects.length,
                    separatorBuilder: (context, _) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final s = _subjects[index];
                      return ListTile(
                        tileColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        leading: const Icon(
                          Icons.menu_book,
                          color: Color(0xFF1E3A5F),
                        ),
                        title: Text(
                          '${s.code} - ${s.name}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text('Trạng thái: ${s.isActive ? "Đang hoạt động" : "Ngừng hoạt động"}'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => QuestionListPage(
                                subjectId: s.id,
                                subjectCode: s.code,
                                subjectName: s.name,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsView() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: _buildPageHeading(
                  'Yêu cầu cấp quyền',
                  'Duyệt yêu cầu truy cập môn học từ giảng viên.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoadingRequests
                ? const Center(child: CircularProgressIndicator())
                : _requestsError != null
                ? _buildLoadError(_requestsError!, _fetchPendingRequests)
                : _pendingRequests.isEmpty
                ? const Center(
                    child: Text('Hiện không có yêu cầu nào đang chờ duyệt'),
                  )
                : ListView.separated(
                    itemCount: _pendingRequests.length,
                    separatorBuilder: (context, _) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      return PendingAccessRequestCard(
                        request: _pendingRequests[index] as Map<String, dynamic>,
                        onReview: _reviewRequest,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportsView() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: _buildPageHeading(
                  'Báo cáo',
                  'Báo cáo và thống kê các kỳ thi của bộ môn.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoadingExams
                ? const Center(child: CircularProgressIndicator())
                : _examsError != null
                ? _buildLoadError(_examsError!, _fetchExams)
                : _exams.isEmpty
                ? const Center(child: Text('Chưa có ca thi nào'))
                : ListView.separated(
                    itemCount: _exams.length,
                    separatorBuilder: (context, _) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      return ExamSummaryReportCard(
                        exam: _exams[index] as Map<String, dynamic>,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadError(String message, VoidCallback onRetry) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            color: Color(0xFFDC2626),
            size: 32,
          ),
          const SizedBox(height: 8),
          Text('Không thể tải dữ liệu. $message', textAlign: TextAlign.center),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget currentBody;
    switch (_currentTabIndex) {
      case 0:
        currentBody = _buildSubjectsView();
        break;
      case 1:
        currentBody = _buildQBankView();
        break;
      case 2:
        currentBody = _buildRequestsView();
        break;
      case 3:
        currentBody = _buildReportsView();
        break;
      case 4:
      default:
        currentBody = const ProfilePage(showAppBar: false);
        break;
    }

    final currentUser = SessionService().currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0.5,
        title: InkWell(
          onTap: () {
            setState(() => _currentTabIndex = 4);
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: const Color(0xFF1E3A5F),
                  child: Text(
                    (currentUser?.fullName.isNotEmpty == true)
                        ? currentUser!.fullName[0].toUpperCase()
                        : 'U',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        currentUser?.fullName ?? 'Trưởng bộ môn',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        currentUser?.userCode.isNotEmpty == true
                            ? 'Mã: ${currentUser!.userCode}'
                            : (currentUser?.role == 'HEAD_OF_SUBJECT'
                                  ? 'Trưởng bộ môn'
                                  : (currentUser?.role ?? '')),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(child: currentBody),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentTabIndex,
          onTap: (index) {
            setState(() => _currentTabIndex = index);
            if (index == 2) _fetchPendingRequests();
            if (index == 3) _fetchExams();
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF173A5E),
          unselectedItemColor: const Color(0xFF94A3B8),
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.menu_book_outlined),
              activeIcon: Icon(Icons.menu_book),
              label: 'Môn học',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.description_outlined),
              activeIcon: Icon(Icons.description),
              label: 'Câu hỏi',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.group_outlined),
              activeIcon: Icon(Icons.group),
              label: 'Yêu cầu',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.pie_chart_outline),
              activeIcon: Icon(Icons.pie_chart),
              label: 'Báo cáo',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Tài khoản',
            ),
          ],
        ),
      ),
    );
  }
}
