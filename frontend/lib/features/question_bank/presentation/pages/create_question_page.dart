import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/services/session_service.dart';

class CreateQuestionPage extends StatefulWidget {
  final String subjectId;
  final String subjectCode;
  final String subjectName;
  final String? questionId;

  const CreateQuestionPage({
    super.key,
    required this.subjectId,
    required this.subjectCode,
    required this.subjectName,
    this.questionId,
  });

  @override
  State<CreateQuestionPage> createState() => _CreateQuestionPageState();
}

class _OptionInput {
  final TextEditingController controller;
  bool isCorrect;

  _OptionInput({required this.controller, this.isCorrect = false});
}

class _CreateQuestionPageState extends State<CreateQuestionPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _apiClient = ApiClient();
  late TabController _tabController;

  final _contentController = TextEditingController();
  final _scoreController = TextEditingController(text: '1.0');
  final _codeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _loController = TextEditingController();

  String _selectedDifficulty = 'MEDIUM';
  String _selectedType = 'SINGLE_CHOICE';
  String _selectedScope = 'PRIVATE';
  String? _selectedChapterId;

  List<dynamic> _chapters = [];
  bool _isLoading = true;
  bool _isSaving = false;

  bool get isEditing => widget.questionId != null;

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
    _tabController = TabController(length: 2, vsync: this);
    if (isHeadOfSubject) {
      _selectedScope = 'PUBLIC';
    }
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _contentController.dispose();
    _scoreController.dispose();
    _codeController.dispose();
    _descriptionController.dispose();
    _loController.dispose();
    for (var opt in _options) {
      opt.controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final chRes = await _apiClient.get(
        ApiEndpoints.chaptersBySubject(widget.subjectId),
      );
      if (chRes['success'] == true && chRes['data'] is List) {
        _chapters = chRes['data'] as List;
        if (!isEditing && _chapters.isNotEmpty) {
          _selectedChapterId = _chapters[0]['_id'];
        }
      }

      if (isEditing) {
        final qRes = await _apiClient.get(
          ApiEndpoints.questionDetail(widget.questionId!),
        );
        if (qRes['success'] == true && qRes['data'] != null) {
          final q = qRes['data']['question'];
          final opts = qRes['data']['options'] as List? ?? [];

          _contentController.text = q['content'] ?? '';
          _scoreController.text = (q['default_score'] ?? 1.0).toString();
          _codeController.text = q['question_code'] ?? '';
          _descriptionController.text = q['description'] ?? '';
          _loController.text = q['learning_outcome'] ?? '';
          _selectedDifficulty =
              (q['difficulty'] ?? q['difficulty_level'] ?? 'MEDIUM')
                  .toString()
                  .toUpperCase();
          _selectedType = q['question_type'] ?? 'SINGLE_CHOICE';
          _selectedScope =
              (q['scope'] ?? (q['is_public'] == true ? 'PUBLIC' : 'PRIVATE'))
                  .toString()
                  .toUpperCase();

          if (q['chapter_id'] is Map) {
            _selectedChapterId = q['chapter_id']['_id'];
          } else {
            _selectedChapterId = q['chapter_id'];
          }

          if (opts.isNotEmpty) {
            for (var o in _options) {
              o.controller.dispose();
            }
            _options.clear();
            for (var opt in opts) {
              _options.add(
                _OptionInput(
                  controller: TextEditingController(
                    text: opt['option_content'] ?? '',
                  ),
                  isCorrect: opt['is_correct'] == true,
                ),
              );
            }
          }
        }
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tải dữ liệu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _addOption() {
    if (_options.length >= 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hỗ trợ tối đa 8 lựa chọn đáp án')),
      );
      return;
    }
    setState(() {
      _options.add(_OptionInput(controller: TextEditingController()));
    });
  }

  void _removeOption(int index) {
    if (_options.length <= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Câu hỏi trắc nghiệm cần tối thiểu 2 đáp án'),
        ),
      );
      return;
    }
    setState(() {
      final removed = _options.removeAt(index);
      removed.controller.dispose();
    });
  }

  void _insertEquationInto(TextEditingController controller) {
    final equations = [
      {'label': 'Phân số', 'tex': r'\frac{a}{b}'},
      {'label': 'Lũy thừa', 'tex': r'x^{2}'},
      {'label': 'Căn bậc 2', 'tex': r'\sqrt{x}'},
      {'label': 'Cộng trừ (±)', 'tex': r'\pm '},
      {'label': 'Khác (≠)', 'tex': r'\ne '},
      {'label': 'Nhỏ hơn hoặc bằng (≤)', 'tex': r'\le '},
      {'label': 'Lớn hơn hoặc bằng (≥)', 'tex': r'\ge '},
      {'label': 'Alpha (α)', 'tex': r'\alpha '},
      {'label': 'Beta (β)', 'tex': r'\beta '},
      {'label': 'Pi (π)', 'tex': r'\pi '},
      {'label': 'Tổng (∑)', 'tex': r'\sum_{i=1}^{n}'},
      {'label': 'Tích phân (∫)', 'tex': r'\int_{a}^{b}'},
      {'label': 'Vô cực (∞)', 'tex': r'\infty '},
      {'label': 'Nhân (×)', 'tex': r'\times '},
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(16),
          constraints: const BoxConstraints(maxHeight: 380),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Chèn công thức Toán học (LaTeX)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Text(
                'Chọn ký hiệu / công thức để chèn vào vị trí con trỏ:',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 3.2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: equations.length,
                  itemBuilder: (context, i) {
                    final item = equations[i];
                    return OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                      ),
                      onPressed: () {
                        final text = controller.text;
                        final selection = controller.selection;
                        final snippet = item['tex']!;
                        if (selection.start >= 0 && selection.end >= 0) {
                          final newText = text.replaceRange(
                            selection.start,
                            selection.end,
                            snippet,
                          );
                          controller.text = newText;
                          controller.selection = TextSelection.collapsed(
                            offset: selection.start + snippet.length,
                          );
                        } else {
                          controller.text = '$text $snippet';
                          controller.selection = TextSelection.collapsed(
                            offset: controller.text.length,
                          );
                        }
                        Navigator.pop(ctx);
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              item['label']!,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E293B),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            item['tex']!,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF2563EB),
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      _tabController.animateTo(0);
      return;
    }

    if (_selectedChapterId == null) {
      _tabController.animateTo(0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn chương học cho câu hỏi'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final isMcq = _selectedType != 'ESSAY';

    if (isMcq) {
      if (_options.length < 2) {
        _tabController.animateTo(1);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Câu hỏi trắc nghiệm phải tạo từ 2 đáp án trở lên'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Check empty
      for (int i = 0; i < _options.length; i++) {
        if (_options[i].controller.text.trim().isEmpty) {
          _tabController.animateTo(1);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Vui lòng nhập nội dung cho đáp án ${String.fromCharCode(65 + i)}',
              ),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      // Check duplicate options constraint
      final seenContents = <String>{};
      for (int i = 0; i < _options.length; i++) {
        final content = _options[i].controller.text.trim().toLowerCase();
        if (seenContents.contains(content)) {
          _tabController.animateTo(1);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Các câu trả lời trong cùng 1 câu hỏi phải khác nhau (Đáp án ${String.fromCharCode(65 + i)} bị trùng lặp)',
              ),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        seenContents.add(content);
      }

      final hasCorrect = _options.any((opt) => opt.isCorrect);
      if (!hasCorrect) {
        _tabController.animateTo(1);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng chọn ít nhất 1 đáp án đúng'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final selectedChapter = _chapters.firstWhere(
        (c) => c['_id'] == _selectedChapterId,
        orElse: () => null,
      );
      final chapterNum = selectedChapter != null
          ? (selectedChapter['chapter_number'] ?? 1)
          : 1;
      final effectiveScope = isHeadOfSubject ? 'PUBLIC' : _selectedScope;

      final body = {
        'subject_id': widget.subjectId,
        'chapter_id': _selectedChapterId,
        'chapter_num': chapterNum,
        'question_code': _codeController.text.trim().isNotEmpty
            ? _codeController.text.trim()
            : null,
        'question_type': _selectedType,
        'difficulty': _selectedDifficulty,
        'difficulty_level': _selectedDifficulty,
        'scope': effectiveScope,
        'is_public': effectiveScope == 'PUBLIC',
        'content': _contentController.text.trim(),
        'description': _descriptionController.text.trim(),
        'learning_outcome': _loController.text.trim().isNotEmpty
            ? _loController.text.trim()
            : null,
        'default_score': double.tryParse(_scoreController.text.trim()) ?? 1.0,
        if (isMcq)
          'options': _options
              .map(
                (opt) => {
                  'option_content': opt.controller.text.trim(),
                  'is_correct': opt.isCorrect,
                },
              )
              .toList(),
      };

      Map<String, dynamic> response;
      if (isEditing) {
        response = await _apiClient.put(
          '${ApiEndpoints.questions}/${widget.questionId}',
          body: body,
        );
      } else {
        response = await _apiClient.post(ApiEndpoints.questions, body: body);
      }

      if (response['success'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEditing
                  ? 'Cập nhật câu hỏi thành công'
                  : 'Tạo câu hỏi thành công',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        throw Exception(response['message'] ?? 'Thao tác thất bại');
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
          isEditing
              ? 'Sửa câu hỏi - ${widget.subjectCode}'
              : 'Thêm câu hỏi - ${widget.subjectCode}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0.5,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF1E3A5F),
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: const Color(0xFF1E3A5F),
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.help_outline, size: 20), text: '1. Câu hỏi'),
            Tab(
              icon: Icon(Icons.format_list_bulleted, size: 20),
              text: '2. Câu trả lời',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: TabBarView(
                controller: _tabController,
                children: [_buildTabQuestionInfo(), _buildTabAnswers()],
              ),
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _handleSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A5F),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      isEditing ? 'Lưu thay đổi' : 'Hoàn tất & Lưu câu hỏi',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabQuestionInfo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Phạm vi lưu trữ
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
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Câu hỏi này thuộc ngân hàng đề chung của bộ môn.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF3B82F6),
                          ),
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
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  RadioListTile<String>(
                    value: 'PRIVATE',
                    groupValue: _selectedScope,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Kho riêng của tôi (Private)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: const Text(
                      'Chỉ bạn mới có thể sử dụng câu hỏi này trong đề thi.',
                      style: TextStyle(fontSize: 11),
                    ),
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
                    title: const Text(
                      'Đóng góp vào Ngân hàng chung (Public)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: const Text(
                      'Chia sẻ câu hỏi để các giảng viên khác trong bộ môn cùng sử dụng.',
                      style: TextStyle(fontSize: 11),
                    ),
                    activeColor: const Color(0xFF1E3A5F),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedScope = val);
                    },
                  ),
                ],
              ),
            ),

          // Chương & Mức độ khó
          Row(
            children: [
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedChapterId,
                  decoration: const InputDecoration(
                    labelText: 'Chương *',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  items: _chapters.map((ch) {
                    return DropdownMenuItem<String>(
                      value: ch['_id'],
                      child: Text(
                        'Chương ${ch['chapter_number']}: ${ch['chapter_title']}',
                        overflow: TextOverflow.ellipsis,
                      ),
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
                  initialValue: _selectedDifficulty,
                  decoration: const InputDecoration(
                    labelText: 'Độ khó *',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'EASY', child: Text('Dễ')),
                    DropdownMenuItem(
                      value: 'MEDIUM',
                      child: Text('Trung bình'),
                    ),
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

          // Loại câu hỏi & Điểm
          Row(
            children: [
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Loại câu hỏi *',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'SINGLE_CHOICE',
                      child: Text('Trắc nghiệm (1 đáp án)'),
                    ),
                    DropdownMenuItem(
                      value: 'MULTIPLE_CHOICE',
                      child: Text('Trắc nghiệm (Nhiều đáp án)'),
                    ),
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
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Điểm số *',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Bắt buộc';
                    final num = double.tryParse(v);
                    if (num == null || num <= 0) return 'Phải > 0';
                    return null;
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Nội dung câu hỏi + Nút công thức Latex
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Nội dung câu hỏi đề bài *',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF1E293B),
                ),
              ),
              TextButton.icon(
                onPressed: () => _insertEquationInto(_contentController),
                icon: const Text(
                  r'$f_x$',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF2563EB),
                  ),
                ),
                label: const Text(
                  'Chèn công thức',
                  style: TextStyle(fontSize: 12, color: Color(0xFF2563EB)),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _contentController,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText:
                  'Nhập nội dung đề bài câu hỏi (hỗ trợ định dạng LaTeX)...',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty)
                return 'Vui lòng nhập nội dung đề bài';
              return null;
            },
          ),

          const SizedBox(height: 16),

          // Mô tả câu hỏi & Chuẩn đầu ra (LO)
          TextFormField(
            controller: _loController,
            decoration: const InputDecoration(
              labelText: 'Chuẩn đầu ra (LO - Tùy chọn)',
              hintText: 'VD: LO1, LO2...',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descriptionController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Mô tả / Ghi chú (Tùy chọn)',
              hintText: 'Ghi chú thêm về câu hỏi...',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Nút chuyển tab
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _tabController.animateTo(1),
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Thiết lập danh sách đáp án ->'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                foregroundColor: const Color(0xFF1E3A5F),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabAnswers() {
    if (_selectedType == 'ESSAY') {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.edit_note, size: 64, color: Colors.blue.shade300),
              const SizedBox(height: 16),
              const Text(
                'Câu hỏi Tự luận',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Đối với hình thức tự luận, sinh viên sẽ nhập bài làm trực tiếp. Không cần thiết lập danh sách phương án trắc nghiệm.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Danh sách đáp án (${_options.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Color(0xFF1E293B),
                ),
              ),
              TextButton.icon(
                onPressed: _addOption,
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: const Text('Thêm câu trả lời'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Quy tắc: Tối thiểu 2 đáp án, ít nhất 1 đáp án đúng, các đáp án không được trùng lặp.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),
          ...List.generate(_options.length, (index) {
            final opt = _options[index];
            final letter = String.fromCharCode(65 + index);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: opt.isCorrect ? const Color(0xFFECFDF5) : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: opt.isCorrect
                      ? const Color(0xFF10B981)
                      : const Color(0xFFCBD5E1),
                  width: opt.isCorrect ? 1.5 : 1,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Radio hoặc Checkbox
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
                        'Đáp án $letter ${opt.isCorrect ? "(ĐÚNG)" : ""}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: opt.isCorrect
                              ? const Color(0xFF047857)
                              : const Color(0xFF334155),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Chèn công thức LaTeX',
                        icon: const Text(
                          r'$f_x$',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                        onPressed: () => _insertEquationInto(opt.controller),
                      ),
                      if (_options.length > 2)
                        IconButton(
                          tooltip: 'Xóa câu trả lời này',
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 20,
                            color: Colors.redAccent,
                          ),
                          onPressed: () => _removeOption(index),
                        ),
                    ],
                  ),
                  TextFormField(
                    controller: opt.controller,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Nhập nội dung phương án $letter...',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      fillColor: Colors.white,
                      filled: true,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
