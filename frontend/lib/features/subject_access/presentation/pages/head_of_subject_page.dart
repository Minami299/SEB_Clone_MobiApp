import 'package:flutter/material.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/services/session_service.dart';
import '../../../auth/presentation/pages/login_page.dart';

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
      dept = json['department_id']['department_name'] ?? json['department_id']['department_code'];
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
        throw Exception(response['message'] ?? 'Không thể tải danh sách môn học');
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

  Future<void> _toggleSubjectStatus(SubjectItem subject, bool nextActive) async {
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
            content: Text('Đã chuyển ${subject.code} sang ${nextActive ? "Active" : "Inactive"}'),
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
            content: Text('Lỗi: ${e.toString().replaceAll("Exception:", "").trim()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _fetchPendingRequests() async {
    setState(() {
      _isLoadingRequests = true;
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
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingRequests = false;
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
              content: Text(status == 'APPROVED' ? 'Đã phê duyệt yêu cầu' : 'Đã từ chối yêu cầu'),
              backgroundColor: status == 'APPROVED' ? Colors.green : Colors.red,
            ),
          );
        }
        _fetchPendingRequests();
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
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: subject.isActive ? Colors.green.withAlpha(30) : Colors.grey.withAlpha(40),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    subject.status,
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
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
            ),
            const Divider(height: 24),
            _buildDetailRow('Khoa / Bộ môn:', subject.departmentName ?? 'Chưa cập nhật'),
            const SizedBox(height: 8),
            _buildDetailRow('Người tạo môn:', subject.creatorName ?? 'Trưởng bộ môn'),
            const SizedBox(height: 8),
            _buildDetailRow('Chấm tự động:', subject.allowAutoGrading ? 'Cho phép' : 'Không'),
            const SizedBox(height: 8),
            _buildDetailRow('Mô tả:', subject.description.isNotEmpty ? subject.description : 'Không có mô tả'),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A5F),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
          child: Text(label, style: const TextStyle(color: Colors.black54, fontSize: 13)),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
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
                const Text(
                  'Subjects',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Manage subject availability and teaching assignments.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_subjects.length} subjects',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      '$activeCount active - $inactiveCount inactive',
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
                            Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
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
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: _subjects.length,
                            separatorBuilder: (context, _) => const SizedBox(height: 12),
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Code and Switch toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                subject.code,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 28,
                    child: Switch(
                      value: subject.isActive,
                      activeColor: Colors.white,
                      activeTrackColor: const Color(0xFF1E3A5F),
                      inactiveThumbColor: Colors.white,
                      inactiveTrackColor: const Color(0xFFCBD5E1),
                      onChanged: (val) => _toggleSubjectStatus(subject, val),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subject.isActive ? 'Active' : 'Inactive',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Row 2: Subject name
          Text(
            subject.name,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          // Row 3: Status label & View Details button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Subject availability',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                ),
              ),
              OutlinedButton(
                onPressed: () => _showSubjectDetails(subject),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1E293B),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: const Text(
                  'View Details',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQBankView() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Q-Bank',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 4),
          const Text(
            'Quản lý ngân hàng câu hỏi theo từng môn học.',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _subjects.isEmpty
                ? const Center(child: Text('Chưa có môn học nào'))
                : ListView.separated(
                    itemCount: _subjects.length,
                    separatorBuilder: (context, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final s = _subjects[index];
                      return ListTile(
                        tileColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        leading: const Icon(Icons.menu_book, color: Color(0xFF1E3A5F)),
                        title: Text('${s.code} - ${s.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Text('Trạng thái: ${s.status}'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Xem câu hỏi môn ${s.code}')),
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
              const Text(
                'Requests',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _fetchPendingRequests,
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Duyệt yêu cầu đăng ký quyền môn học từ giảng viên.',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoadingRequests
                ? const Center(child: CircularProgressIndicator())
                : _pendingRequests.isEmpty
                    ? const Center(child: Text('Hiện không có yêu cầu nào đang chờ duyệt'))
                    : ListView.separated(
                        itemCount: _pendingRequests.length,
                        separatorBuilder: (context, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final req = _pendingRequests[index];
                          final id = req['_id'] ?? '';
                          final lecName = req['lecturer_id']?['full_name'] ?? 'Giảng viên';
                          final lecEmail = req['lecturer_id']?['email'] ?? '';
                          final subjCode = req['subject_id']?['subject_code'] ?? '';
                          final subjName = req['subject_id']?['subject_name'] ?? '';
                          final grantType = req['grant_type'] ?? 'QUESTION_CONTRIBUTION';

                          return Card(
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    lecName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  Text('$lecEmail | Môn: $subjCode ($subjName)', style: const TextStyle(color: Colors.black54, fontSize: 13)),
                                  const SizedBox(height: 4),
                                  Text('Loại quyền: $grantType', style: const TextStyle(color: Colors.blueGrey, fontSize: 12)),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton(
                                        onPressed: () => _reviewRequest(id, 'REJECTED'),
                                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                                        child: const Text('Từ chối'),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton(
                                        onPressed: () => _reviewRequest(id, 'APPROVED'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                        ),
                                        child: const Text('Phê duyệt'),
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

  Widget _buildReportsView() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Reports',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 4),
          const Text(
            'Báo cáo và thống kê các kỳ thi của bộ môn.',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 20),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            child: const Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tổng quan vi phạm', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  SizedBox(height: 8),
                  Text('Chưa ghi nhận vi phạm nghiêm trọng nào trong các ca thi gần đây.', style: TextStyle(color: Colors.black54)),
                ],
              ),
            ),
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
      default:
        currentBody = _buildReportsView();
        break;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          _currentTabIndex == 0
              ? 'Trưởng bộ môn'
              : _currentTabIndex == 1
                  ? 'Ngân hàng câu hỏi'
                  : _currentTabIndex == 2
                      ? 'Duyệt yêu cầu'
                      : 'Báo cáo',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
            onPressed: () {
              if (_currentTabIndex == 0) _fetchSubjects();
              if (_currentTabIndex == 2) _fetchPendingRequests();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
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
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF1E3A5F),
          unselectedItemColor: const Color(0xFF94A3B8),
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.menu_book_outlined),
              activeIcon: Icon(Icons.menu_book),
              label: 'Subjects',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.description_outlined),
              activeIcon: Icon(Icons.description),
              label: 'Q-Bank',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.group_outlined),
              activeIcon: Icon(Icons.group),
              label: 'Requests',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.pie_chart_outline),
              activeIcon: Icon(Icons.pie_chart),
              label: 'Reports',
            ),
          ],
        ),
      ),
    );
  }
}
