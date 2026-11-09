import '../../domain/entities/question_entity.dart';

class OptionItemModel extends OptionEntity {
  OptionItemModel({
    required super.id,
    required super.content,
    super.hint,
  });

  factory OptionItemModel.fromJson(Map<String, dynamic> json) {
    return OptionItemModel(
      id: json['_id'] ?? json['id'] ?? '',
      content: json['option_content'] ?? '',
      hint: json['hint'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'option_content': content,
      'hint': hint,
    };
  }
}

class QuestionItemModel extends QuestionEntity {
  QuestionItemModel({
    required super.id,
    required super.content,
    required super.questionType,
    required super.defaultScore,
    required List<OptionItemModel> super.options,
  });

  factory QuestionItemModel.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> q = (json['question'] is Map<String, dynamic>)
        ? json['question'] as Map<String, dynamic>
        : json;
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

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'content': content,
      'question_type': questionType,
      'default_score': defaultScore,
      'options': options.map((opt) {
        if (opt is OptionItemModel) return opt.toJson();
        return {
          '_id': opt.id,
          'option_content': opt.content,
          'hint': opt.hint,
        };
      }).toList(),
    };
  }
}
