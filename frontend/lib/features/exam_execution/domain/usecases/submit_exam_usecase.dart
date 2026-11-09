import '../repositories/exam_repository.dart';

class SubmitExamUseCase {
  final ExamRepository repository;

  const SubmitExamUseCase(this.repository);

  Future<Map<String, dynamic>> call({required String attemptId}) async {
    return await repository.submitExam(attemptId: attemptId);
  }
}
