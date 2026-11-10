import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';

class _ParsedQuestion {
  String content;
  List<Map<String, dynamic>> options;
  String correctLetter;

  _ParsedQuestion({
    required this.content,
    required this.options,
    required this.correctLetter,
  });
}

class BatchImportQuestionsPage extends StatefulWidget {
  final String subjectId;
  final String subjectCode;
  final String subjectName;

  const BatchImportQuestionsPage({
    super.key,
    required this.subjectId,
    required this.subjectCode,
    required this.subjectName,
  });

  @override
  State<BatchImportQuestionsPage> createState() =>
      _BatchImportQuestionsPageState();
}

class _BatchImportQuestionsPageState extends State<BatchImportQuestionsPage> {
  final _apiClient = ApiClient();
  final _textController = TextEditingController();

  List<dynamic> _chapters = [];
  String? _selectedChapterId;
  String _selectedDifficulty = 'MEDIUM';
  bool _isLoadingChapters = true;
  bool _isSaving = false;

  List<_ParsedQuestion> _parsedQuestions = [];
  bool _hasParsed = false;

  @override
  void initState() {
    super.initState();
    _loadChapters();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _loadChapters() async {
    try {
      final res = await _apiClient.get(
        ApiEndpoints.chaptersBySubject(widget.subjectId),
      );
      if (res['success'] == true && res['data'] is List) {
        if (mounted) {
          setState(() {
            _chapters = res['data'] as List;
            if (_chapters.isNotEmpty) {
              _selectedChapterId = _chapters[0]['_id'];
            }
            _isLoadingChapters = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingChapters = false);
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    if (data != null && data.text != null && data.text!.isNotEmpty) {
      setState(() {
        _textController.text = data.text!;
      });
    }
  }

  void _parseText() {
    final raw = _textController.text.trim();
    if (raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập hoặc dán nội dung câu hỏi'),
        ),
      );
      return;
    }

    final blocks = raw.split(
      RegExp(r'(?:(?:\r?\n\s*){2,}|(?=Câu\s+\d+[:.]))', caseSensitive: false),
    );
    final List<_ParsedQuestion> results = [];

    for (var block in blocks) {
      final lines = block
          .split(RegExp(r'\r?\n'))
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      if (lines.length < 3) continue;

      String questionContent = lines[0]
          .replaceFirst(RegExp(r'^Câu\s+\d+[:.]\s*', caseSensitive: false), '')
          .trim();
      List<Map<String, dynamic>> options = [];
      String correctLetter = 'A';

      for (int i = 1; i < lines.length; i++) {
        final line = lines[i];
        final ansMatch = RegExp(
          r'^(?:Đáp án|ANSWER|Key)[:\s]*([A-D])',
          caseSensitive: false,
        ).firstMatch(line);
        if (ansMatch != null) {
          correctLetter = ansMatch.group(1)!.toUpperCase();
          continue;
        }

        final optMatch = RegExp(
          r'^([A-D])[\.\:\)]\s*(.+)',
          caseSensitive: false,
        ).firstMatch(line);
        if (optMatch != null) {
          final letter = optMatch.group(1)!.toUpperCase();
          final text = optMatch.group(2)!.trim();
          options.add({
            'letter': letter,
            'option_content': text,
            'is_correct': false,
          });
        }
      }

      if (options.length >= 2) {
        for (var opt in options) {
          if (opt['letter'] == correctLetter) {
            opt['is_correct'] = true;
          }
        }
        results.add(
          _ParsedQuestion(
            content: questionContent,
            options: options,
            correctLetter: correctLetter,
          ),
        );
      }
    }

    if (results.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Không nhận diện được câu hỏi nào. Hãy kiểm tra định dạng A. B. C. D. và Đáp án: B',
          ),
        ),
      );
      return;
    }

    setState(() {
      _parsedQuestions = results;
      _hasParsed = true;
    });
  }

  Future<void> _saveAll() async {
    if (_parsedQuestions.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      final selectedChapter = _chapters.firstWhere(
        (c) => c['_id'] == _selectedChapterId,
        orElse: () => null,
      );
      final chapterNum = selectedChapter != null
          ? (selectedChapter['chapter_number'] ?? 1)
          : 1;

      final questionsPayload = _parsedQuestions
          .map(
            (q) => {
              'chapter_id': _selectedChapterId,
              'chapter_num': chapterNum,
              'difficulty': _selectedDifficulty,
              'content': q.content,
              'default_score': 1.0,
              'options': q.options
                  .map(
                    (o) => {
                      'option_content': o['option_content'],
                      'is_correct': o['is_correct'] == true,
                    },
                  )
                  .toList(),
            },
          )
          .toList();

      final res = await _apiClient.post(
        ApiEndpoints.questionsBatch,
        body: {'subject_id': widget.subjectId, 'questions': questionsPayload},
      );

      if (res['success'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Đã nhập thành công ${res['count'] ?? _parsedQuestions.length} câu hỏi vào Kho riêng!',
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        Navigator.pop(context, true);
      } else {
        throw Exception(res['message'] ?? 'Nhập câu hỏi thất bại');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Nhập hàng loạt - ${widget.subjectCode}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0.5,
      ),
      bottomNavigationBar: _hasParsed && _parsedQuestions.isNotEmpty
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: SafeArea(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveAll,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Lưu ${_parsedQuestions.length} câu hỏi vào Kho riêng',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ),
            )
          : null,
      body: _isLoadingChapters
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Chọn Chương & Độ khó gọn gàng
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedChapterId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Chương',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            isDense: true,
                          ),
                          items: _chapters.map((ch) {
                            return DropdownMenuItem<String>(
                              value: ch['_id'],
                              child: Text(
                                'Chương ${ch['chapter_number']}: ${ch['chapter_title']}',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedChapterId = val);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedDifficulty,
                          decoration: const InputDecoration(
                            labelText: 'Độ khó',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            isDense: true,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'EASY',
                              child: Text('Dễ', style: TextStyle(fontSize: 13)),
                            ),
                            DropdownMenuItem(
                              value: 'MEDIUM',
                              child: Text(
                                'Trung bình',
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'HARD',
                              child: Text(
                                'Khó',
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedDifficulty = val);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Nút tiện ích: Dán từ Clipboard
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Nội dung đề thi:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      InkWell(
                        onTap: _pasteFromClipboard,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          child: Text(
                            'Dán văn bản',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF2563EB),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Khung nhập văn bản
                  TextField(
                    controller: _textController,
                    maxLines: 8,
                    style: const TextStyle(fontSize: 13, height: 1.4),
                    decoration: InputDecoration(
                      hintText: 'Dán đề bài tại đây...\n\nCâu 1: Thuật toán nào có độ phức tạp O(1)?\nA. Tìm kiếm nhị phân\nB. Truy cập mảng theo chỉ số\nĐáp án: B',
                      hintStyle: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Nút phân tích
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _parseText,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Phân tích câu hỏi',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),

                  // Danh sách câu hỏi đã bóc tách xem trước
                  if (_hasParsed) ...[
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Đã nhận diện (${_parsedQuestions.length} câu):',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        InkWell(
                          onTap: () => setState(() {
                            _parsedQuestions.clear();
                            _hasParsed = false;
                          }),
                          child: const Text(
                            'Xóa kết quả',
                            style: TextStyle(fontSize: 12, color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _parsedQuestions.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final q = _parsedQuestions[index];

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${index + 1}. ${q.content}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.close,
                                      size: 16,
                                      color: Color(0xFF94A3B8),
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () {
                                      setState(() {
                                        _parsedQuestions.removeAt(index);
                                        if (_parsedQuestions.isEmpty) {
                                          _hasParsed = false;
                                        }
                                      });
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              ...q.options.map((opt) {
                                final isCorrect = opt['is_correct'] == true;
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 4),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isCorrect
                                        ? const Color(0xFFECFDF5)
                                        : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isCorrect
                                          ? const Color(0xFFA7F3D0)
                                          : const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        '${opt['letter']}. ',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: isCorrect
                                              ? const Color(0xFF065F46)
                                              : const Color(0xFF334155),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          opt['option_content'] ?? '',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: isCorrect
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            color: isCorrect
                                                ? const Color(0xFF065F46)
                                                : const Color(0xFF334155),
                                          ),
                                        ),
                                      ),
                                      if (isCorrect)
                                        const Text(
                                          '✓ Đúng',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF059669),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 80),
                  ],
                ],
              ),
            ),
    );
  }
}
