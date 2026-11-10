import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';

class SubjectAccessDialog extends StatefulWidget {
  final String subjectId;
  final String subjectCode;
  final String subjectName;

  const SubjectAccessDialog({
    super.key,
    required this.subjectId,
    required this.subjectCode,
    required this.subjectName,
  });

  @override
  State<SubjectAccessDialog> createState() => _SubjectAccessDialogState();
}

class _SubjectAccessDialogState extends State<SubjectAccessDialog> {
  final _apiClient = ApiClient();
  List<dynamic> _accessRecords = [];
  List<dynamic> _lecturers = [];
  String? _selectedLecturerId;
  String? _error;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _apiClient.get(ApiEndpoints.subjectAccessForSubject(widget.subjectId)),
        _apiClient.get(ApiEndpoints.subjectAccessLecturers),
      ]);
      final accessResponse = results[0] as Map<String, dynamic>;
      final lecturerResponse = results[1] as Map<String, dynamic>;
      if (accessResponse['success'] != true || lecturerResponse['success'] != true) {
        throw Exception('Không thể tải danh sách quyền hoặc giảng viên');
      }
      if (!mounted) return;
      setState(() {
        _accessRecords = accessResponse['data'] as List<dynamic>;
        _lecturers = lecturerResponse['data'] as List<dynamic>;
        _selectedLecturerId = _availableLecturers.isNotEmpty
            ? _availableLecturers.first['_id']?.toString()
            : null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceAll('Exception:', '').trim();
      });
    }
  }

  List<dynamic> get _availableLecturers {
    final alreadyGranted = _accessRecords
        .where((record) => record['status'] == 'APPROVED')
        .map((record) => record['lecturer_id']?['_id']?.toString())
        .toSet();
    return _lecturers
        .where((lecturer) => !alreadyGranted.contains(lecturer['_id']?.toString()))
        .toList();
  }

  Future<void> _grantAccess() async {
    if (_selectedLecturerId == null) return;
    setState(() => _saving = true);
    try {
      await _apiClient.post(
        ApiEndpoints.subjectAccessGrant(widget.subjectId),
        body: {'lecturer_id': _selectedLecturerId, 'grant_type': 'INVITATION'},
      );
      await _loadData();
      if (mounted) setState(() => _saving = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString().replaceAll('Exception:', '').trim();
      });
    }
  }

  Future<void> _revokeAccess(Map<String, dynamic> record) async {
    final lecturer = record['lecturer_id'] as Map<String, dynamic>? ?? {};
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thu hồi quyền truy cập?'),
        content: Text('Giảng viên ${lecturer['full_name'] ?? ''} sẽ không còn quyền đóng góp câu hỏi cho môn này.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Thu hồi')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    try {
      await _apiClient.delete(
        ApiEndpoints.subjectAccessRevoke(widget.subjectId, record['_id'].toString()),
      );
      await _loadData();
      if (mounted) setState(() => _saving = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString().replaceAll('Exception:', '').trim();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Quyền giảng viên · ${widget.subjectCode}'),
      content: SizedBox(
        width: 440,
        child: _loading
            ? const SizedBox(height: 140, child: Center(child: CircularProgressIndicator()))
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.subjectName, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 16),
                    if (_error != null) ...[
                      Text(_error!, style: const TextStyle(color: Color(0xFFDC2626))),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: _loadData,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Thử lại'),
                        ),
                      ),
                    ],
                    if (_availableLecturers.isNotEmpty) ...[
                      DropdownButtonFormField<String>(
                        value: _selectedLecturerId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Chọn giảng viên'),
                        items: _availableLecturers.map((lecturer) {
                          final name = lecturer['full_name'] ?? 'Giảng viên';
                          final code = lecturer['user_code'] ?? '';
                          return DropdownMenuItem<String>(
                            value: lecturer['_id'].toString(),
                            child: Text('$name${code.isNotEmpty ? ' · $code' : ''}', overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: _saving ? null : (value) => setState(() => _selectedLecturerId = value),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _saving ? null : _grantAccess,
                          icon: const Icon(Icons.person_add_alt_1),
                          label: const Text('Cấp quyền cho môn học này'),
                        ),
                      ),
                    ] else
                      const Text('Không còn giảng viên phù hợp để cấp quyền trong khoa này.'),
                    const Divider(height: 28),
                    Text('Quyền đã cấp', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    ..._accessRecords.where((record) => record['status'] == 'APPROVED').map((record) {
                      final lecturer = record['lecturer_id'] as Map<String, dynamic>? ?? {};
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(lecturer['full_name'] ?? 'Giảng viên'),
                        subtitle: Text(lecturer['user_code'] ?? lecturer['email'] ?? ''),
                        trailing: IconButton(
                          tooltip: 'Thu hồi quyền',
                          onPressed: _saving ? null : () => _revokeAccess(record as Map<String, dynamic>),
                          icon: const Icon(Icons.person_remove_outlined, color: Color(0xFFDC2626)),
                        ),
                      );
                    }),
                    if (!_accessRecords.any((record) => record['status'] == 'APPROVED'))
                      const Text('Chưa có giảng viên nào được cấp quyền.'),
                  ],
                ),
              ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng'))],
    );
  }
}
