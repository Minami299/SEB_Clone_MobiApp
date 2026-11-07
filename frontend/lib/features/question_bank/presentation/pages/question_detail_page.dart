import 'package:flutter/material.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';

class QuestionDetailPage extends StatefulWidget {
  final String questionId;
  final String? questionCode;

  const QuestionDetailPage({
    super.key,
    required this.questionId,
    this.questionCode,
  });

  @override
  State<QuestionDetailPage> createState() => _QuestionDetailPageState();
}

class _QuestionDetailPageState extends State<QuestionDetailPage> {
  final _apiClient = ApiClient();
  Map<String, dynamic>? _questionData;
  List<dynamic> _options = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _apiClient.get(ApiEndpoints.questionDetail(widget.questionId));
      if (response['success'] == true && response['data'] != null) {
        if (mounted) {
          setState(() {
            _questionData = response['data']['question'];
            _options = response['data']['options'] as List? ?? [];
            _isLoading = false;
          });
        }
      } else {
        throw Exception(response['message'] ?? 'Không thể tải chi tiết câu hỏi');
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

  Color _getDifficultyColor(String? level) {
    switch (level?.toUpperCase()) {
      case 'EASY':
        return Colors.green;
      case 'HARD':
        return Colors.red;
      case 'MEDIUM':
      default:
        return Colors.orange;
    }
  }

  String _getDifficultyText(String? level) {
    switch (level?.toUpperCase()) {
      case 'EASY':
        return 'Dễ';
      case 'HARD':
        return 'Khó';
      case 'MEDIUM':
      default:
        return 'Trung bình';
    }
  }

  String _getTypeText(String? type) {
    switch (type?.toUpperCase()) {
      case 'SINGLE_CHOICE':
        return 'Trắc nghiệm (1 đáp án)';
      case 'MULTIPLE_CHOICE':
        return 'Trắc nghiệm (Nhiều đáp án)';
      case 'ESSAY':
        return 'Tự luận';
      default:
        return type ?? 'Không xác định';
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.questionCode?.isNotEmpty == true
        ? 'Câu hỏi: ${widget.questionCode}'
        : 'Chi tiết câu hỏi';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0.5,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _fetchDetail, child: const Text('Thử lại')),
                    ],
                  ),
                )
              : _questionData == null
                  ? const Center(child: Text('Không tìm thấy thông tin câu hỏi'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Metadata card
                          Container(
                            padding: const EdgeInsets.all(14.0),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _getDifficultyColor(_questionData!['difficulty_level']).withAlpha(25),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: _getDifficultyColor(_questionData!['difficulty_level'])),
                                      ),
                                      child: Text(
                                        'Độ khó: ${_getDifficultyText(_questionData!['difficulty_level'])}',
                                        style: TextStyle(
                                          color: _getDifficultyColor(_questionData!['difficulty_level']),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      'Điểm: ${_questionData!['default_score'] ?? 1.0}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E3A5F)),
                                    ),
                                  ],
                                ),
                                const Divider(height: 20),
                                _buildInfoRow('Loại câu hỏi:', _getTypeText(_questionData!['question_type'])),
                                const SizedBox(height: 6),
                                _buildInfoRow(
                                  'Chương học:',
                                  _questionData!['chapter_id'] is Map
                                      ? 'Chương ${_questionData!['chapter_id']['chapter_number']}: ${_questionData!['chapter_id']['chapter_title']}'
                                      : 'Chưa phân chương',
                                ),
                                if (_questionData!['created_by'] is Map) ...[
                                  const SizedBox(height: 6),
                                  _buildInfoRow('Người soạn:', _questionData!['created_by']['full_name'] ?? ''),
                                ],
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Question content
                          const Text(
                            'Nội dung câu hỏi:',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B)),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16.0),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Text(
                              _questionData!['content'] ?? '',
                              style: const TextStyle(fontSize: 16, height: 1.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Options or Essay
                          if (_questionData!['question_type'] == 'ESSAY') ...[
                            const Text(
                              'Ghi chú / Hướng dẫn trả lời tự luận:',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B)),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14.0),
                              decoration: BoxDecoration(
                                color: Colors.blue.withAlpha(15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Text(
                                _questionData!['description']?.toString().isNotEmpty == true
                                    ? _questionData!['description']
                                    : 'Câu hỏi tự luận yêu cầu sinh viên nhập câu trả lời trực tiếp.',
                                style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
                              ),
                            ),
                          ] else ...[
                            Text(
                              'Các đáp án lựa chọn (${_options.length}):',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B)),
                            ),
                            const SizedBox(height: 10),
                            ...List.generate(_options.length, (index) {
                              final opt = _options[index];
                              final isCorrect = opt['is_correct'] == true;
                              final optionLetter = String.fromCharCode(65 + index);

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: isCorrect ? const Color(0xFFECFDF5) : Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isCorrect ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                                    width: isCorrect ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor: isCorrect ? const Color(0xFF10B981) : const Color(0xFFF1F5F9),
                                      child: Text(
                                        optionLetter,
                                        style: TextStyle(
                                          color: isCorrect ? Colors.white : const Color(0xFF334155),
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        opt['option_content'] ?? '',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: isCorrect ? FontWeight.w600 : FontWeight.normal,
                                          color: isCorrect ? const Color(0xFF065F46) : const Color(0xFF1E293B),
                                        ),
                                      ),
                                    ),
                                    if (isCorrect) ...[
                                      const SizedBox(width: 8),
                                      const Chip(
                                        label: Text('ĐÚNG', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                        backgroundColor: Color(0xFF10B981),
                                        padding: EdgeInsets.zero,
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
                    ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1E293B))),
        ),
      ],
    );
  }
}
