import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../domain/entities/exam_entity.dart';

class ExamLivePinDialog extends StatefulWidget {
  final ExamEntity exam;
  final VoidCallback onRefresh;

  const ExamLivePinDialog({
    super.key,
    required this.exam,
    required this.onRefresh,
  });

  @override
  State<ExamLivePinDialog> createState() => _ExamLivePinDialogState();
}

class _ExamLivePinDialogState extends State<ExamLivePinDialog> {
  final _apiClient = ApiClient();
  Timer? _countdownTimer;
  Timer? _pinRotatedNoticeTimer;

  String _currentPin = '';
  int _remainingSeconds = 300;
  int _intervalSeconds = 300;
  int _totalCandidates = 0;
  int _activeAttempts = 0;
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _pinJustRotated = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _currentPin = '------';
    _fetchLivePin();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pinRotatedNoticeTimer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        // Hết 5 phút -> tự động refresh mã mới từ server
        _fetchLivePin(isAutoRotate: true);
      }
    });
  }

  Future<void> _fetchLivePin({bool isAutoRotate = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _apiClient.get(
        ApiEndpoints.examLivePin(widget.exam.id),
      );
      if (res['success'] == true && res['data'] != null) {
        final data = res['data'];
        if (mounted) {
          final newPin = data['access_pin']?.toString() ?? _currentPin;
          final didChange =
              _currentPin.isNotEmpty &&
              _currentPin != '------' &&
              _currentPin != newPin;

          setState(() {
            _currentPin = newPin;
            _remainingSeconds =
                (data['remaining_seconds'] as num?)?.toInt() ?? 300;
            _intervalSeconds =
                (data['interval_seconds'] as num?)?.toInt() ?? 300;
            _totalCandidates =
                (data['total_candidates'] as num?)?.toInt() ?? _totalCandidates;
            _activeAttempts =
                (data['active_attempts'] as num?)?.toInt() ?? _activeAttempts;
            _isLoading = false;
            if (isAutoRotate || didChange) {
              _pinJustRotated = true;
            }
          });

          if (isAutoRotate || didChange) {
            try {
              HapticFeedback.heavyImpact();
            } catch (_) {}
            _pinRotatedNoticeTimer?.cancel();
            _pinRotatedNoticeTimer = Timer(const Duration(seconds: 20), () {
              if (mounted) setState(() => _pinJustRotated = false);
            });
          }

          _startTimer();
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Không thể đồng bộ mã PIN: $e';
        });
      }
    }
  }

  Future<void> _handleForceRefresh() async {
    setState(() {
      _isRefreshing = true;
    });

    try {
      final res = await _apiClient.post(
        ApiEndpoints.examRefreshPin(widget.exam.id),
      );
      if (res['success'] == true && res['data'] != null) {
        final data = res['data'];
        if (mounted) {
          setState(() {
            _currentPin = data['access_pin'] ?? _currentPin;
            _remainingSeconds =
                (data['remaining_seconds'] as num?)?.toInt() ?? 300;
            _intervalSeconds =
                (data['interval_seconds'] as num?)?.toInt() ?? 300;
            _totalCandidates =
                (data['total_candidates'] as num?)?.toInt() ?? _totalCandidates;
            _activeAttempts =
                (data['active_attempts'] as num?)?.toInt() ?? _activeAttempts;
            _isRefreshing = false;
            _pinJustRotated = true;
          });
          _pinRotatedNoticeTimer?.cancel();
          _pinRotatedNoticeTimer = Timer(const Duration(seconds: 20), () {
            if (mounted) setState(() => _pinJustRotated = false);
          });
          widget.onRefresh();
          _startTimer();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã làm mới mã PIN ca thi thành công.'),
              backgroundColor: Color(0xFF10B981),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _formatTime(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _formatPin(String pin) {
    if (pin.length == 6) {
      return '${pin.substring(0, 3)}  ${pin.substring(3)}';
    }
    return pin;
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.exam.status.toUpperCase().trim();
    final isOpen =
        (s == 'PUBLISHED' ||
        s == 'ONGOING' ||
        s == 'IN_PROGRESS' ||
        s == 'ACTIVE');
    final progress = _intervalSeconds > 0
        ? (_remainingSeconds / _intervalSeconds).clamp(0.0, 1.0)
        : 0.0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Row Tiêu đề & Đóng
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.qr_code_2,
                        color: Color(0xFF1E3A5F),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'MÃ PIN PHÒNG THI',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          widget.exam.subjectCode.isNotEmpty
                              ? widget.exam.subjectCode
                              : 'SEB EXAM',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.close,
                    size: 20,
                    color: Color(0xFF94A3B8),
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Tên ca thi
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.exam.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isOpen
                          ? const Color(0xFFECFDF5)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isOpen ? '• Đang mở' : 'Chưa mở',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isOpen
                            ? const Color(0xFF047857)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                  if (_totalCandidates > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Text(
                        'Đã vào: $_activeAttempts/$_totalCandidates',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1D4ED8),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            if (_pinJustRotated) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFF59E0B)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.campaign, color: Color(0xFFD97706), size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Mã PIN vừa đổi mới! Thầy/cô vui lòng đọc mã mới này cho thí sinh.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFDC2626),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],

            const SizedBox(height: 18),

            // Box Hiển thị Mã PIN cỡ lớn kiểu Máy chiếu (Dark Navy Theme)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
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
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    'MÃ VÀO THI DÀNH CHO SINH VIÊN',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  else
                    SelectableText(
                      _formatPin(_currentPin),
                      style: const TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 6,
                        fontFamily: 'monospace',
                      ),
                    ),

                  const SizedBox(height: 14),

                  // Thanh đếm ngược 5 phút
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.timer_outlined,
                        size: 14,
                        color: Color(0xFF38BDF8),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Tự động đổi mã sau: ${_formatTime(_remainingSeconds)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF38BDF8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      height: 4,
                      width: 180,
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.white.withValues(alpha: 0.15),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF38BDF8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Nút Thao tác: Copy & Đổi mã ngay
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _currentPin.isNotEmpty
                        ? () {
                            Clipboard.setData(ClipboardData(text: _currentPin));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Đã sao chép mã PIN: $_currentPin',
                                ),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          }
                        : null,
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text(
                      'Sao chép PIN',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1E3A5F),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isRefreshing ? null : _handleForceRefresh,
                    icon: _isRefreshing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.refresh, size: 16),
                    label: const Text(
                      'Đổi mã mới ngay',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A5F),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
