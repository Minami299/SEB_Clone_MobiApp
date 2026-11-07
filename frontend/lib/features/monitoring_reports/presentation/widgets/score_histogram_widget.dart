import 'package:flutter/material.dart';

class ScoreHistogramWidget extends StatelessWidget {
  final Map<String, dynamic> histogram;
  final int totalSubmitted;

  const ScoreHistogramWidget({
    super.key,
    required this.histogram,
    required this.totalSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          _buildBar('< 5.0 (Trượt)', histogram['under5'] ?? 0, Colors.red),
          const SizedBox(height: 10),
          _buildBar('5.0 - 6.5 (Trung bình)', histogram['from5To65'] ?? 0, Colors.amber.shade700),
          const SizedBox(height: 10),
          _buildBar('6.5 - 8.0 (Khá)', histogram['from65To8'] ?? 0, Colors.blue),
          const SizedBox(height: 10),
          _buildBar('8.0 - 10.0 (Giỏi)', histogram['from8To10'] ?? 0, Colors.green),
        ],
      ),
    );
  }

  Widget _buildBar(String label, int count, Color color) {
    final double pct = totalSubmitted > 0 ? (count / totalSubmitted) : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
            Text('$count thí sinh (${(pct * 100).toStringAsFixed(1)}%)', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 10,
            backgroundColor: const Color(0xFFF1F5F9),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
