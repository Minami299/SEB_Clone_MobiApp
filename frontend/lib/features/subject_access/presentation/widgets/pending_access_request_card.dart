import 'package:flutter/material.dart';

class PendingAccessRequestCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final Function(String id, String action) onReview;

  const PendingAccessRequestCard({
    super.key,
    required this.request,
    required this.onReview,
  });

  @override
  Widget build(BuildContext context) {
    final id = request['_id'] ?? '';
    final lecName = request['lecturer_id']?['full_name'] ?? 'Giảng viên';
    final lecEmail = request['lecturer_id']?['email'] ?? '';
    final subjCode = request['subject_id']?['subject_code'] ?? '';
    final subjName = request['subject_id']?['subject_name'] ?? '';
    final grantType = request['grant_type'] ?? 'QUESTION_CONTRIBUTION';

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lecName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            Text(
              '$lecEmail | Môn: $subjCode ($subjName)',
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Loại quyền: $grantType',
              style: const TextStyle(
                color: Colors.blueGrey,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => onReview(id, 'REJECTED'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                  child: const Text('Từ chối'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => onReview(id, 'APPROVED'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Phê duyệt'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
