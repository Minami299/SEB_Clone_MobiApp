import '../entities/exam_attempt_entity.dart';
import '../repositories/exam_repository.dart';

class StartExamUseCase {
  final ExamRepository repository;

  const StartExamUseCase(this.repository);

  Future<ExamAttemptEntity> call({
    required String examId,
  }) async {
    return await repository.startExam(
      examId: examId,
    );
  }
}
