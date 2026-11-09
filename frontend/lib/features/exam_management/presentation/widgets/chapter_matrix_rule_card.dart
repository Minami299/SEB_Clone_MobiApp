import 'package:flutter/material.dart';

class ChapterMatrixRuleCard extends StatelessWidget {
  final int chapterNum;
  final String chapterTitle;
  final int maxEasy;
  final int maxMed;
  final int maxHard;
  final int curEasy;
  final int curMed;
  final int curHard;
  final ValueChanged<int> onEasyChanged;
  final ValueChanged<int> onMedChanged;
  final ValueChanged<int> onHardChanged;

  const ChapterMatrixRuleCard({
    super.key,
    required this.chapterNum,
    required this.chapterTitle,
    required this.maxEasy,
    required this.maxMed,
    required this.maxHard,
    required this.curEasy,
    required this.curMed,
    required this.curHard,
    required this.onEasyChanged,
    required this.onMedChanged,
    required this.onHardChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tiêu đề chương
          Text(
            'Chương $chapterNum: $chapterTitle',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 12),

          // 3 dòng độ khó theo chuẩn Mobile UX (Dễ, TB, Khó)
          _buildDifficultyRow(
            label: 'Dễ',
            max: maxEasy,
            current: curEasy,
            color: const Color(0xFF10B981),
            onChanged: onEasyChanged,
          ),
          const Divider(height: 16, color: Color(0xFFF1F5F9)),
          _buildDifficultyRow(
            label: 'Trung bình',
            max: maxMed,
            current: curMed,
            color: const Color(0xFFF59E0B),
            onChanged: onMedChanged,
          ),
          const Divider(height: 16, color: Color(0xFFF1F5F9)),
          _buildDifficultyRow(
            label: 'Khó',
            max: maxHard,
            current: curHard,
            color: const Color(0xFFEF4444),
            onChanged: onHardChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildDifficultyRow({
    required String label,
    required int max,
    required int current,
    required Color color,
    required ValueChanged<int> onChanged,
  }) {
    final bool isExceeded = current > max;

    return Row(
      children: [
        // Chấm màu nhận diện
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),

        // Tên mức độ & Tối đa
        Expanded(
          child: Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '(Tối đa: $max)',
                style: TextStyle(
                  fontSize: 12,
                  color: isExceeded ? Colors.red : const Color(0xFF64748B),
                  fontWeight: isExceeded ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),

        // Cụm nút [-]  Số  [+] to, rõ ràng, dễ bấm bằng ngón tay
        Container(
          decoration: BoxDecoration(
            color: isExceeded ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isExceeded ? Colors.red : const Color(0xFFE2E8F0)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Nút Trừ
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: const Icon(Icons.remove, size: 16, color: Color(0xFF475569)),
                onPressed: current > 0 ? () => onChanged(current - 1) : null,
              ),

              // Số lượng
              Container(
                constraints: const BoxConstraints(minWidth: 32),
                alignment: Alignment.center,
                child: Text(
                  '$current',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isExceeded ? Colors.red : const Color(0xFF0F172A),
                  ),
                ),
              ),

              // Nút Cộng
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: const Icon(Icons.add, size: 16, color: Color(0xFF475569)),
                onPressed: () => onChanged(current + 1),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
