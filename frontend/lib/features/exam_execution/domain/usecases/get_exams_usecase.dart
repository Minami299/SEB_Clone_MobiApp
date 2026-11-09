import '../entities/exam_entity.dart';
import '../repositories/exam_repository.dart';

class GetExamsUseCase {
  final ExamRepository repository;

  const GetExamsUseCase(this.repository);

  Future<List<ExamEntity>> call() async {
    return await repository.getExams();
  }
}
