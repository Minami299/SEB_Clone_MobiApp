import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

class ApiEndpoints {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5000/api';
    }
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:5000/api';
    }
    return 'http://localhost:5000/api';
  }

  static String get health => '$baseUrl/health';

  // Auth
  static String get authLogin => '$baseUrl/auth/login';
  static String get authMe => '$baseUrl/auth/me';

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
