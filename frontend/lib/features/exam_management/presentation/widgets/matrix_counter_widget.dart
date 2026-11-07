import 'package:flutter/material.dart';

class MatrixCounterWidget extends StatelessWidget {
  final String label;
  final int value;
  final int max;
  final Color color;
  final ValueChanged<int> onChanged;

  const MatrixCounterWidget({
    super.key,
    required this.label,
    required this.value,
    required this.max,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isExceeded = value > max;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: isExceeded ? Colors.red.withAlpha(20) : color.withAlpha(15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isExceeded ? Colors.red : color.withAlpha(80)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isExceeded ? Colors.red : color),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: value > 0 ? () => onChanged(value - 1) : null,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: const Icon(Icons.remove, size: 14),
                ),
              ),
              Text(
                '$value',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isExceeded ? Colors.red : const Color(0xFF1E293B),
                ),
              ),
              InkWell(
                onTap: () => onChanged(value + 1),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: const Icon(Icons.add, size: 14),
                ),
              ),
            ],
          ),
          if (isExceeded)
            const Text(
              'Thiếu câu',
              style: TextStyle(fontSize: 9, color: Colors.red, fontWeight: FontWeight.bold),
            )
          else
            Text(
              'Tối đa: $max',
              style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
            ),
        ],
      ),
    );
  }
}
