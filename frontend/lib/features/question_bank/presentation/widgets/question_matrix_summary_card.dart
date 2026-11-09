import 'package:flutter/material.dart';

class QuestionMatrixSummaryCard extends StatelessWidget {
  final int selectedScopeTab;
  final bool showMatrixSummary;
  final Map<int, Map<String, int>> matrixStats;
  final VoidCallback onToggle;

  const QuestionMatrixSummaryCard({
    super.key,
    required this.selectedScopeTab,
    required this.showMatrixSummary,
    required this.matrixStats,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.grid_view, size: 15, color: Color(0xFF1E3A5F)),
                  const SizedBox(width: 6),
                  Text(
                    'Thống kê câu hỏi (${selectedScopeTab == 0 ? "Kho chung" : "Kho riêng"})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E293B)),
                  ),
                ],
              ),
              InkWell(
                onTap: onToggle,
                child: Text(
                  showMatrixSummary ? 'Thu gọn' : 'Chi tiết',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (showMatrixSummary) ...[
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: matrixStats.entries.map((entry) {
                  final chNum = entry.key;
                  final counts = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Chương $chNum (${counts['TOTAL']} câu)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF1E293B))),
                        const SizedBox(height: 2),
                        Text(
                          'Dễ: ${counts['EASY']}  •  Trung bình: ${counts['MEDIUM']}  •  Khó: ${counts['HARD']}',
                          style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
