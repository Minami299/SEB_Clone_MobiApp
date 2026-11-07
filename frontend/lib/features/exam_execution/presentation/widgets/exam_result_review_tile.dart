import 'package:flutter/material.dart';

class ExamResultReviewTile extends StatelessWidget {
  final int index;
  final Map<String, dynamic> reviewQuestion;

  const ExamResultReviewTile({
    super.key,
    required this.index,
    required this.reviewQuestion,
  });

  @override
  Widget build(BuildContext context) {
    final isQCorrect = reviewQuestion['is_correct'] == true;
    final opts = reviewQuestion['options'] as List? ?? [];
    final selectedOptId = reviewQuestion['selected_option_id']?.toString();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isQCorrect ? const Color(0xFF10B981) : Colors.red.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Câu ${index + 1}:',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF64748B)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isQCorrect ? Colors.green.withAlpha(25) : Colors.red.withAlpha(25),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isQCorrect ? 'ĐÚNG (+${reviewQuestion['score_awarded']}đ)' : 'SAI (0đ)',
                  style: TextStyle(
                    color: isQCorrect ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            reviewQuestion['content'] ?? '',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 10),
          ...List.generate(opts.length, (optIdx) {
            final opt = opts[optIdx];
            final isThisCorrect = opt['is_correct'] == true;
            final isThisSelected = selectedOptId == opt['id']?.toString();

            Color optColor = Colors.transparent;
            Border? optBorder;
            if (isThisCorrect) {
              optColor = const Color(0xFFECFDF5);
              optBorder = Border.all(color: const Color(0xFF10B981));
            } else if (isThisSelected && !isThisCorrect) {
              optColor = const Color(0xFFFEF2F2);
              optBorder = Border.all(color: Colors.red);
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: optColor,
                borderRadius: BorderRadius.circular(6),
                border: optBorder ?? Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Text(
                    '${String.fromCharCode(65 + optIdx)}.',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isThisCorrect
                          ? Colors.green.shade800
                          : isThisSelected
                              ? Colors.red
                              : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      opt['content'] ?? '',
                      style: TextStyle(
                        fontSize: 13,
                        color: isThisCorrect
                            ? Colors.green.shade900
                            : isThisSelected
                                ? Colors.red.shade900
                                : const Color(0xFF1E293B),
                        fontWeight: (isThisCorrect || isThisSelected) ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                  if (isThisCorrect)
                    const Icon(Icons.check_circle, size: 16, color: Color(0xFF10B981))
                  else if (isThisSelected)
                    const Icon(Icons.cancel, size: 16, color: Colors.red),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
