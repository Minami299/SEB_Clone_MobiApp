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
  });

  factory ExamModel.fromJson(Map<String, dynamic> json) {
    return ExamModel(
      id: json['_id'] ?? json['id'] ?? '',
      title: json['exam_title'] ?? '',
      description: json['description'],
      durationMinutes: json['duration_minutes'] ?? 60,
      maxViolations: json['max_violations'] ?? 3,
      accessPin: json['access_pin'],
      status: json['status'] ?? 'DRAFT',
      startTime: json['start_time'] != null ? DateTime.tryParse(json['start_time']) : null,
      endTime: json['end_time'] != null ? DateTime.tryParse(json['end_time']) : null,
      minPassPercentage: (json['min_pass_percentage'] as num?)?.toDouble() ?? 50.0,
    );
  }
}

