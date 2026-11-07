import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../widgets/chapter_matrix_rule_card.dart';

class CreateEditExamPage extends StatefulWidget {
  final String? examId;

  const CreateEditExamPage({super.key, this.examId});

  @override
  State<CreateEditExamPage> createState() => _CreateEditExamPageState();
}

class _CreateEditExamPageState extends State<CreateEditExamPage> {
  final _formKey = GlobalKey<FormState>();
  final _apiClient = ApiClient();

  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _durationController = TextEditingController(text: '60');
  final _maxViolationsController = TextEditingController(text: '3');
  final _pinController = TextEditingController();
  final _minPassController = TextEditingController(text: '50');

  DateTime _startTime = DateTime.now().add(const Duration(minutes: 10));
  DateTime _endTime = DateTime.now().add(const Duration(hours: 3));

  String? _selectedSubjectId;
  String? _selectedClassId;
  String _selectedGradingMethod = 'ALL_CORRECT'; // ALL_CORRECT vs PARTIAL
  bool _allowReview = false;
  bool _shuffleQuestions = true;
  bool _shuffleOptions = true;

  // Chế độ ra đề: false = Thủ công, true = Ma trận tự động
  bool _isDynamicMatrix = false;
  bool _includePrivateInMatrix = true;
  List<dynamic> _subjectChapters = [];
  final Map<int, Map<String, int>> _matrixConfigRules = {};

  List<dynamic> _subjects = [];
  List<dynamic> _classes = [];
  List<dynamic> _classStudents = [];
  final Set<String> _selectedStudentIds = {};

  List<dynamic> _availableQuestions = [];
  final Set<String> _selectedQuestionIds = {};

  bool _isLoading = true;
  bool _isLoadingQuestions = false;
  bool _isLoadingClasses = false;
  bool _isLoadingStudents = false;
  bool _isSaving = false;

  bool get isEditing => widget.examId != null;

  @override
  void initState() {
    super.initState();
    _generateRandomPin();
    _loadInitialData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _durationController.dispose();
    _maxViolationsController.dispose();
    _pinController.dispose();
    _minPassController.dispose();
    super.dispose();
  }

  void _generateRandomPin() {
    final random = Random();
    final pin = (100000 + random.nextInt(900000)).toString();
    setState(() {
      _pinController.text = pin;
    });
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final subRes = await _apiClient.get(ApiEndpoints.subjectAccessSubjects);
      if (subRes['success'] == true && subRes['data'] is List) {
        _subjects = subRes['data'] as List;
        if (!isEditing && _subjects.isNotEmpty) {
          _selectedSubjectId = _subjects[0]['_id'];
          await Future.wait([
            _fetchQuestionsAndChapters(_selectedSubjectId!),
            _fetchClassesBySubject(_selectedSubjectId!),
          ]);
        }
      }

      if (isEditing) {
        final examRes = await _apiClient.get(ApiEndpoints.examDetail(widget.examId!));
        if (examRes['success'] == true && examRes['data'] != null) {
          final exam = examRes['data']['exam'];
          _titleController.text = exam['exam_title'] ?? '';
          _descController.text = exam['description'] ?? '';
          _durationController.text = (exam['duration_minutes'] ?? 60).toString();
          _maxViolationsController.text = (exam['max_violations'] ?? 3).toString();
          _pinController.text = exam['access_pin'] ?? '';
          _minPassController.text = (exam['min_pass_percentage'] ?? 50).toString();
          _selectedGradingMethod = exam['mcq_grading_method'] ?? 'ALL_CORRECT';
          _allowReview = exam['allow_review'] == true;
          _shuffleQuestions = exam['shuffle_questions'] == true;
          _shuffleOptions = exam['shuffle_options'] == true;

          if (exam['start_time'] != null) {
            _startTime = DateTime.tryParse(exam['start_time'])?.toLocal() ?? _startTime;
          }
          if (exam['end_time'] != null) {
            _endTime = DateTime.tryParse(exam['end_time'])?.toLocal() ?? _endTime;
          }

          if (exam['subject_id'] is Map) {
            _selectedSubjectId = exam['subject_id']['_id'];
          } else {
            _selectedSubjectId = exam['subject_id'];
          }

          if (exam['class_id'] is Map) {
            _selectedClassId = exam['class_id']['_id'];
          } else {
            _selectedClassId = exam['class_id'];
          }

          if (_selectedSubjectId != null) {
            await Future.wait([
              _fetchQuestionsAndChapters(_selectedSubjectId!),
              _fetchClassesBySubject(_selectedSubjectId!),
            ]);
          }

          if (_selectedClassId != null) {
            await _fetchClassStudents(_selectedClassId!);
          }

          // Kiểm tra cấu hình ma trận
          if (exam['matrix_config'] != null && exam['matrix_config']['is_dynamic'] == true) {
            _isDynamicMatrix = true;
            _includePrivateInMatrix = exam['matrix_config']['include_private'] != false;
            final rules = exam['matrix_config']['rules'] as List? ?? [];
            for (var r in rules) {
              final cNum = r['chapter_num'] is int ? r['chapter_num'] as int : int.tryParse(r['chapter_num'].toString()) ?? 1;
              final diff = (r['difficulty'] ?? 'MEDIUM').toString().toUpperCase();
              final count = r['count'] is int ? r['count'] as int : int.tryParse(r['count'].toString()) ?? 0;
              _matrixConfigRules.putIfAbsent(cNum, () => {'EASY': 0, 'MEDIUM': 0, 'HARD': 0});
              _matrixConfigRules[cNum]![diff] = count;
            }
          }

          final assignedQ = examRes['data']['questions'] as List? ?? [];
          for (var q in assignedQ) {
            if (q is Map && q['_id'] != null) {
              _selectedQuestionIds.add(q['_id']);
            }
          }

          final assignedStudents = examRes['data']['students'] as List? ?? [];
          for (var s in assignedStudents) {
            if (s is Map && s['_id'] != null) {
              _selectedStudentIds.add(s['_id']);
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải dữ liệu: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _fetchClassesBySubject(String subjectId) async {
    setState(() => _isLoadingClasses = true);
    try {
      final res = await _apiClient.get(ApiEndpoints.examClassesBySubject(subjectId));
      if (res['success'] == true && res['data'] is List) {
        final list = res['data'] as List;
        if (mounted) {
          setState(() {
            _classes = list;
            if (!isEditing && _classes.isNotEmpty) {
              _selectedClassId = _classes[0]['_id'];
              _fetchClassStudents(_selectedClassId!);
            }
            _isLoadingClasses = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingClasses = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingClasses = false);
    }
  }

  Future<void> _fetchClassStudents(String classId) async {
    setState(() => _isLoadingStudents = true);
    try {
      final res = await _apiClient.get(ApiEndpoints.examClassStudents(classId));
      if (res['success'] == true && res['data'] is List) {
        final students = res['data'] as List;
        if (mounted) {
          setState(() {
            _classStudents = students;
            if (!isEditing) {
              _selectedStudentIds.clear();
              for (var s in _classStudents) {
                if (s['_id'] != null) {
                  _selectedStudentIds.add(s['_id']);
                }
              }
            }
            _isLoadingStudents = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingStudents = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingStudents = false);
    }
  }

  Future<void> _fetchQuestionsAndChapters(String subjectId) async {
    setState(() {
      _isLoadingQuestions = true;
    });

    try {
      final futures = await Future.wait([
        _apiClient.get(ApiEndpoints.questionsBySubject(subjectId)),
        _apiClient.get(ApiEndpoints.chaptersBySubject(subjectId)),
      ]);

      final qRes = futures[0];
      final chRes = futures[1];

      if (mounted) {
        setState(() {
          if (qRes['success'] == true && qRes['data'] is List) {
            _availableQuestions = qRes['data'] as List;
            if (!isEditing && _selectedQuestionIds.isEmpty) {
              for (var q in _availableQuestions) {
                _selectedQuestionIds.add(q['_id']);
              }
            }
          }
          if (chRes['success'] == true && chRes['data'] is List) {
            _subjectChapters = chRes['data'] as List;
            for (var ch in _subjectChapters) {
              final cNum = ch['chapter_number'] is int ? ch['chapter_number'] as int : int.tryParse(ch['chapter_number'].toString()) ?? 1;
              _matrixConfigRules.putIfAbsent(cNum, () => {'EASY': 0, 'MEDIUM': 0, 'HARD': 0});
            }
          }
          _isLoadingQuestions = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingQuestions = false;
        });
      }
    }
  }

  int _getAvailableCount(int chapterNum, String diff) {
    return _availableQuestions.where((q) {
      final isPublic = (q['scope'] == 'PUBLIC' || q['is_public'] == true);
      if (!_includePrivateInMatrix && !isPublic) return false;

      int qChNum = 1;
      if (q['chapter_num'] != null) {
        qChNum = int.tryParse(q['chapter_num'].toString()) ?? 1;
      } else if (q['chapter_id'] is Map && q['chapter_id']['chapter_number'] != null) {
        qChNum = int.tryParse(q['chapter_id']['chapter_number'].toString()) ?? 1;
      }
      if (qChNum != chapterNum) return false;

      final qDiff = (q['difficulty'] ?? q['difficulty_level'] ?? 'MEDIUM').toString().toUpperCase();
      return qDiff == diff.toUpperCase();
    }).length;
  }

  int _getTotalMatrixQuestions() {
    int total = 0;
    _matrixConfigRules.forEach((_, diffs) {
      total += (diffs['EASY'] ?? 0) + (diffs['MEDIUM'] ?? 0) + (diffs['HARD'] ?? 0);
    });
    return total;
  }

  String? _validateMatrixConfig() {
    final total = _getTotalMatrixQuestions();
    if (total == 0) {
      return 'Vui lòng thiết lập số câu hỏi lớn hơn 0 trong ma trận đề thi';
    }

    for (var entry in _matrixConfigRules.entries) {
      final cNum = entry.key;
      final diffs = entry.value;

      final easyReq = diffs['EASY'] ?? 0;
      final easyAvail = _getAvailableCount(cNum, 'EASY');
      if (easyReq > easyAvail) {
        return 'Chương $cNum mức Dễ: yêu cầu $easyReq câu nhưng kho chỉ có $easyAvail câu';
      }

      final medReq = diffs['MEDIUM'] ?? 0;
      final medAvail = _getAvailableCount(cNum, 'MEDIUM');
      if (medReq > medAvail) {
        return 'Chương $cNum mức Trung bình: yêu cầu $medReq câu nhưng kho chỉ có $medAvail câu';
      }

      final hardReq = diffs['HARD'] ?? 0;
      final hardAvail = _getAvailableCount(cNum, 'HARD');
      if (hardReq > hardAvail) {
        return 'Chương $cNum mức Khó: yêu cầu $hardReq câu nhưng kho chỉ có $hardAvail câu';
      }
    }
    return null;
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final initialDate = isStart ? _startTime : _endTime;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );

    if (pickedTime == null || !mounted) return;

    setState(() {
      final combined = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
      if (isStart) {
        _startTime = combined;
        if (_endTime.isBefore(_startTime)) {
          _endTime = _startTime.add(Duration(minutes: int.tryParse(_durationController.text) ?? 60));
        }
      } else {
        _endTime = combined;
      }
    });
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedSubjectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn môn học cho ca thi'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_isDynamicMatrix) {
      final matrixError = _validateMatrixConfig();
      if (matrixError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(matrixError), backgroundColor: Colors.red),
        );
        return;
      }
    } else {
      if (_selectedQuestionIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng chọn ít nhất 1 câu hỏi vào đề thi'), backgroundColor: Colors.red),
        );
        return;
      }
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final List<Map<String, dynamic>> compiledRules = [];
      if (_isDynamicMatrix) {
        _matrixConfigRules.forEach((cNum, diffs) {
          if ((diffs['EASY'] ?? 0) > 0) {
            compiledRules.add({'chapter_num': cNum, 'difficulty': 'EASY', 'count': diffs['EASY']});
          }
          if ((diffs['MEDIUM'] ?? 0) > 0) {
            compiledRules.add({'chapter_num': cNum, 'difficulty': 'MEDIUM', 'count': diffs['MEDIUM']});
          }
          if ((diffs['HARD'] ?? 0) > 0) {
            compiledRules.add({'chapter_num': cNum, 'difficulty': 'HARD', 'count': diffs['HARD']});
          }
        });
      }

      final body = {
        'subject_id': _selectedSubjectId,
        'class_id': _selectedClassId,
        'exam_title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'start_time': _startTime.toIso8601String(),
        'end_time': _endTime.toIso8601String(),
        'duration_minutes': int.tryParse(_durationController.text.trim()) ?? 60,
        'max_violations': int.tryParse(_maxViolationsController.text.trim()) ?? 3,
        'access_pin': _pinController.text.trim(),
        'min_pass_percentage': int.tryParse(_minPassController.text.trim()) ?? 50,
        'mcq_grading_method': _selectedGradingMethod,
        'allow_review': _allowReview,
        'shuffle_questions': _shuffleQuestions,
        'shuffle_options': _shuffleOptions,
        'student_ids': _selectedStudentIds.toList(),
        'matrix_config': {
          'is_dynamic': _isDynamicMatrix,
          'rules': compiledRules,
          'include_private': _includePrivateInMatrix,
        },
        if (!_isDynamicMatrix)
          'question_ids': _selectedQuestionIds.toList(),
      };

      String examId;

      if (isEditing) {
        examId = widget.examId!;
        await _apiClient.put(ApiEndpoints.examDetail(examId), body: body);
      } else {
        final createRes = await _apiClient.post(ApiEndpoints.exams, body: body);
        if (createRes['success'] != true || createRes['data'] == null) {
          throw Exception(createRes['message'] ?? 'Tạo ca thi thất bại');
        }
        examId = createRes['data']['_id'];
      }

      // Nếu là chế độ chọn câu hỏi thủ công, gán câu hỏi cố định
      if (!_isDynamicMatrix && _selectedQuestionIds.isNotEmpty) {
        await _apiClient.post(
          ApiEndpoints.examQuestions(examId),
          body: {'question_ids': _selectedQuestionIds.toList()},
        );
      }

      // Gán danh sách sinh viên
      if (_selectedStudentIds.isNotEmpty) {
        await _apiClient.post(
          ApiEndpoints.examStudents(examId),
          body: {'student_ids': _selectedStudentIds.toList()},
        );
      }

      // Công bố ca thi nếu tạo mới
      if (!isEditing) {
        await _apiClient.patch(ApiEndpoints.examPublish(examId));
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEditing ? 'Cập nhật ca thi thành công' : 'Khởi tạo và công bố ca thi thành công'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: ${e.toString().replaceAll("Exception:", "").trim()}'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(isEditing ? 'Chỉnh sửa Ca thi' : 'Tạo mới Ca thi', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0.5,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Môn học & Lớp học
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedSubjectId,
                            decoration: const InputDecoration(
                              labelText: 'Môn học *',
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            items: _subjects.map((s) {
                              return DropdownMenuItem<String>(
                                value: s['_id'],
                                child: Text('${s['subject_code']} - ${s['subject_name']}', overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedSubjectId = val;
                                  _selectedQuestionIds.clear();
                                  _selectedClassId = null;
                                  _classStudents.clear();
                                  _selectedStudentIds.clear();
                                });
                                _fetchQuestionsAndChapters(val);
                                _fetchClassesBySubject(val);
                              }
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Lớp học
                    DropdownButtonFormField<String>(
                      value: _selectedClassId,
                      decoration: InputDecoration(
                        labelText: 'Lớp học ca thi',
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        suffixIcon: _isLoadingClasses
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : null,
                      ),
                      items: [
                        const DropdownMenuItem<String>(value: null, child: Text('Không gắn theo lớp cụ thể')),
                        ..._classes.map((c) {
                          return DropdownMenuItem<String>(
                            value: c['_id'],
                            child: Text('Lớp ${c['class_code']} (${c['semester']})', overflow: TextOverflow.ellipsis),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        setState(() {
                          _selectedClassId = val;
                          _classStudents.clear();
                          _selectedStudentIds.clear();
                        });
                        if (val != null) {
                          _fetchClassStudents(val);
                        }
                      },
                    ),

                    const SizedBox(height: 14),

                    // Exam Title
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Tiêu đề ca thi *',
                        hintText: 'VD: Thi kết thúc học phần Kỳ Fall 2026',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tiêu đề ca thi' : null,
                    ),

                    const SizedBox(height: 14),

                    // Date & Time pickers
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _pickDateTime(isStart: true),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Bắt đầu *',
                                border: OutlineInputBorder(),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              child: Text(
                                '${_startTime.day}/${_startTime.month} ${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: () => _pickDateTime(isStart: false),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Kết thúc *',
                                border: OutlineInputBorder(),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              child: Text(
                                '${_endTime.day}/${_endTime.month} ${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Duration (30-300 min) & Max violations
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _durationController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Thời lượng (30-300 phút) *',
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white,
                              helperText: 'Tối thiểu 30, tối đa 300p',
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Bắt buộc';
                              final d = int.tryParse(v.trim());
                              if (d == null || d < 30 || d > 300) {
                                return 'Từ 30 - 300 phút';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _maxViolationsController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Giới hạn vi phạm',
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white,
                              helperText: 'Mặc định 3 lần',
                            ),
                            validator: (v) => (v == null || int.tryParse(v) == null) ? 'Hợp lệ' : null,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Cách chấm điểm trắc nghiệm & Điểm sàn yêu cầu tối thiểu
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<String>(
                            value: _selectedGradingMethod,
                            decoration: const InputDecoration(
                              labelText: 'Cách chấm điểm trắc nghiệm',
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'ALL_CORRECT',
                                child: Text('Đúng tất cả mới tính điểm (All or Nothing)', overflow: TextOverflow.ellipsis),
                              ),
                              DropdownMenuItem(
                                value: 'PARTIAL',
                                child: Text('Tính điểm từng phần (Partial Credit)', overflow: TextOverflow.ellipsis),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedGradingMethod = val);
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _minPassController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Điểm sàn (%)',
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              helperText: 'Mặc định 50%',
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Bắt buộc';
                              final p = int.tryParse(v.trim());
                              if (p == null || p < 0 || p > 100) return 'Từ 0 - 100';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Access PIN with Random Button
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _pinController,
                            maxLength: 6,
                            decoration: const InputDecoration(
                              labelText: 'Mã PIN ca thi (6 số) *',
                              counterText: '',
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            validator: (v) => (v == null || v.length != 6) ? 'Cần 6 số' : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: _generateRandomPin,
                          icon: const Icon(Icons.shuffle, size: 18),
                          label: const Text('Tạo PIN'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E3A5F),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Security & Exam Config Toggles
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Cho phép xem lại bài thi sau khi nộp', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            subtitle: const Text('Sinh viên có thể xem chi tiết đáp án đúng sau khi nộp bài', style: TextStyle(fontSize: 11)),
                            value: _allowReview,
                            activeColor: const Color(0xFF1E3A5F),
                            onChanged: (val) => setState(() => _allowReview = val),
                          ),
                          const Divider(height: 1),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Xáo trộn thứ tự câu hỏi', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            value: _shuffleQuestions,
                            activeColor: const Color(0xFF1E3A5F),
                            onChanged: (val) => setState(() => _shuffleQuestions = val),
                          ),
                          const Divider(height: 1),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Xáo trộn thứ tự đáp án', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            value: _shuffleOptions,
                            activeColor: const Color(0xFF1E3A5F),
                            onChanged: (val) => setState(() => _shuffleOptions = val),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Phân bổ danh sách sinh viên dự thi theo Lớp
                    if (_selectedClassId != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Danh sách thí sinh (${_selectedStudentIds.length}/${_classStudents.length}):',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                                ),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      if (_selectedStudentIds.length == _classStudents.length) {
                                        _selectedStudentIds.clear();
                                      } else {
                                        for (var s in _classStudents) {
                                          if (s['_id'] != null) _selectedStudentIds.add(s['_id']);
                                        }
                                      }
                                    });
                                  },
                                  child: Text(_selectedStudentIds.length == _classStudents.length ? 'Bỏ chọn tất cả' : 'Chọn tất cả'),
                                ),
                              ],
                            ),
                            if (_isLoadingStudents)
                              const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
                            else if (_classStudents.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text('Lớp học này chưa có sinh viên nào ghi danh.', style: TextStyle(color: Colors.orange, fontSize: 12)),
                              )
                            else
                              Container(
                                constraints: const BoxConstraints(maxHeight: 180),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  itemCount: _classStudents.length,
                                  separatorBuilder: (context, _) => const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final stu = _classStudents[index];
                                    final sId = stu['_id'];
                                    final isEligible = _selectedStudentIds.contains(sId);

                                    return CheckboxListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      value: isEligible,
                                      activeColor: const Color(0xFF10B981),
                                      title: Text('${stu['user_code'] ?? ""} - ${stu['full_name'] ?? ""}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                      subtitle: Text(stu['email'] ?? '', style: const TextStyle(fontSize: 11, color: Colors.black54)),
                                      secondary: isEligible
                                          ? const Chip(label: Text('Đủ điều kiện', style: TextStyle(color: Colors.white, fontSize: 9)), backgroundColor: Color(0xFF10B981), padding: EdgeInsets.zero)
                                          : const Chip(label: Text('Cấm thi', style: TextStyle(color: Colors.white, fontSize: 9)), backgroundColor: Colors.red, padding: EdgeInsets.zero),
                                      onChanged: (val) {
                                        setState(() {
                                          if (val == true) {
                                            _selectedStudentIds.add(sId);
                                          } else {
                                            _selectedStudentIds.remove(sId);
                                          }
                                        });
                                      },
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Tiêu đề & Nút chuyển đổi Phương thức ra đề
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Phương thức thiết lập đề thi Trắc nghiệm',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => setState(() => _isDynamicMatrix = false),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: !_isDynamicMatrix ? const Color(0xFF1E3A5F) : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Chọn thủ công',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: !_isDynamicMatrix ? Colors.white : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: InkWell(
                                  onTap: () => setState(() => _isDynamicMatrix = true),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: _isDynamicMatrix ? const Color(0xFF1E3A5F) : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Ma trận tự động',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: _isDynamicMatrix ? Colors.white : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_isDynamicMatrix) ...[
                            const SizedBox(height: 10),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              title: const Text('Bao gồm câu hỏi kho riêng (Private) của tôi', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              subtitle: const Text('Hệ thống sẽ bốc ngẫu nhiên từ cả kho Public và Private của bạn', style: TextStyle(fontSize: 11)),
                              value: _includePrivateInMatrix,
                              activeColor: const Color(0xFF1E3A5F),
                              onChanged: (val) => setState(() => _includePrivateInMatrix = val),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Giao diện theo Phương thức ra đề
                    if (!_isDynamicMatrix) ...[
                      // CÁCH 1: TỰ CHỌN CÂU HỎI THỦ CÔNG
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Chọn câu hỏi vào đề (${_selectedQuestionIds.length}/${_availableQuestions.length}):',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                if (_selectedQuestionIds.length == _availableQuestions.length) {
                                  _selectedQuestionIds.clear();
                                } else {
                                  for (var q in _availableQuestions) {
                                    _selectedQuestionIds.add(q['_id']);
                                  }
                                }
                              });
                            },
                            child: Text(_selectedQuestionIds.length == _availableQuestions.length ? 'Bỏ chọn tất cả' : 'Chọn tất cả'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (_isLoadingQuestions)
                        const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()))
                      else if (_availableQuestions.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: Text('Môn học này chưa có câu hỏi nào trong Ngân hàng đề.', style: TextStyle(color: Colors.red)),
                        )
                      else
                        Container(
                          constraints: const BoxConstraints(maxHeight: 250),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: _availableQuestions.length,
                            separatorBuilder: (context, _) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final q = _availableQuestions[index];
                              final id = q['_id'];
                              final isChecked = _selectedQuestionIds.contains(id);
                              final isPublicQ = (q['scope'] == 'PUBLIC' || q['is_public'] == true);

                              return CheckboxListTile(
                                dense: true,
                                value: isChecked,
                                activeColor: const Color(0xFF1E3A5F),
                                title: Text(
                                  q['content'] ?? '',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                ),
                                subtitle: Text(
                                  'Kho: ${isPublicQ ? "Chung (Public)" : "Riêng (Private)"} | Độ khó: ${q['difficulty_level'] ?? q['difficulty']}',
                                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                                ),
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedQuestionIds.add(id);
                                    } else {
                                      _selectedQuestionIds.remove(id);
                                    }
                                  });
                                },
                              );
                            },
                          ),
                        ),
                    ] else ...[
                      // CÁCH 2: THIẾT LẬP MA TRẬN ĐỀ TỰ ĐỘNG
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Cấu hình Ma trận bốc ngẫu nhiên:',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                          ),
                          Text(
                            'Tổng: ${_getTotalMatrixQuestions()} câu',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E3A5F)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (_isLoadingQuestions)
                        const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()))
                      else if (_subjectChapters.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: Text('Môn học này chưa có danh sách chương học.', style: TextStyle(color: Colors.red)),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _subjectChapters.length,
                          separatorBuilder: (context, _) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final ch = _subjectChapters[index];
                            final cNum = ch['chapter_number'] is int ? ch['chapter_number'] as int : int.tryParse(ch['chapter_number'].toString()) ?? 1;
                            final cTitle = ch['chapter_title'] ?? '';

                            _matrixConfigRules.putIfAbsent(cNum, () => {'EASY': 0, 'MEDIUM': 0, 'HARD': 0});
                            final curEasy = _matrixConfigRules[cNum]!['EASY'] ?? 0;
                            final curMed = _matrixConfigRules[cNum]!['MEDIUM'] ?? 0;
                            final curHard = _matrixConfigRules[cNum]!['HARD'] ?? 0;

                            final maxEasy = _getAvailableCount(cNum, 'EASY');
                            final maxMed = _getAvailableCount(cNum, 'MEDIUM');
                            final maxHard = _getAvailableCount(cNum, 'HARD');

                            return ChapterMatrixRuleCard(
                              chapterNum: cNum,
                              chapterTitle: cTitle,
                              maxEasy: maxEasy,
                              maxMed: maxMed,
                              maxHard: maxHard,
                              curEasy: curEasy,
                              curMed: curMed,
                              curHard: curHard,
                              onEasyChanged: (newVal) {
                                setState(() {
                                  _matrixConfigRules[cNum]!['EASY'] = newVal;
                                });
                              },
                              onMedChanged: (newVal) {
                                setState(() {
                                  _matrixConfigRules[cNum]!['MEDIUM'] = newVal;
                                });
                              },
                              onHardChanged: (newVal) {
                                setState(() {
                                  _matrixConfigRules[cNum]!['HARD'] = newVal;
                                });
                              },
                            );
                          },
                        ),
                    ],

                    const SizedBox(height: 24),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _handleSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E3A5F),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: _isSaving
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text(
                                isEditing ? 'Lưu thay đổi' : 'Tạo ca thi & Công bố',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
