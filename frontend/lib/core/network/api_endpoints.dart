import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

class ApiEndpoints {
  // Đối với máy ảo Android: dùng 10.0.2.2
  // Đối với thiết bị thật (cắm cáp USB): dùng 127.0.0.1 (kết hợp lệnh adb reverse tcp:5000 tcp:5000) hoặc IP Wi-Fi máy tính
  static String host = '127.0.0.1';

  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5000/api';
    }
    if (Platform.isAndroid) {
      return 'http://$host:5000/api';
    }
    return 'http://localhost:5000/api';
  }

  static String get health => '$baseUrl/health';

  // Auth
  static String get authLogin => '$baseUrl/auth/login';
  static String get authForgotSendOtp => '$baseUrl/auth/forgot-password/send-otp';
  static String get authForgotVerifyOtp => '$baseUrl/auth/forgot-password/verify-otp';
  static String get authForgotPassword => '$baseUrl/auth/forgot-password';
  static String get authProfileSendOtp => '$baseUrl/auth/profile/send-otp';
  static String get authMe => '$baseUrl/auth/me';
  static String get authUsers => '$baseUrl/auth/users';
  static String authUserDetail(String id) => '$baseUrl/auth/users/$id';
  static String authUserRole(String id) => '$baseUrl/auth/users/$id/role';

  // Subject Access & Head of Subject
  static String get subjectAccessSubjects => '$baseUrl/subject-access/subjects';
  static String subjectStatus(String id) => '$baseUrl/subject-access/subjects/$id/status';
  static String get subjectAccessPending => '$baseUrl/subject-access/pending';
  static String subjectAccessReview(String id) => '$baseUrl/subject-access/$id/review';

  // Question Bank
  static String get questions => '$baseUrl/questions';
  static String questionsBySubject(String subjectId) => '$baseUrl/questions/subject/$subjectId';
  static String questionDetail(String id) => '$baseUrl/questions/$id';
  static String chaptersBySubject(String subjectId) => '$baseUrl/questions/chapters/subject/$subjectId';

  // Exams
  static String get exams => '$baseUrl/exams';
  static String examDetail(String id) => '$baseUrl/exams/$id';
  static String examStatistics(String id) => '$baseUrl/exams/$id/statistics';
  static String examExport(String id) => '$baseUrl/exams/$id/export';
  static String examQuestions(String id) => '$baseUrl/exams/$id/questions';
  static String examStudents(String id) => '$baseUrl/exams/$id/students';
  static String examPublish(String id) => '$baseUrl/exams/$id/publish';
  static String examClassesBySubject(String subjectId) => '$baseUrl/exams/classes/by-subject/$subjectId';
  static String examClassStudents(String classId) => '$baseUrl/exams/classes/$classId/students';

  // Exam Execution
  static String get examMySubmissions => '$baseUrl/exam-execution/my-submissions';
  static String get examStart => '$baseUrl/exam-execution/start';
  static String get examAnswer => '$baseUrl/exam-execution/answer';
  static String get examViolation => '$baseUrl/exam-execution/violation';
  static String examSubmit(String attemptId) => '$baseUrl/exam-execution/$attemptId/submit';
  static String examResult(String attemptId) => '$baseUrl/exam-execution/$attemptId/result';
  static String examForceSuspend(String attemptId) => '$baseUrl/exam-execution/$attemptId/force-suspend';
  static String examViolations(String examId) => '$baseUrl/exam-execution/violations/$examId';
}
