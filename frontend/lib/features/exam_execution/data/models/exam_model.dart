class ExamModel {
  final String id;
  final String title;
  final String? description;
  final int durationMinutes;
  final int maxViolations;
  final String? accessPin;
  final String status;
  final DateTime? startTime;
  final DateTime? endTime;
  final double minPassPercentage;
  final String subjectCode;
  final String subjectName;
  final bool? allowReview;

  ExamModel({
    required this.id,
    required this.title,
    this.description,
    required this.durationMinutes,
    required this.maxViolations,
    this.accessPin,
    required this.status,
    this.startTime,
    this.endTime,
    required this.minPassPercentage,
    this.subjectCode = '',
    this.subjectName = '',
    this.allowReview,
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
}


