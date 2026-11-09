import 'question_entity.dart';

class ExamAttemptEntity {
  final String attemptId;
  final String examTitle;
  final int durationMinutes;
  final int maxViolations;
  final List<QuestionEntity> questions;

  const ExamAttemptEntity({
    required this.attemptId,
    required this.examTitle,
    required this.durationMinutes,
    required this.maxViolations,
    required this.questions,
  });
}
