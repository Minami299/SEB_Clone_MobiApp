import '../../domain/entities/exam_attempt_entity.dart';
import '../../domain/entities/exam_entity.dart';
import '../../domain/entities/question_entity.dart';
import '../../domain/repositories/exam_repository.dart';
import '../datasources/exam_remote_datasource.dart';
import '../models/question_item_model.dart';

class ExamRepositoryImpl implements ExamRepository {
  final ExamRemoteDataSource remoteDataSource;

  ExamRepositoryImpl({ExamRemoteDataSource? remoteDataSource})
      : remoteDataSource = remoteDataSource ?? ExamRemoteDataSource();

  @override
  Future<List<ExamEntity>> getExams() async {
    final models = await remoteDataSource.getExams();
    return models;
  }

  @override
  Future<ExamAttemptEntity> startExam({
    required String examId,
  }) async {
    final result = await remoteDataSource.startAttempt(
      examId: examId,
    );

    final rawQuestions = result['questions'];
    final List<QuestionEntity> questions;
    if (rawQuestions is List<QuestionEntity>) {
      questions = rawQuestions;
    } else if (rawQuestions is List) {
      questions = rawQuestions.map((item) {
        if (item is QuestionEntity) return item;
        return QuestionItemModel.fromJson(item as Map<String, dynamic>);
      }).toList();
    } else {
      questions = [];
    }

    return ExamAttemptEntity(
      attemptId: result['attempt_id']?.toString() ?? '',
      examTitle: result['exam_title']?.toString() ?? '',
      durationMinutes: (result['duration_minutes'] as num?)?.toInt() ?? 60,
      maxViolations: (result['max_violations'] as num?)?.toInt() ?? 3,
      questions: questions,
    );
  }

  @override
  Future<void> saveAnswer({
    required String attemptId,
    required String questionId,
    required String selectedOptionId,
  }) async {
    await remoteDataSource.saveAnswer(
      attemptId: attemptId,
      questionId: questionId,
      selectedOptionId: selectedOptionId,
    );
  }

  @override
  Future<Map<String, dynamic>> reportViolation({
    required String attemptId,
    required String examId,
    required String violationType,
    String? details,
  }) async {
    return await remoteDataSource.reportViolation(
      attemptId: attemptId,
      examId: examId,
      violationType: violationType,
      details: details,
    );
  }

  @override
  Future<Map<String, dynamic>> submitExam({required String attemptId}) async {
    return await remoteDataSource.submitExam(attemptId: attemptId);
  }

  @override
  Future<Map<String, dynamic>> getExamViolations(String examId) async {
    return await remoteDataSource.getExamViolations(examId);
  }

  @override
  Future<Map<String, dynamic>> forceSuspendAttempt(
    String attemptId, {
    String? reason,
  }) async {
    return await remoteDataSource.forceSuspendAttempt(attemptId, reason: reason);
  }

  @override
  Future<Map<String, dynamic>> unlockAttempt(String attemptId) async {
    return await remoteDataSource.unlockAttempt(attemptId);
  }
}
