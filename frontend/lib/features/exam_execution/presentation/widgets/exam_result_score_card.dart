import 'package:flutter/material.dart';

class ExamResultScoreCard extends StatelessWidget {
  final dynamic totalScore;
  final dynamic maxScore;
  final dynamic percentage;
  final bool isPassed;
  final bool isDisqualified;
  final int correctCount;
  final int wrongCount;
  final int unansweredCount;
  final int totalQuestions;
  final int durationSeconds;

  const ExamResultScoreCard({
    super.key,
    required this.totalScore,
    required this.maxScore,
    required this.percentage,
    required this.isPassed,
    required this.isDisqualified,
    required this.correctCount,
    required this.wrongCount,
    required this.unansweredCount,
    required this.totalQuestions,
    required this.durationSeconds,
  });

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m}p ${s}s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Text(
            '$totalScore',
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: isDisqualified
                  ? Colors.red
                  : isPassed
                      ? const Color(0xFF1E3A5F)
                      : Colors.orange,
            ),
          ),
          Text(
            'Thang điểm: $maxScore đ ($percentage%)',
            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const Divider(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatColumn('Số câu đúng', '$correctCount / $totalQuestions', Colors.green),
              _buildStatColumn('Số câu sai', '$wrongCount', Colors.red),
              _buildStatColumn('Chưa làm', '$unansweredCount', Colors.grey),
              _buildStatColumn('Thời gian', _formatDuration(durationSeconds), const Color(0xFF1E3A5F)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
      ],
    );
  }
}
