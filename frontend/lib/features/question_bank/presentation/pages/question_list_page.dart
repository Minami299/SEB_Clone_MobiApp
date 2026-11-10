import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import 'batch_import_questions_page.dart';
import 'create_question_page.dart';
import '../widgets/question_item_card.dart';
import '../widgets/question_matrix_summary_card.dart';

class QuestionListPage extends StatefulWidget {
  final String subjectId;
  final String subjectCode;
  final String subjectName;
  final bool showPrivateTab;

  const QuestionListPage({
    super.key,
    required this.subjectId,
    required this.subjectCode,
    required this.subjectName,
    this.showPrivateTab = true,
  });

  @override
  State<QuestionListPage> createState() => _QuestionListPageState();
}

class _QuestionListPageState extends State<QuestionListPage> {
  final _apiClient = ApiClient();

  List<dynamic> _questions = [];
  List<dynamic> _chapters = [];
  bool _isLoading = true;
  String? _errorMessage;

  String _selectedDifficulty = 'ALL';
  String _selectedChapter = 'ALL';
  int _selectedScopeTab = 0; // 0: PUBLIC, 1: PRIVATE
  bool _showMatrixSummary = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final futures = await Future.wait([
        _apiClient.get(ApiEndpoints.questionsBySubject(widget.subjectId)),
        _apiClient.get(ApiEndpoints.chaptersBySubject(widget.subjectId)),
      ]);

      final qRes = futures[0];
      final chRes = futures[1];

      if (mounted) {
        setState(() {
          if (qRes['success'] == true && qRes['data'] is List) {
            _questions = qRes['data'] as List;
          }
          if (chRes['success'] == true && chRes['data'] is List) {
            _chapters = chRes['data'] as List;
          }
          _isLoading = false;
        });
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

  Future<void> _handleDelete(String questionId, String content) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa câu hỏi'),
        content: Text('Bạn có chắc chắn muốn xóa câu hỏi này?\n"$content"'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final res = await _apiClient.delete(
        ApiEndpoints.questionDetail(questionId),
      );
      if (res['success'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xóa câu hỏi thành công'),
            backgroundColor: Colors.green,
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
      );
    }
  }

  int get _publicQuestionsCount => _questions
      .where((q) => (q['scope'] == 'PUBLIC' || q['is_public'] == true))
      .length;

  int get _privateQuestionsCount => _questions
      .where((q) => !(q['scope'] == 'PUBLIC' || q['is_public'] == true))
      .length;

  int get _currentTabTotalQuestions =>
      _selectedScopeTab == 0 ? _publicQuestionsCount : _privateQuestionsCount;

  bool get _isFilterActive =>
      _searchController.text.trim().isNotEmpty ||
      _selectedDifficulty != 'ALL' ||
      _selectedChapter != 'ALL';

  List<dynamic> get _filteredQuestions {
    final query = _searchController.text.trim().toLowerCase();
    return _questions.where((q) {
      // Phân loại theo Scope Tab: 0 là Public, 1 là Private
      final isPublic = (q['scope'] == 'PUBLIC' || q['is_public'] == true);
      if (_selectedScopeTab == 0 && !isPublic) return false;
      if (_selectedScopeTab == 1 && isPublic) return false;

      final content = (q['content'] ?? '').toString().toLowerCase();
      final code = (q['question_code'] ?? '').toString().toLowerCase();
      if (query.isNotEmpty &&
          !content.contains(query) &&
          !code.contains(query)) {
        return false;
      }

      if (_selectedDifficulty != 'ALL') {
        final diff = (q['difficulty'] ?? q['difficulty_level'] ?? '')
            .toString()
            .toUpperCase();
        if (diff != _selectedDifficulty) {
          return false;
        }
      }

      if (_selectedChapter != 'ALL') {
        final chId = q['chapter_id'] is Map
            ? q['chapter_id']['_id']
            : q['chapter_id'];
        if (chId != _selectedChapter) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  /// Thống kê ma trận số lượng câu hỏi theo từng Chương và Độ khó
  Map<int, Map<String, int>> _computeMatrixStats() {
    final Map<int, Map<String, int>> stats = {};

    // Khởi tạo các chương đã biết
    for (var ch in _chapters) {
      final num = ch['chapter_number'] is int
          ? ch['chapter_number'] as int
          : int.tryParse(ch['chapter_number'].toString()) ?? 1;
      stats[num] = {'EASY': 0, 'MEDIUM': 0, 'HARD': 0, 'TOTAL': 0};
    }

    // Đếm câu hỏi tương ứng theo kho đang xem (hoặc toàn bộ)
    for (var q in _questions) {
      final isPublic = (q['scope'] == 'PUBLIC' || q['is_public'] == true);
      if (_selectedScopeTab == 0 && !isPublic) continue;
      if (_selectedScopeTab == 1 && isPublic) continue;

      int chapterNum = 1;
      if (q['chapter_num'] != null) {
        chapterNum = int.tryParse(q['chapter_num'].toString()) ?? 1;
      } else if (q['chapter_id'] is Map &&
          q['chapter_id']['chapter_number'] != null) {
        chapterNum =
            int.tryParse(q['chapter_id']['chapter_number'].toString()) ?? 1;
      }

      stats.putIfAbsent(
        chapterNum,
        () => {'EASY': 0, 'MEDIUM': 0, 'HARD': 0, 'TOTAL': 0},
      );

      final diff = (q['difficulty'] ?? q['difficulty_level'] ?? 'MEDIUM')
          .toString()
          .toUpperCase();
      if (stats[chapterNum]!.containsKey(diff)) {
        stats[chapterNum]![diff] = (stats[chapterNum]![diff] ?? 0) + 1;
      } else {
        stats[chapterNum]!['MEDIUM'] = (stats[chapterNum]!['MEDIUM'] ?? 0) + 1;
      }
      stats[chapterNum]!['TOTAL'] = (stats[chapterNum]!['TOTAL'] ?? 0) + 1;
    }

    return stats;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredQuestions;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          '${widget.subjectCode} - Ngân hàng câu hỏi',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0.5,
        actions: [
          IconButton(
            tooltip: 'Nhập hàng loạt',
            icon: const Icon(Icons.playlist_add),
            onPressed: () async {
              final imported = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => BatchImportQuestionsPage(
                    subjectId: widget.subjectId,
                    subjectCode: widget.subjectCode,
                    subjectName: widget.subjectName,
                  ),
                ),
              );
              if (imported == true) {
                _loadData();
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            builder: (ctx) => SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFEFF6FF),
                        child: Icon(Icons.edit_note, color: Color(0xFF2563EB)),
                      ),
                      title: const Text(
                        'Soạn câu hỏi thủ công',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text('Tạo từng câu với đầy đủ tùy chọn'),
                      onTap: () async {
                        Navigator.pop(ctx);
                        final created = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CreateQuestionPage(
                              subjectId: widget.subjectId,
                              subjectCode: widget.subjectCode,
                              subjectName: widget.subjectName,
                            ),
                          ),
                        );
                        if (created == true) {
                          _loadData();
                        }
                      },
                    ),
                    ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFECFDF5),
                        child: Icon(
                          Icons.playlist_add,
                          color: Color(0xFF10B981),
                        ),
                      ),
                      title: const Text(
                        'Nhập nhanh từ văn bản',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text(
                        'Dán danh sách nhiều câu hỏi (Aiken / Trắc nghiệm)',
                      ),
                      onTap: () async {
                        Navigator.pop(ctx);
                        final imported = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BatchImportQuestionsPage(
                              subjectId: widget.subjectId,
                              subjectCode: widget.subjectCode,
                              subjectName: widget.subjectName,
                            ),
                          ),
                        );
                        if (imported == true) {
                          _loadData();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        backgroundColor: const Color(0xFF1E3A5F),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Thêm câu hỏi'),
      ),
      body: Column(
        children: [
          // Tabs phân loại kho: Public vs Private
          Container(
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _selectedScopeTab = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _selectedScopeTab == 0
                                ? const Color(0xFF1E3A5F)
                                : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.public,
                            size: 16,
                            color: _selectedScopeTab == 0
                                ? const Color(0xFF1E3A5F)
                                : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Kho chung bộ môn ($_publicQuestionsCount)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: _selectedScopeTab == 0
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: _selectedScopeTab == 0
                                  ? const Color(0xFF1E3A5F)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                  ),
                  ),
                ),
                if (widget.showPrivateTab)
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _selectedScopeTab = 1),
                      child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _selectedScopeTab == 1
                                ? const Color(0xFF1E3A5F)
                                : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 16,
                            color: _selectedScopeTab == 1
                                ? const Color(0xFF1E3A5F)
                                : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Kho riêng của tôi ($_privateQuestionsCount)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: _selectedScopeTab == 1
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: _selectedScopeTab == 1
                                  ? const Color(0xFF1E3A5F)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Header info & filters
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        widget.subjectName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isFilterActive
                          ? '${filtered.length} / $_currentTabTotalQuestions câu'
                          : '$_currentTabTotalQuestions câu',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Search bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm nội dung câu hỏi...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                // Filter dropdowns
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedChapter,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Chương',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: 'ALL',
                            child: Text('Tất cả chương'),
                          ),
                          ..._chapters.map(
                            (ch) => DropdownMenuItem<String>(
                              value: ch['_id'],
                              child: Text(
                                'Chương ${ch['chapter_number']}: ${ch['chapter_title']}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedChapter = val);
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
                            horizontal: 8,
                            vertical: 6,
                          ),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'ALL', child: Text('Tất cả')),
                          DropdownMenuItem(value: 'EASY', child: Text('Dễ')),
                          DropdownMenuItem(
                            value: 'MEDIUM',
                            child: Text('Trung bình'),
                          ),
                          DropdownMenuItem(value: 'HARD', child: Text('Khó')),
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
              ],
            ),
          ),

          // Khối thống kê ma trận theo Chương & Độ khó (Extracted to Widget)
          if (_chapters.isNotEmpty)
            QuestionMatrixSummaryCard(
              selectedScopeTab: _selectedScopeTab,
              showMatrixSummary: _showMatrixSummary,
              matrixStats: _computeMatrixStats(),
              onToggle: () =>
                  setState(() => _showMatrixSummary = !_showMatrixSummary),
            ),

          const Divider(height: 1),

          // List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.shield_outlined,
                            size: 48,
                            color: Color(0xFFEF4444),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF1E293B),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F172A),
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Quay lại danh sách môn học'),
                          ),
                        ],
                      ),
                    ),
                  )
                : filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _selectedScopeTab == 1 &&
                                    _privateQuestionsCount == 0
                                ? Icons.lock_person_outlined
                                : Icons.search_off_outlined,
                            size: 48,
                            color: const Color(0xFF94A3B8),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _selectedScopeTab == 1 &&
                                    _privateQuestionsCount == 0
                                ? 'Kho riêng của bạn chưa có câu hỏi nào'
                                : 'Không tìm thấy câu hỏi nào phù hợp',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _selectedScopeTab == 1 &&
                                    _privateQuestionsCount == 0
                                ? 'Bạn có thể tự do tạo các câu hỏi trắc nghiệm riêng tại đây bằng nút "+ Thêm câu hỏi".'
                                : 'Hãy thử thay đổi từ khóa tìm kiếm hoặc bỏ bớt các bộ lọc.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                    itemCount: filtered.length,
                    separatorBuilder: (context, _) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      return QuestionItemCard(
                        question: filtered[index] as Map<String, dynamic>,
                        onDelete: _handleDelete,
                        onRefresh: _loadData,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
