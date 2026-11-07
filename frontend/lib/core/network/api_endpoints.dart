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
  static String get authMe => '$baseUrl/auth/me';
  static String get authUsers => '$baseUrl/auth/users';
  static String authUserDetail(String id) => '$baseUrl/auth/users/$id';
  static String authUserRole(String id) => '$baseUrl/auth/users/$id/role';

  // Subject Access & Head of Subject
  static String get subjectAccessSubjects => '$baseUrl/subject-access/subjects';
  static String subjectStatus(String id) => '$baseUrl/subject-access/subjects/$id/status';
  static String get subjectAccessPending => '$baseUrl/subject-access/pending';
  static String subjectAccessReview(String id) => '$baseUrl/subject-access/$id/review';

  // Exams
  static String get exams => '$baseUrl/exams';
  static String examDetail(String id) => '$baseUrl/exams/$id';

  // Exam Execution
  static String get examStart => '$baseUrl/exam-execution/start';
  static String get examAnswer => '$baseUrl/exam-execution/answer';
  static String get examViolation => '$baseUrl/exam-execution/violation';
  static String examSubmit(String attemptId) => '$baseUrl/exam-execution/$attemptId/submit';
  static String examViolations(String examId) => '$baseUrl/exam-execution/violations/$examId';
}
