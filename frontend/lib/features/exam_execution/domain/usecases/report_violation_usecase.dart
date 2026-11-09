import '../repositories/exam_repository.dart';

class ReportViolationUseCase {
  final ExamRepository repository;

  const ReportViolationUseCase(this.repository);

  Future<Map<String, dynamic>> call({
    required String attemptId,
    required String examId,
    required String violationType,
    String? details,
  }) async {
    return await repository.reportViolation(
      attemptId: attemptId,
      examId: examId,
      violationType: violationType,
      details: details,
    );
  }
}
