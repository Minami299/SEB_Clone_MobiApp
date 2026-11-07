import 'package:flutter/material.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/services/session_service.dart';

class CreateQuestionPage extends StatefulWidget {
  final String subjectId;
  final String subjectCode;
  final String subjectName;

  const CreateQuestionPage({
    super.key,
    required this.subjectId,
    required this.subjectCode,
    required this.subjectName,
  });

  @override
  State<CreateQuestionPage> createState() => _CreateQuestionPageState();
}

class _OptionInput {
  final TextEditingController controller;
  bool isCorrect;

  _OptionInput({required this.controller, this.isCorrect = false});
}

class _CreateQuestionPageState extends State<CreateQuestionPage> {
  final _formKey = GlobalKey<FormState>();
  final _apiClient = ApiClient();

  final _contentController = TextEditingController();
  final _scoreController = TextEditingController(text: '1.0');
  final _codeController = TextEditingController();

  String _selectedDifficulty = 'MEDIUM';
  String _selectedType = 'SINGLE_CHOICE';
  String _selectedScope = 'PRIVATE';
  String? _selectedChapterId;

  List<dynamic> _chapters = [];
  bool _isLoadingChapters = true;
  bool _isSaving = false;

  bool get isHeadOfSubject {
    final role = SessionService().currentUser?.role;
    return role == 'HEAD_OF_SUBJECT' || role == 'ADMIN';
  }

  final List<_OptionInput> _options = [
    _OptionInput(controller: TextEditingController(), isCorrect: true),
    _OptionInput(controller: TextEditingController()),
    _OptionInput(controller: TextEditingController()),
    _OptionInput(controller: TextEditingController()),
  ];

  @override
  void initState() {
    super.initState();
    if (isHeadOfSubject) {
      _selectedScope = 'PUBLIC';
    }
    _fetchChapters();
  }

  @override
  void dispose() {
    _contentController.dispose();
    _scoreController.dispose();
    _codeController.dispose();
    for (var opt in _options) {
      opt.controller.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchChapters() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.chaptersBySubject(widget.subjectId));
      if (response['success'] == true && response['data'] is List) {
        final list = response['data'] as List;
        if (mounted) {
          setState(() {
            _chapters = list;
            if (_chapters.isNotEmpty) {
              _selectedChapterId = _chapters[0]['_id'];
            }
            _isLoadingChapters = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingChapters = false;
        });
      }
    }
  }

  void _addOption() {
    if (_options.length >= 8) return;
    setState(() {
      _options.add(_OptionInput(controller: TextEditingController()));
    });
  }

  void _removeOption(int index) {
    if (_options.length <= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Câu hỏi trắc nghiệm cần tối thiểu 2 đáp án')),
      );
      return;
    }
    setState(() {
      final removed = _options.removeAt(index);
      removed.controller.dispose();
    });
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedChapterId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn chương học cho câu hỏi'), backgroundColor: Colors.red),
      );
      return;
    }

    final isMcq = _selectedType != 'ESSAY';

    if (isMcq) {
      for (int i = 0; i < _options.length; i++) {
        if (_options[i].controller.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Vui lòng nhập nội dung cho đáp án ${String.fromCharCode(65 + i)}'), backgroundColor: Colors.red),
          );
          return;
        }
      }

      final hasCorrect = _options.any((opt) => opt.isCorrect);
      if (!hasCorrect) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng chọn ít nhất 1 đáp án đúng'), backgroundColor: Colors.red),
        );
        return;
      }
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final selectedChapter = _chapters.firstWhere(
        (c) => c['_id'] == _selectedChapterId,
        orElse: () => null,
      );
      final chapterNum = selectedChapter != null ? (selectedChapter['chapter_number'] ?? 1) : 1;
      final effectiveScope = isHeadOfSubject ? 'PUBLIC' : _selectedScope;

      final body = {
        'subject_id': widget.subjectId,
        'chapter_id': _selectedChapterId,
        'chapter_num': chapterNum,
        'question_code': _codeController.text.trim().isNotEmpty ? _codeController.text.trim() : null,
        'question_type': _selectedType,
        'difficulty': _selectedDifficulty,
        'difficulty_level': _selectedDifficulty,
        'scope': effectiveScope,
        'is_public': effectiveScope == 'PUBLIC',
        'content': _contentController.text.trim(),
        'default_score': double.tryParse(_scoreController.text.trim()) ?? 1.0,
        if (isMcq)
          'options': _options
              .map((opt) => {
                    'option_content': opt.controller.text.trim(),
                    'is_correct': opt.isCorrect,
                  })
              .toList(),
      };

      final response = await _apiClient.post(ApiEndpoints.questions, body: body);
      if (response['success'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tạo câu hỏi thành công'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      } else {
        throw Exception(response['message'] ?? 'Tạo câu hỏi thất bại');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: ${e.toString().replaceAll("Exception:", "").trim()}'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMcq = _selectedType != 'ESSAY';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Thêm câu hỏi - ${widget.subjectCode}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0.5,
      ),
      body: _isLoadingChapters
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Phân quyền phạm vi câu hỏi (Public / Private)
                    if (isHeadOfSubject)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.public, color: Color(0xFF1D4ED8), size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Câu hỏi chung của bộ môn (Public)',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E3A8A)),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Câu hỏi này sẽ được tự động chia sẻ vào ngân hàng đề chung của toàn bộ môn.',
                                    style: TextStyle(fontSize: 11, color: Color(0xFF3B82F6)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Phạm vi lưu trữ câu hỏi',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                            ),
                            const SizedBox(height: 8),
                            RadioListTile<String>(
                              value: 'PRIVATE',
                              groupValue: _selectedScope,
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Kho riêng của tôi (Private)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              subtitle: const Text('Chỉ bạn mới có thể sử dụng câu hỏi này trong đề thi của mình.', style: TextStyle(fontSize: 11)),
                              activeColor: const Color(0xFF1E3A5F),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedScope = val);
                              },
                            ),
                            RadioListTile<String>(
                              value: 'PUBLIC',
                              groupValue: _selectedScope,
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Đóng góp vào Ngân hàng chung (Public)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              subtitle: const Text('Chia sẻ câu hỏi để các giảng viên khác trong bộ môn cùng sử dụng.', style: TextStyle(fontSize: 11)),
                              activeColor: const Color(0xFF1E3A5F),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedScope = val);
                              },
                            ),
                          ],
                        ),
                      ),

                    // Chapter & Difficulty row
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<String>(
                            value: _selectedChapterId,
                            decoration: const InputDecoration(
                              labelText: 'Chương học',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            items: _chapters.map((ch) {
                              return DropdownMenuItem<String>(
                                value: ch['_id'],
                                child: Text('Chương ${ch['chapter_number']}: ${ch['chapter_title']}', overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedChapterId = val);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            value: _selectedDifficulty,
                            decoration: const InputDecoration(
                              labelText: 'Độ khó',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'EASY', child: Text('Dễ')),
                              DropdownMenuItem(value: 'MEDIUM', child: Text('Trung bình')),
                              DropdownMenuItem(value: 'HARD', child: Text('Khó')),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedDifficulty = val);
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Type & Score row
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<String>(
                            value: _selectedType,
                            decoration: const InputDecoration(
                              labelText: 'Loại câu hỏi',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'SINGLE_CHOICE', child: Text('Trắc nghiệm (1 đáp án)')),
                              DropdownMenuItem(value: 'MULTIPLE_CHOICE', child: Text('Trắc nghiệm (Nhiều đáp án)')),
                              DropdownMenuItem(value: 'ESSAY', child: Text('Tự luận')),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedType = val);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _scoreController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Điểm',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Bắt buộc';
                              if (double.tryParse(v) == null) return 'Số không hợp lệ';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Question Content
                    TextFormField(
                      controller: _contentController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Nội dung câu hỏi',
                        alignLabelWithHint: true,
                        hintText: 'Nhập nội dung câu hỏi thi...',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Vui lòng nhập nội dung câu hỏi';
                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    // Options section for Multiple Choice
                    if (isMcq) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Đáp án lựa chọn (Tích chọn đáp án đúng):',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
                          ),
                          TextButton.icon(
                            onPressed: _addOption,
                            icon: const Icon(Icons.add_circle_outline, size: 18),
                            label: const Text('Thêm đáp án'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...List.generate(_options.length, (index) {
                        final opt = _options[index];
                        final letter = String.fromCharCode(65 + index);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: opt.isCorrect ? const Color(0xFFECFDF5) : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: opt.isCorrect ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
                            ),
                          ),
                          child: Row(
                            children: [
                              // Radio or Checkbox for correct answer
                              if (_selectedType == 'SINGLE_CHOICE')
                                Radio<int>(
                                  value: index,
                                  groupValue: _options.indexWhere((o) => o.isCorrect),
                                  activeColor: const Color(0xFF10B981),
                                  onChanged: (val) {
                                    setState(() {
                                      for (int i = 0; i < _options.length; i++) {
                                        _options[i].isCorrect = (i == val);
                                      }
                                    });
                                  },
                                )
                              else
                                Checkbox(
                                  value: opt.isCorrect,
                                  activeColor: const Color(0xFF10B981),
                                  onChanged: (val) {
                                    setState(() {
                                      opt.isCorrect = val ?? false;
                                    });
                                  },
                                ),
                              Text(
                                '$letter.',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: opt.isCorrect ? const Color(0xFF10B981) : Colors.black87,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  controller: opt.controller,
                                  decoration: InputDecoration(
                                    hintText: 'Nội dung đáp án $letter',
                                    border: InputBorder.none,
                                    isDense: true,
                                  ),
                                ),
                              ),
                              if (_options.length > 2)
                                IconButton(
                                  icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                                  onPressed: () => _removeOption(index),
                                  tooltip: 'Xóa đáp án',
                                ),
                            ],
                          ),
                        );
                      }),
                    ],

                    const SizedBox(height: 24),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _handleSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E3A5F),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('Lưu câu hỏi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
