import 'package:flutter/material.dart';
import '../widgets/violation_history_list.dart';
import 'exam_list_page.dart';

class ExamSuspendedPage extends StatelessWidget {
  final String examTitle;
  final int violationCount;
  final int maxViolations;
  final String? endReason;
  final List<dynamic> violations;

  const ExamSuspendedPage({
    super.key,
    required this.examTitle,
    required this.violationCount,
    required this.maxViolations,
    this.endReason,
    this.violations = const [],
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFFFEF2F2),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Spacer(),

                // Warning Icon
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: Colors.red.withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    size: 54,
                    color: Colors.red,
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  'BÀI THI ĐÃ BỊ ĐÌNH CHỈ DO VI PHẠM NỘI QUY',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF991B1B),
                    height: 1.3,
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  'Ca thi: $examTitle',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Color(0xFF7F1D1D), fontWeight: FontWeight.w500),
                ),

                const SizedBox(height: 8),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Số lỗi vi phạm: $violationCount / $maxViolations',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),

                const SizedBox(height: 24),

                // Violation History Box (Extracted to Widget)
                ViolationHistoryList(violations: violations),

                const Spacer(),

                // The ONLY allowed button: Confirm and back to Home
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const ExamListPage()),
                        (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF991B1B),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text(
                      'Xác nhận và thoát về màn hình chính',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
