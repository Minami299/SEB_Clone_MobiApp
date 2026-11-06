import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/datasources/exam_remote_datasource.dart';
import '../../data/models/question_item_model.dart';

class ExamTakingPage extends StatefulWidget {
  final String examId;
  final String attemptId;
  final String examTitle;
  final int durationMinutes;
  final int maxViolations;
  final List<QuestionItemModel> questions;

  const ExamTakingPage({
    super.key,
    required this.examId,
    required this.attemptId,
    required this.examTitle,
    required this.durationMinutes,
    required this.maxViolations,
    required this.questions,
  });

  @override
  State<ExamTakingPage> createState() => _ExamTakingPageState();
}

class _ExamTakingPageState extends State<ExamTakingPage> with WidgetsBindingObserver {
  final _examDataSource = ExamRemoteDataSource();

  int _currentIndex = 0;
  final Map<String, String> _selectedAnswers = {}; // questionId -> optionId
  int _violationCount = 0;
  bool _isTerminated = false;
  bool _isSubmitting = false;
  bool _canExit = false;
  DateTime? _lastViolationTime;

  late int _remainingSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _remainingSeconds = widget.durationMinutes * 60;
    _startTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        _timer?.cancel();
        _handleForceSubmit('Hết giờ làm bài!');
      }
    });
  }

  // Giám sát an toàn SEB (Kiosk Mode / Anti-cheat)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (_isTerminated || _isSubmitting || _canExit) return;

    // Khi thí sinh rời app, chuyển app hoặc mở đa nhiệm/thanh thông báo
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      final now = DateTime.now();
      if (_lastViolationTime == null || now.difference(_lastViolationTime!).inSeconds >= 2) {
        _lastViolationTime = now;
        _triggerViolation('Ứng dụng bị mất tiêu điểm (chuyển màn hình hoặc mở ứng dụng khác)');
      }
    }
  }

  Future<void> _triggerViolation(String reason) async {
    setState(() {
      _violationCount++;
    });

    try {
      final res = await _examDataSource.reportViolation(
        attemptId: widget.attemptId,
        examId: widget.examId,
        violationType: 'APP_UNFOCUSED',
        details: reason,
      );
      if (res['is_disqualified'] == true && !_isTerminated) {
        _isTerminated = true;
        _timer?.cancel();
        _handleForceSubmit('Bài thi bị đình chỉ tự động: Vượt quá số lần vi phạm an toàn');
        return;
      }
    } catch (_) {
      // Bỏ qua lỗi mạng
    }

    if (_violationCount >= widget.maxViolations) {
      if (!_isTerminated) {
        _isTerminated = true;
        _timer?.cancel();
        _handleForceSubmit('Bài thi bị đình chỉ tự động: Vượt quá số lần vi phạm an toàn (${widget.maxViolations})');
      }
    } else {
      _showViolationWarningDialog(reason);
    }
  }

  void _showViolationWarningDialog(String reason) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('CẢNH BÁO VI PHẠM', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(reason),
            const SizedBox(height: 12),
            Text(
              'Số lần vi phạm: $_violationCount / ${widget.maxViolations}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent),
            ),
            const SizedBox(height: 4),
            const Text(
              'Chú ý: Nếu đạt tới giới hạn vi phạm, hệ thống sẽ tự động đình chỉ và khóa bài thi ngay lập tức.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Đã hiểu và tiếp tục'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleOptionSelect(String questionId, String optionId) async {
    setState(() {
      _selectedAnswers[questionId] = optionId;
    });

    // Auto-save câu trả lời
    try {
      await _examDataSource.saveAnswer(
        attemptId: widget.attemptId,
        questionId: questionId,
        selectedOptionId: optionId,
      );
    } catch (_) {
      // Bỏ qua lỗi mạng nền để không gián đoạn thao tác của thí sinh
    }
  }

  Future<void> _handleForceSubmit(String reason) async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      final result = await _examDataSource.submitExam(attemptId: widget.attemptId);
      if (!mounted) return;
      _showResultDialog(result, forceReason: reason);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi nộp bài: $e')),
      );
    }
  }

  Future<void> _confirmSubmit() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận nộp bài'),
        content: Text(
          'Bạn đã hoàn thành ${_selectedAnswers.length}/${widget.questions.length} câu. Bạn có chắc chắn muốn kết thúc bài thi?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Làm tiếp')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
            child: const Text('Nộp bài'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _timer?.cancel();
      _handleForceSubmit('Thí sinh chủ động nộp bài');
    }
  }

  void _showResultDialog(Map<String, dynamic> result, {String? forceReason}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(
          _isTerminated ? 'BÀI THI BỊ ĐÌNH CHỈ' : 'KẾT QUẢ BÀI THI',
          style: TextStyle(
            color: _isTerminated ? Colors.red : Colors.green[800],
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (forceReason != null) ...[
              Text(forceReason, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
            ],
            Text('Tổng điểm đạt được: ${result['total_score']}'),
            const SizedBox(height: 4),
            Text(
              'Trạng thái: ${result['is_passed'] == true ? "ĐẠT (PASSED)" : "KHÔNG ĐẠT (FAILED)"}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: result['is_passed'] == true ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(height: 4),
            Text('Số lỗi vi phạm ghi nhận: $_violationCount'),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              _canExit = true;
              Navigator.pop(ctx); // Đóng dialog
              Navigator.pop(context); // Quay về danh sách bài thi
            },
            child: const Text('Hoàn tất'),
          ),
        ],
      ),
    );
  }

  String _formatTimer(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.examTitle)),
        body: const Center(child: Text('Đề thi chưa có câu hỏi nào')),
      );
    }

    final currentQuestion = widget.questions[_currentIndex];
    final selectedOption = _selectedAnswers[currentQuestion.id];

    return WillPopScope(
      onWillPop: () async {
        if (_canExit) return true;
        // Chặn nút Back cứng của Android để chống thoát bài thi
        _triggerViolation('Cố ý nhấn nút Back để thoát ứng dụng');
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(widget.examTitle),
          backgroundColor: Colors.blueAccent,
          foregroundColor: Colors.white,
          actions: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              decoration: BoxDecoration(
                color: _remainingSeconds < 300 ? Colors.red : Colors.white24,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    _formatTimer(_remainingSeconds),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.check_circle_outline),
              tooltip: 'Nộp bài',
              onPressed: _isSubmitting ? null : _confirmSubmit,
            ),
          ],
        ),
        body: Column(
          children: [
            // Thanh trạng thái vi phạm
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: _violationCount > 0 ? Colors.red[50] : Colors.blue[50],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Câu ${_currentIndex + 1} / ${widget.questions.length}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      Icon(Icons.shield, size: 16, color: _violationCount > 0 ? Colors.red : Colors.blue),
                      const SizedBox(width: 4),
                      Text(
                        'Vi phạm: $_violationCount / ${widget.maxViolations}',
                        style: TextStyle(
                          color: _violationCount > 0 ? Colors.red : Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Khung nội dung câu hỏi và các lựa chọn
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Câu ${_currentIndex + 1}: ${currentQuestion.content}',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    ...currentQuestion.options.map((opt) {
                      final isSelected = selectedOption == opt.id;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.blue[50] : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? Colors.blueAccent : Colors.grey.shade300,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: RadioListTile<String>(
                          value: opt.id,
                          groupValue: selectedOption,
                          title: Text(opt.content),
                          onChanged: (val) {
                            if (val != null) {
                              _handleOptionSelect(currentQuestion.id, val);
                            }
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),

            // Thanh điều hướng Trước / Sau
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, -2)),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton.icon(
                    onPressed: _currentIndex > 0
                        ? () {
                            setState(() {
                              _currentIndex--;
                            });
                          }
                        : null,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Câu trước'),
                  ),
                  _currentIndex < widget.questions.length - 1
                      ? ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _currentIndex++;
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text('Câu tiếp'),
                        )
                      : ElevatedButton.icon(
                          onPressed: _isSubmitting ? null : _confirmSubmit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.done_all),
                          label: const Text('Hoàn thành'),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

