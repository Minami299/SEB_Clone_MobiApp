import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import 'pending_access_request_card.dart';

class PendingAccessRequestsDialog extends StatefulWidget {
  const PendingAccessRequestsDialog({super.key});

  @override
  State<PendingAccessRequestsDialog> createState() =>
      _PendingAccessRequestsDialogState();
}

class _PendingAccessRequestsDialogState
    extends State<PendingAccessRequestsDialog> {
  final _apiClient = ApiClient();
  List<dynamic> _requests = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await _apiClient.get(ApiEndpoints.subjectAccessPending);
      if (response['success'] != true || response['data'] is! List) {
        throw Exception(response['message'] ?? 'Không thể tải danh sách yêu cầu');
      }
      if (!mounted) return;
      setState(() {
        _requests = response['data'] as List<dynamic>;
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

  Future<void> _reviewRequest(String id, String status) async {
    try {
      final response = await _apiClient.patch(
        ApiEndpoints.subjectAccessReview(id),
        body: {'status': status},
      );
      if (response['success'] != true) {
        throw Exception(response['message'] ?? 'Không thể xử lý yêu cầu');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(status == 'APPROVED' ? 'Đã phê duyệt yêu cầu' : 'Đã từ chối yêu cầu'),
        ),
      );
      await _loadRequests();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceAll('Exception:', '').trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final dialogHeight =
        (MediaQuery.sizeOf(context).height * 0.65).clamp(240.0, 520.0).toDouble();
    return AlertDialog(
      title: const Text('Yêu cầu cấp quyền đang chờ'),
      content: SizedBox(
        width: 520,
        height: dialogHeight,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _loadRequests,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Thử lại'),
                    ),
                  ],
                ),
              )
            : _requests.isEmpty
            ? const Center(child: Text('Hiện không có yêu cầu nào đang chờ duyệt.'))
            : ListView.separated(
                itemCount: _requests.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) => PendingAccessRequestCard(
                  request: _requests[index] as Map<String, dynamic>,
                  onReview: _reviewRequest,
                ),
              ),
      ),
      actions: [
        TextButton(onPressed: _loadRequests, child: const Text('Làm mới')),
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng')),
      ],
    );
  }
}
