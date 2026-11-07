import 'package:flutter/material.dart';
import 'matrix_counter_widget.dart';

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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chương $chapterNum: $chapterTitle',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 4),
          Text(
            'Khả dụng trong kho: Dễ ($maxEasy), TB ($maxMed), Khó ($maxHard)',
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: MatrixCounterWidget(
                  label: 'Dễ',
                  value: curEasy,
                  max: maxEasy,
                  color: Colors.green,
                  onChanged: onEasyChanged,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: MatrixCounterWidget(
                  label: 'TB',
                  value: curMed,
                  max: maxMed,
                  color: Colors.orange,
                  onChanged: onMedChanged,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: MatrixCounterWidget(
                  label: 'Khó',
                  value: curHard,
                  max: maxHard,
                  color: Colors.red,
                  onChanged: onHardChanged,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
