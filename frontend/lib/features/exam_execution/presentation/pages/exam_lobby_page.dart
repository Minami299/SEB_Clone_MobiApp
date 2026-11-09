import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../data/datasources/exam_remote_datasource.dart';
import '../../data/models/question_item_model.dart';
import '../widgets/exam_lobby_header_card.dart';
import '../widgets/preflight_checklist_card.dart';
import 'exam_taking_page.dart';

class ExamLobbyPage extends StatefulWidget {
  final String examId;
  final String accessPin;
  final String examTitle;
  final String subjectCode;
  final int durationMinutes;
  final int maxViolations;

  const ExamLobbyPage({
    super.key,
    required this.examId,
    required this.accessPin,
    required this.examTitle,
    required this.subjectCode,
    required this.durationMinutes,
    required this.maxViolations,
  });

  @override
  State<ExamLobbyPage> createState() => _ExamLobbyPageState();
}

class _ExamLobbyPageState extends State<ExamLobbyPage> {
  final _apiClient = ApiClient();
  final _examDataSource = ExamRemoteDataSource();

  bool _isChecking = true;
  bool _serverConnected = false;
  bool _batterySufficient = true; // Thiết bị kiểm tra đạt chuẩn
  bool _rulesAgreed = false;
  bool _isStarting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _performPreflightChecks();
  }

  Future<void> _performPreflightChecks() async {
    setState(() {
      _isChecking = true;
      _errorMessage = null;
    });

    try {
      // 1. Kiểm tra kết nối tới server (Ping health)
      final healthRes = await _apiClient.get(ApiEndpoints.health);
      final isHealthy =
          healthRes['status'] == 'OK' || healthRes['success'] == true;

      // Giả lập kiểm tra thiết bị an toàn
      await Future.delayed(const Duration(milliseconds: 600));

      if (mounted) {
        setState(() {
          _serverConnected = isHealthy;
          _batterySufficient = true;
          _isChecking = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _serverConnected = false;
          _isChecking = false;
          _errorMessage =
              'Không thể kết nối đến máy chủ. Vui lòng kiểm tra lại mạng.';
        });
      }
    }
  }

  Future<void> _handleStartExam() async {
    if (!_serverConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chưa kết nối được với máy chủ'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_rulesAgreed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng đọc và đồng ý với nội quy phòng thi'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isStarting = true;
      _errorMessage = null;
    });

    try {
      final examData = await _examDataSource.startExam(
        examId: widget.examId,
        accessPin: widget.accessPin,
      );

      final dynamic rawQuestions = examData['questions'];
      final List<QuestionItemModel> questions;
      if (rawQuestions is List<QuestionItemModel>) {
        questions = rawQuestions;
      } else if (rawQuestions is List) {
        questions = rawQuestions.map((item) {
          if (item is QuestionItemModel) return item;
          return QuestionItemModel.fromJson(item as Map<String, dynamic>);
        }).toList();
      } else {
        questions = [];
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ExamTakingPage(
            examId: widget.examId,
            attemptId: examData['attempt_id'],
            examTitle: widget.examTitle,
            durationMinutes: widget.durationMinutes,
            maxViolations: widget.maxViolations,
            questions: questions,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isStarting = false;
        _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage!), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final canStart =
        _serverConnected && _batterySufficient && _rulesAgreed && !_isStarting;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text(
          'Kiểm tra điều kiện dự thi',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        backgroundColor: const Color(0xFF173A5E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Exam Header Card
            ExamLobbyHeaderCard(
              subjectCode: widget.subjectCode,
              examTitle: widget.examTitle,
              durationMinutes: widget.durationMinutes,
              maxViolations: widget.maxViolations,
              accessPin: widget.accessPin,
            ),

            const SizedBox(height: 20),

            // Pre-flight Checklist Card
            const Text(
              'Điều kiện trước khi vào thi',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF173A5E),
              ),
            ),
            const SizedBox(height: 10),

            PreflightChecklistCard(
              serverConnected: _serverConnected,
              batterySufficient: _batterySufficient,
            ),

            const SizedBox(height: 20),

            // Rules Card
            const Text(
              'Cam kết phòng thi an toàn',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF173A5E),
              ),
            ),
            const SizedBox(height: 10),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              padding: const EdgeInsets.all(16),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Không rời khỏi ứng dụng hoặc mở danh sách ứng dụng gần đây.',
                    style: TextStyle(fontSize: 13, height: 1.45),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Không chụp ảnh, quay màn hình hoặc chia sẻ câu hỏi thi.',
                    style: TextStyle(fontSize: 13, height: 1.45),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Mọi lần mất tiêu điểm màn hình sẽ được ghi nhận.',
                    style: TextStyle(fontSize: 13, height: 1.45),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Vượt giới hạn vi phạm sẽ đình chỉ bài thi tự động.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: Color(0xFFB42318),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Agreement Checkbox
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _rulesAgreed,
              activeColor: const Color(0xFF1E3A5F),
              title: const Text(
                'Tôi đã đọc và đồng ý tuân thủ nội quy phòng thi.',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
              onChanged: (val) => setState(() => _rulesAgreed = val ?? false),
            ),

            const SizedBox(height: 20),

            // Start Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: canStart ? _handleStartExam : null,
                icon: _isStarting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.play_arrow),
                label: Text(
                  _isStarting ? 'Đang khởi tạo ca thi...' : 'Bắt đầu làm bài',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF173A5E),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
