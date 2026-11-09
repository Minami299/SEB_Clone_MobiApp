import 'package:flutter/material.dart';
import '../pages/question_detail_page.dart';

class QuestionItemCard extends StatelessWidget {
  final Map<String, dynamic> question;
  final Function(String id, String content) onDelete;
  final VoidCallback? onRefresh;

  const QuestionItemCard({
    super.key,
    required this.question,
    required this.onDelete,
    this.onRefresh,
  });

  Color _getDifficultyColor(String diff) {
    switch (diff) {
      case 'EASY':
        return Colors.green;
      case 'HARD':
        return Colors.red;
      case 'MEDIUM':
      default:
        return Colors.orange;
    }
  }

  String _getDifficultyText(String diff) {
    switch (diff) {
      case 'EASY':
        return 'Dễ';
      case 'HARD':
        return 'Khó';
      case 'MEDIUM':
      default:
        return 'Trung bình';
    }
  }

  String _getTypeText(String type) {
    switch (type) {
      case 'MULTIPLE_CHOICE':
        return 'Nhiều đáp án';
      case 'SINGLE_CHOICE':
      default:
        return '1 đáp án';
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = question['_id'] ?? '';
    final content = question['content'] ?? '';
    final diff = question['difficulty_level'] ?? question['difficulty'] ?? 'MEDIUM';
    final type = question['question_type'] ?? 'SINGLE_CHOICE';
    final score = question['default_score'] ?? 1.0;
    final code = question['question_code'] ?? '';
    final isPublicQ = (question['scope'] == 'PUBLIC' || question['is_public'] == true);

    String chapterLabel = '';
    if (question['chapter_id'] is Map) {
      chapterLabel = 'Chương ${question['chapter_id']['chapter_number']}: ${question['chapter_id']['chapter_title']}';
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () async {
          final res = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => QuestionDetailPage(
                questionId: id,
                questionCode: code.isNotEmpty ? code : null,
              ),
            ),
          );
          if (res == true && onRefresh != null) {
            onRefresh!();
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badges row
              Row(
                children: [
                  if (code.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        code,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF334155)),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  // Badge phạm vi Public/Private
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: isPublicQ ? const Color(0xFFEFF6FF) : const Color(0xFFFAF5FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isPublicQ ? const Color(0xFF93C5FD) : const Color(0xFFD8B4FE)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPublicQ ? Icons.public : Icons.lock_outline,
                          size: 11,
                          color: isPublicQ ? const Color(0xFF1D4ED8) : const Color(0xFF7E22CE),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          isPublicQ ? 'Kho chung' : 'Kho riêng',
                          style: TextStyle(
                            color: isPublicQ ? const Color(0xFF1D4ED8) : const Color(0xFF7E22CE),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getDifficultyColor(diff).withAlpha(25),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _getDifficultyColor(diff)),
                    ),
                    child: Text(
                      _getDifficultyText(diff),
                      style: TextStyle(color: _getDifficultyColor(diff), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A5F).withAlpha(15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _getTypeText(type),
                      style: const TextStyle(color: Color(0xFF1E3A5F), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$score điểm',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E3A5F)),
                  ),
                  if (!isPublicQ) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Xóa câu hỏi',
                      onPressed: () => onDelete(id, content),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 8),

              // Content
              Text(
                content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A), height: 1.4),
              ),

              if (chapterLabel.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  chapterLabel,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
