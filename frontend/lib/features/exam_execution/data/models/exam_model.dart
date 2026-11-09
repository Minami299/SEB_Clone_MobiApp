import '../../domain/entities/exam_entity.dart';

class ExamModel extends ExamEntity {
  ExamModel({
    required super.id,
    required super.title,
    super.description,
    required super.durationMinutes,
    required super.maxViolations,
    super.accessPin,
    required super.status,
    super.startTime,
    super.endTime,
    required super.minPassPercentage,
    super.subjectCode = '',
    super.subjectName = '',
    super.allowReview,
  });

  factory ExamModel.fromJson(Map<String, dynamic> json) {
    String subCode = '';
    String subName = '';
    if (json['subject_id'] is Map<String, dynamic>) {
      subCode = json['subject_id']['subject_code'] ?? '';
      subName = json['subject_id']['subject_name'] ?? '';
    } else if (json['subject_code'] != null) {
      subCode = json['subject_code'].toString();
    }
    if (json['subject_name'] != null && subName.isEmpty) {
      subName = json['subject_name'].toString();
    }

    return ExamModel(
      id: json['_id'] ?? json['id'] ?? '',
      title: json['exam_title'] ?? '',
      description: json['description'],
      durationMinutes: json['duration_minutes'] ?? 60,
      maxViolations: json['max_violations'] ?? 3,
      accessPin: json['access_pin'] ?? json['exam_pin'],
      status: json['status'] ?? 'DRAFT',
      startTime: json['start_time'] != null ? DateTime.tryParse(json['start_time']) : null,
      endTime: json['end_time'] != null ? DateTime.tryParse(json['end_time']) : null,
      minPassPercentage: (json['min_pass_percentage'] as num?)?.toDouble() ?? 50.0,
      subjectCode: subCode,
      subjectName: subName,
      allowReview: json['allow_review'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'exam_title': title,
      'description': description,
      'duration_minutes': durationMinutes,
      'max_violations': maxViolations,
      'access_pin': accessPin,
      'status': status,
      'start_time': startTime?.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'min_pass_percentage': minPassPercentage,
      'subject_code': subjectCode,
      'subject_name': subjectName,
      'allow_review': allowReview,
    };
  }
}
