class OptionItemModel {
  final String id;
  final String content;
  final String? hint;

  OptionItemModel({
    required this.id,
    required this.content,
    this.hint,
  });

  factory OptionItemModel.fromJson(Map<String, dynamic> json) {
    return OptionItemModel(
      id: json['_id'] ?? json['id'] ?? '',
      content: json['option_content'] ?? '',
      hint: json['hint'],
    );
  }
}

class QuestionItemModel {
  final String id;
  final String content;
  final String questionType;
  final double defaultScore;
  final List<OptionItemModel> options;

  QuestionItemModel({
    required this.id,
    required this.content,
    required this.questionType,
    required this.defaultScore,
    required this.options,
  });

  factory QuestionItemModel.fromJson(Map<String, dynamic> json) {
    final q = json['question'] ?? {};
    final rawOptions = json['options'] as List? ?? [];

    return QuestionItemModel(
      id: q['_id'] ?? q['id'] ?? '',
      content: q['content'] ?? '',
      questionType: q['question_type'] ?? 'SINGLE_CHOICE',
      defaultScore: (q['default_score'] as num?)?.toDouble() ?? 1.0,
      options: rawOptions
          .map((item) => OptionItemModel.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

