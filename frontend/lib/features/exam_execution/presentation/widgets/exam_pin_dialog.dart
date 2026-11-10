import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';

class ExamPinDialog extends StatefulWidget {
  final String examId;
  final String examTitle;

  const ExamPinDialog({
    super.key,
    required this.examId,
    required this.examTitle,
  });

  @override
  State<ExamPinDialog> createState() => _ExamPinDialogState();
}

class _ExamPinDialogState extends State<ExamPinDialog> {
  final _apiClient = ApiClient();
  Timer? _timer;
  String? _pin;
  String? _error;
  int _secondsUntilRefresh = 300;

  @override
  void initState() {
    super.initState();
    _loadPin();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_secondsUntilRefresh <= 1) {
        _loadPin();
      } else {
        setState(() => _secondsUntilRefresh--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadPin() async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.examCurrentPin(widget.examId),
      );
      final data = response['data'] as Map<String, dynamic>?;
      if (!mounted) return;
      setState(() {
        _pin = data?['access_pin']?.toString();
        _secondsUntilRefresh =
            (data?['refresh_seconds'] as num?)?.toInt() ?? 300;
        _error = _pin == null ? 'Ca thi chưa có mã vào thi.' : null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = 'Không thể tải mã vào thi: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Mã vào thi hiện tại'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.examTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red))
          else
            Text(
              _pin ?? '------',
              style: const TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w800,
                letterSpacing: 8,
                fontFamily: 'monospace',
              ),
            ),
          const SizedBox(height: 12),
          Text('Tự đổi sau $_secondsUntilRefresh giây'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Đóng'),
        ),
      ],
    );
  }
}
