import '../repositories/exam_repository.dart';

class SaveAnswerUseCase {
  final ExamRepository repository;

  const SaveAnswerUseCase(this.repository);

  Future<void> call({
    required String attemptId,
    required String questionId,
    required String selectedOptionId,
  }) async {
    return await repository.saveAnswer(
      attemptId: attemptId,
      questionId: questionId,
      selectedOptionId: selectedOptionId,
    );
  }
}
