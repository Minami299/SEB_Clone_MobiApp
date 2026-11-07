import 'package:flutter/material.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../widgets/exam_result_review_tile.dart';
import '../widgets/exam_result_score_card.dart';
import 'exam_list_page.dart';

class ExamResultPage extends StatefulWidget {
  final String attemptId;

  const ExamResultPage({
    super.key,
    required this.attemptId,
  });

  @override
  State<ExamResultPage> createState() => _ExamResultPageState();
}

class _ExamResultPageState extends State<ExamResultPage> {
  final _apiClient = ApiClient();
  Map<String, dynamic>? _resultData;
  bool _isLoading = true;
  String? _errorMessage;
  bool _showReview = false;

  @override
  void initState() {
    super.initState();
    _fetchResult();
  }

  Future<void> _fetchResult() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _apiClient.get(ApiEndpoints.examResult(widget.attemptId));
      if (response['success'] == true && response['data'] != null) {
        if (mounted) {
          setState(() {
            _resultData = response['data'] as Map<String, dynamic>;
            _isLoading = false;
          });
        }
      } else {
        throw Exception(response['message'] ?? 'Không thể tải kết quả thi');
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null || _resultData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Kết quả thi')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_errorMessage ?? 'Lỗi tải dữ liệu', style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _fetchResult, child: const Text('Thử lại')),
            ],
          ),
        ),
      );
    }

    final data = _resultData!;
    final totalScore = data['total_score'] ?? 0;
    final maxScore = data['max_score'] ?? 10;
    final percentage = data['percentage'] ?? 0;
    final isPassed = data['is_passed'] == true;
    final isDisqualified = data['status'] == 'DISQUALIFIED' || data['status'] == 'SUSPENDED';
    final correctCount = data['correct_count'] ?? 0;
    final wrongCount = data['wrong_count'] ?? 0;
    final unansweredCount = data['unanswered_count'] ?? 0;
    final totalQuestions = data['total_questions'] ?? 0;
    final durationSeconds = data['duration_taken_seconds'] ?? 0;
    final allowReview = data['allow_review'] == true;
    final List<dynamic> reviewQuestions = data['review_questions'] as List? ?? [];

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const ExamListPage()),
          (route) => false,
        );
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('Kết quả ca thi', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1E293B),
          elevation: 0.5,
          automaticallyImplyLeading: false,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Status Badge & Icon
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDisqualified
                      ? Colors.red.withAlpha(25)
                      : isPassed
                          ? Colors.green.withAlpha(25)
                          : Colors.orange.withAlpha(25),
                ),
                child: Icon(
                  isDisqualified
                      ? Icons.cancel
                      : isPassed
                          ? Icons.check_circle
                          : Icons.info,
                  size: 42,
                  color: isDisqualified
                      ? Colors.red
                      : isPassed
                          ? Colors.green
                          : Colors.orange,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                isDisqualified
                    ? 'BÀI THI BỊ ĐÌNH CHỈ'
                    : isPassed
                        ? 'HOÀN THÀNH XUẤT SẮC'
                        : 'HOÀN THÀNH BÀI THI',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDisqualified
                      ? Colors.red
                      : isPassed
                          ? Colors.green
                          : const Color(0xFF1E293B),
                ),
              ),

              const SizedBox(height: 6),
              Text(
                data['exam_title'] ?? '',
                style: const TextStyle(fontSize: 15, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
              ),

              const SizedBox(height: 20),

              // Score Card (Extracted to Widget)
              ExamResultScoreCard(
                totalScore: totalScore,
                maxScore: maxScore,
                percentage: percentage,
                isPassed: isPassed,
                isDisqualified: isDisqualified,
                correctCount: correctCount,
                wrongCount: wrongCount,
                unansweredCount: unansweredCount,
                totalQuestions: totalQuestions,
                durationSeconds: durationSeconds,
              ),

              const SizedBox(height: 16),

              // Review Exam Section
              if (allowReview && reviewQuestions.isNotEmpty) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() => _showReview = !_showReview),
                    icon: Icon(_showReview ? Icons.visibility_off : Icons.visibility),
                    label: Text(_showReview ? 'Ẩn đáp án chi tiết' : 'Xem lại bài thi chi tiết'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1E3A5F),
                      side: const BorderSide(color: Color(0xFF1E3A5F)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                if (_showReview) ...[
                  const SizedBox(height: 16),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: reviewQuestions.length,
                    separatorBuilder: (context, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      return ExamResultReviewTile(
                        index: index,
                        reviewQuestion: reviewQuestions[index] as Map<String, dynamic>,
                      );
                    },
                  ),
                ],
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withAlpha(15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Ca thi này không cho phép xem lại chi tiết đáp án trước khi toàn bộ thí sinh hoàn thành.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Color(0xFF1E3A5F)),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Back to Home Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const ExamListPage()),
                      (route) => false,
                    );
                  },
                  icon: const Icon(Icons.home),
                  label: const Text('Quay về trang chủ', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A5F),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
