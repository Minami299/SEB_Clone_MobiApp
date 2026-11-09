class OptionEntity {
  final String id;
  final String content;
  final String? hint;

  const OptionEntity({
    required this.id,
    required this.content,
    this.hint,
  });
}

class QuestionEntity {
  final String id;
  final String content;
  final String questionType;
  final double defaultScore;
  final List<OptionEntity> options;

  const QuestionEntity({
    required this.id,
    required this.content,
    required this.questionType,
    required this.defaultScore,
    required this.options,
  });
}
