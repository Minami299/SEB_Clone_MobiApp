class ExamEntity {
  final String id;
  final String title;
  final String? description;
  final int durationMinutes;
  final int maxViolations;
  final String status;
  final DateTime? startTime;
  final DateTime? endTime;
  final double minPassPercentage;
  final String subjectCode;
  final String subjectName;
  final bool? allowReview;

  const ExamEntity({
    required this.id,
    required this.title,
    this.description,
    required this.durationMinutes,
    required this.maxViolations,
    required this.status,
    this.startTime,
    this.endTime,
    required this.minPassPercentage,
    this.subjectCode = '',
    this.subjectName = '',
    this.allowReview,
  });
}
