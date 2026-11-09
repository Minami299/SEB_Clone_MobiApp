import '../entities/exam_attempt_entity.dart';
import '../entities/exam_entity.dart';

abstract class ExamRepository {
  Future<List<ExamEntity>> getExams();

  Future<ExamAttemptEntity> startExam({
    required String examId,
    String? accessPin,
  });

  Future<void> saveAnswer({
    required String attemptId,
    required String questionId,
    required String selectedOptionId,
  });

  Future<Map<String, dynamic>> reportViolation({
    required String attemptId,
    required String examId,
    required String violationType,
    String? details,
  });

  Future<Map<String, dynamic>> submitExam({required String attemptId});

  Future<Map<String, dynamic>> getExamViolations(String examId);

  Future<Map<String, dynamic>> forceSuspendAttempt(String attemptId, {String? reason});

  Future<Map<String, dynamic>> unlockAttempt(String attemptId);
}
