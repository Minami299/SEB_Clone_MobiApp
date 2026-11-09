import 'package:flutter/foundation.dart';
import '../../domain/entities/exam_entity.dart';
import '../../domain/usecases/get_exams_usecase.dart';

class ExamListNotifier extends ChangeNotifier {
  final GetExamsUseCase getExamsUseCase;

  ExamListNotifier({required this.getExamsUseCase});

  List<ExamEntity> _exams = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<ExamEntity> get exams => _exams;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchExams() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _exams = await getExamsUseCase();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
