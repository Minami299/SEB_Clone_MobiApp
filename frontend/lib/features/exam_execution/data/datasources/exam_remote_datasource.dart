import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../models/exam_model.dart';
import '../models/question_item_model.dart';

class ExamRemoteDataSource {
  final ApiClient apiClient;

  ExamRemoteDataSource({ApiClient? apiClient})
      : apiClient = apiClient ?? ApiClient();

  Future<List<ExamModel>> getExams() async {
    final response = await apiClient.get(ApiEndpoints.exams);
    final list = response['data'] as List? ?? [];
    return list.map((e) => ExamModel.fromJson(e)).toList();
  }

  Future<Map<String, dynamic>> startExam({
    required String examId,
    required String accessPin,
  }) =>
      startAttempt(examId: examId, accessPin: accessPin);

  Future<Map<String, dynamic>> startAttempt({
    required String examId,
    required String accessPin,
  }) async {
    final response = await apiClient.post(
      ApiEndpoints.examStart,
      body: {
        'exam_id': examId,
        'access_pin': accessPin,
      },
    );

    final data = response['data'] as Map<String, dynamic>;
    final rawQuestions = data['questions'] as List? ?? [];

    final questions = rawQuestions
        .map((item) => QuestionItemModel.fromJson(item as Map<String, dynamic>))
        .toList();

    return {
      'attempt_id': data['attempt_id'],
      'exam_title': data['exam_title'] ?? '',
      'duration_minutes': data['duration_minutes'] ?? 60,
      'max_violations': data['max_violations'] ?? 3,
      'questions': questions,
    };
  }

  Future<void> saveAnswer({
    required String attemptId,
    required String questionId,
    required String selectedOptionId,
  }) async {
    await apiClient.post(
      ApiEndpoints.examAnswer,
      body: {
        'attempt_id': attemptId,
        'question_id': questionId,
        'selected_option_id': selectedOptionId,
      },
    );
  }

  Future<Map<String, dynamic>> reportViolation({
    required String attemptId,
    required String examId,
    required String violationType,
    String? details,
  }) async {
    final response = await apiClient.post(
      ApiEndpoints.examViolation,
      body: {
        'attempt_id': attemptId,
        'exam_id': examId,
        'violation_type': violationType,
        'violation_details': details ?? '',
      },
    );
    return response['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> submitExam({required String attemptId}) async {
    final response = await apiClient.post(ApiEndpoints.examSubmit(attemptId));
    return response['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getExamViolations(String examId) async {
    final response = await apiClient.get(ApiEndpoints.examViolations(examId));
    return response['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> forceSuspendAttempt(String attemptId, {String? reason}) async {
    final response = await apiClient.post(
      ApiEndpoints.examForceSuspend(attemptId),
      body: {'reason': reason ?? 'PROCTOR_FORCE_SUSPEND'},
    );
    return response['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> unlockAttempt(String attemptId) async {
    final response = await apiClient.post(ApiEndpoints.examUnlockAttempt(attemptId));
    return response as Map<String, dynamic>;
  }
}
