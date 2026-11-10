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
  final _quitPinController = TextEditingController(text: '888888');
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
  String _studentFilterQuery = '';

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
    _loadInitialData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _durationController.dispose();
    _maxViolationsController.dispose();
    _quitPinController.dispose();
    _minPassController.dispose();
    super.dispose();
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
          _quitPinController.text = exam['exit_pin'] ?? '888888';
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

  void _showManageStudentsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final searchQuery = _studentFilterQuery.toLowerCase().trim();
            final filteredStudents = _classStudents.where((s) {
              if (searchQuery.isEmpty) return true;
              final name = (s['full_name'] ?? '').toString().toLowerCase();
              final code = (s['user_code'] ?? '').toString().toLowerCase();
              final email = (s['email'] ?? '').toString().toLowerCase();
              return name.contains(searchQuery) || code.contains(searchQuery) || email.contains(searchQuery);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Danh sách thí sinh dự thi',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          Text(
                            'Đã chọn ${_selectedStudentIds.length} / ${_classStudents.length} thí sinh',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showAddRetakeStudentDialog();
                        },
                        icon: const Icon(Icons.person_add, size: 14),
                        label: const Text('Thêm thi lại', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E3A5F),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Search field
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Tìm theo Tên hoặc Mã sinh viên...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      isDense: true,
                    ),
                    onChanged: (val) {
                      setModalState(() {
                        _studentFilterQuery = val;
                      });
                    },
                  ),
                  const SizedBox(height: 8),

                  // Chọn tất cả / Bỏ chọn tất cả
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            setState(() {
                              for (var s in _classStudents) {
                                if (s['_id'] != null) _selectedStudentIds.add(s['_id']);
                              }
                            });
                          });
                        },
                        child: const Text('Chọn tất cả', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            setState(() {
                              _selectedStudentIds.clear();
                            });
                          });
                        },
                        child: const Text('Bỏ chọn tất cả', style: TextStyle(fontSize: 12, color: Colors.red)),
                      ),
                    ],
                  ),
                  const Divider(height: 1),

                  // Student list
                  Expanded(
                    child: filteredStudents.isEmpty
                        ? const Center(
                            child: Text(
                              'Không có thí sinh nào phù hợp',
                              style: TextStyle(color: Color(0xFF64748B)),
                            ),
                          )
                        : ListView.separated(
                            itemCount: filteredStudents.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
                            itemBuilder: (c, idx) {
                              final s = filteredStudents[idx];
                              final id = s['_id'];
                              final isSelected = _selectedStudentIds.contains(id);
                              final isRetake = s['is_retake'] == true;
                              final name = s['full_name'] ?? 'Sinh viên';
                              final code = s['user_code'] ?? '';
                              final email = s['email'] ?? '';
                              final initial = name.isNotEmpty ? name.trim()[0].toUpperCase() : 'S';

                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: isRetake ? const Color(0xFFFFF7ED) : const Color(0xFFEFF6FF),
                                  child: Text(
                                    initial,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isRetake ? const Color(0xFFEA580C) : const Color(0xFF1D4ED8),
                                    ),
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isRetake) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFF7ED),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: const Color(0xFFFED7AA)),
                                        ),
                                        child: const Text(
                                          'Thi lại / Khác lớp',
                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFEA580C)),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                subtitle: Text(
                                  code.isNotEmpty ? '$code • $email' : email,
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: Checkbox(
                                  value: isSelected,
                                  activeColor: const Color(0xFF1E3A5F),
                                  onChanged: (val) {
                                    setModalState(() {
                                      setState(() {
                                        if (val == true) {
                                          _selectedStudentIds.add(id);
                                        } else {
                                          _selectedStudentIds.remove(id);
                                        }
                                      });
                                    });
                                  },
                                ),
                              );
                            },
                          ),
                  ),

                  // Bottom button
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A5F),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('Xác nhận (${_selectedStudentIds.length} thí sinh)'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAddRetakeStudentDialog() {
    final searchController = TextEditingController();
    List<dynamic> searchResults = [];
    bool isSearching = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            Future<void> executeSearch(String q) async {
              setDialogState(() => isSearching = true);
              try {
                final res = await _apiClient.get(ApiEndpoints.examSearchStudents(q: q.trim()));
                if (res['success'] == true && res['data'] is List) {
                  setDialogState(() {
                    searchResults = res['data'] as List;
                    isSearching = false;
                  });
                } else {
                  setDialogState(() => isSearching = false);
                }
              } catch (_) {
                setDialogState(() => isSearching = false);
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              title: const Row(
                children: [
                  Icon(Icons.person_add_alt_1, color: Color(0xFF1E3A5F), size: 20),
                  SizedBox(width: 8),
                  Text('Thêm thí sinh thi lại', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 380,
                child: Column(
                  children: [
                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: 'Nhập Mã SV (VD: SE180005) hoặc Tên...',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.arrow_forward, size: 18),
                          onPressed: () => executeSearch(searchController.text),
                        ),
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        isDense: true,
                      ),
                      onSubmitted: (val) => executeSearch(val),
                    ),
                    const SizedBox(height: 10),
                    if (isSearching)
                      const Expanded(child: Center(child: CircularProgressIndicator()))
                    else if (searchResults.isEmpty)
                      const Expanded(
                        child: Center(
                          child: Text(
                            'Nhập thông tin và bấm tìm kiếm để thêm thí sinh ngoài lớp vào ca thi',
                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.separated(
                          itemCount: searchResults.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (c, idx) {
                            final s = searchResults[idx];
                            final id = s['_id'];
                            final name = s['full_name'] ?? 'Sinh viên';
                            final code = s['user_code'] ?? '';
                            final email = s['email'] ?? '';
                            final alreadyAdded = _classStudents.any((existing) => existing['_id'] == id);

                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              subtitle: Text('$code • $email', style: const TextStyle(fontSize: 11)),
                              trailing: alreadyAdded
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFECFDF5),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text('Đã thêm', style: TextStyle(fontSize: 11, color: Color(0xFF047857), fontWeight: FontWeight.bold)),
                                    )
                                  : ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF1E3A5F),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        visualDensity: VisualDensity.compact,
                                        elevation: 0,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          final newStudent = Map<String, dynamic>.from(s);
                                          newStudent['is_retake'] = true;
                                          _classStudents.add(newStudent);
                                          if (id != null) _selectedStudentIds.add(id);
                                        });
                                        setDialogState(() {});
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Đã thêm thí sinh $name ($code) vào ca thi'), duration: const Duration(seconds: 1)),
                                        );
                                      },
                                      child: const Text('+ Thêm', style: TextStyle(fontSize: 11)),
                                    ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Đóng'),
                ),
              ],
            );
          },
        );
      },
    );
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

  Future<void> _showQuickAddQuestionDialog() async {
    if (_selectedSubjectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn môn học trước khi thêm câu hỏi')),
      );
      return;
    }

    final contentCtrl = TextEditingController();
    final optACtrl = TextEditingController();
    final optBCtrl = TextEditingController();
    final optCCtrl = TextEditingController();
    final optDCtrl = TextEditingController();
    int correctOpt = 0;
    String difficulty = 'MEDIUM';
    String? selectedChapterId = _subjectChapters.isNotEmpty ? _subjectChapters.first['_id'] : null;

    final added = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Row(
            children: [
              Icon(Icons.add_circle, color: Color(0xFF1E3A5F)),
              SizedBox(width: 8),
              Expanded(
                child: Text('Thêm câu hỏi nhanh (Kho riêng)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Nội dung câu hỏi *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: contentCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: 'Nhập đề bài câu hỏi...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.all(10),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Độ khó', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<String>(
                              value: difficulty,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'EASY', child: Text('Dễ')),
                                DropdownMenuItem(value: 'MEDIUM', child: Text('Trung bình')),
                                DropdownMenuItem(value: 'HARD', child: Text('Khó')),
                              ],
                              onChanged: (val) {
                                if (val != null) setDialogState(() => difficulty = val);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (_subjectChapters.isNotEmpty)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Chương', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              const SizedBox(height: 4),
                              DropdownButtonFormField<String>(
                                value: selectedChapterId,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                ),
                                items: _subjectChapters.map((ch) {
                                  return DropdownMenuItem<String>(
                                    value: ch['_id']?.toString(),
                                    child: Text(
                                      'Chương ${ch['chapter_number'] ?? ''}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) setDialogState(() => selectedChapterId = val);
                                },
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Các phương án (Tích chọn đáp án đúng):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 6),
                  _buildOptionInput(optACtrl, 'A', 0, correctOpt, (idx) => setDialogState(() => correctOpt = idx)),
                  const SizedBox(height: 6),
                  _buildOptionInput(optBCtrl, 'B', 1, correctOpt, (idx) => setDialogState(() => correctOpt = idx)),
                  const SizedBox(height: 6),
                  _buildOptionInput(optCCtrl, 'C', 2, correctOpt, (idx) => setDialogState(() => correctOpt = idx)),
                  const SizedBox(height: 6),
                  _buildOptionInput(optDCtrl, 'D', 3, correctOpt, (idx) => setDialogState(() => correctOpt = idx)),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A5F), foregroundColor: Colors.white),
              onPressed: () async {
                final content = contentCtrl.text.trim();
                if (content.isEmpty || optACtrl.text.trim().isEmpty || optBCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Vui lòng nhập nội dung câu hỏi và ít nhất 2 đáp án A, B')),
                  );
                  return;
                }
                final opts = [
                  {'content': optACtrl.text.trim(), 'is_correct': correctOpt == 0},
                  {'content': optBCtrl.text.trim(), 'is_correct': correctOpt == 1},
                  if (optCCtrl.text.trim().isNotEmpty) {'content': optCCtrl.text.trim(), 'is_correct': correctOpt == 2},
                  if (optDCtrl.text.trim().isNotEmpty) {'content': optDCtrl.text.trim(), 'is_correct': correctOpt == 3},
                ];

                try {
                  final res = await _apiClient.post(
                    ApiEndpoints.questions,
                    body: {
                      'subject_id': _selectedSubjectId,
                      'chapter_id': selectedChapterId ?? (_subjectChapters.isNotEmpty ? _subjectChapters.first['_id'] : null),
                      'content': content,
                      'question_type': 'SINGLE_CHOICE',
                      'difficulty': difficulty,
                      'difficulty_level': difficulty,
                      'scope': 'PRIVATE',
                      'options': opts,
                    },
                  );
                  if (res['success'] == true) {
                    Navigator.pop(ctx, true);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(res['message'] ?? 'Thêm câu hỏi thất bại')),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Lỗi thêm câu hỏi: $e')),
                  );
                }
              },
              child: const Text('Lưu vào Kho riêng'),
            ),
          ],
        ),
      ),
    );

    if (added == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã thêm câu hỏi vào Kho riêng của bạn!'), backgroundColor: Colors.green),
      );
      _fetchQuestionsAndChapters(_selectedSubjectId!);
    }
  }

  Widget _buildOptionInput(TextEditingController ctrl, String label, int idx, int currentCorrect, Function(int) onSelect) {
    final isSelected = idx == currentCorrect;
    return Row(
      children: [
        InkWell(
          onTap: () => onSelect(idx),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
            ),
            child: Text(label, style: TextStyle(color: isSelected ? Colors.white : const Color(0xFF475569), fontWeight: FontWeight.bold, fontSize: 11)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: ctrl,
            decoration: InputDecoration(
              hintText: 'Nội dung đáp án $label',
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleSave({bool publishImmediately = true}) async {
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
        'exit_pin': _quitPinController.text.trim(),
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

      // Công bố ca thi nếu người dùng chọn Mở ca thi ngay
      if (!isEditing && publishImmediately) {
        await _apiClient.patch(ApiEndpoints.examPublish(examId));
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEditing
              ? 'Cập nhật ca thi thành công'
              : (publishImmediately ? 'Đã tạo và mở ca thi thành công' : 'Đã lưu ca thi ở dạng bản nháp')),
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
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: isEditing
              ? SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : () => _handleSave(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A5F),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 1,
                    ),
                    child: _isSaving
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Lưu thay đổi', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                )
              : Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          onPressed: _isSaving ? null : () => _handleSave(publishImmediately: false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF1E3A5F),
                            side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: _isSaving
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Lưu bản nháp', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : () => _handleSave(publishImmediately: true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E3A5F),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 1,
                          ),
                          child: _isSaving
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('Mở ca thi ngay', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ==========================================
                    // CARD 1: THÔNG TIN CHUNG
                    // ==========================================
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.info_outline, size: 18, color: Color(0xFF1E3A5F)),
                              SizedBox(width: 8),
                              Text(
                                'THÔNG TIN CHUNG',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E3A5F), letterSpacing: 0.5),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Môn học (isExpanded: true)
                          DropdownButtonFormField<String>(
                            value: _selectedSubjectId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Môn học *',
                              border: OutlineInputBorder(),
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
                          const SizedBox(height: 12),

                          // Lớp học (isExpanded: true)
                          DropdownButtonFormField<String>(
                            value: _selectedClassId,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Lớp học ca thi',
                              border: const OutlineInputBorder(),
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
                          const SizedBox(height: 12),

                          // Khối quản lý Thí sinh dự thi & Thêm thí sinh thi lại
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.groups_outlined, size: 18, color: Color(0xFF1E3A5F)),
                                        SizedBox(width: 6),
                                        Text(
                                          'Thí sinh dự thi',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: _selectedStudentIds.isNotEmpty ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: _selectedStudentIds.isNotEmpty ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0),
                                        ),
                                      ),
                                      child: Text(
                                        'Đã chọn ${_selectedStudentIds.length} thí sinh',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: _selectedStudentIds.isNotEmpty ? const Color(0xFF1D4ED8) : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _showManageStudentsSheet,
                                        icon: const Icon(Icons.checklist, size: 15),
                                        label: const Text('Xem danh sách', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: const Color(0xFF1E3A5F),
                                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: _showAddRetakeStudentDialog,
                                        icon: const Icon(Icons.person_add_alt_1, size: 15),
                                        label: const Text('+ Thêm thi lại', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF1E3A5F),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          elevation: 0,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Tiêu đề ca thi
                          TextFormField(
                            controller: _titleController,
                            decoration: const InputDecoration(
                              labelText: 'Tiêu đề ca thi *',
                              hintText: 'VD: Thi kết thúc học phần Kỳ Fall 2026',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tiêu đề ca thi' : null,
                          ),
                          const SizedBox(height: 12),

                          // Thời gian Bắt đầu / Kết thúc với prefixIcon calendar
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => _pickDateTime(isStart: true),
                                  child: InputDecorator(
                                    decoration: const InputDecoration(
                                      labelText: 'Bắt đầu *',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.calendar_today_outlined, size: 18, color: Color(0xFF64748B)),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                                      prefixIcon: Icon(Icons.calendar_today_outlined, size: 18, color: Color(0xFF64748B)),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ==========================================
                    // CARD 2: CẤU HÌNH & BẢO MẬT
                    // ==========================================
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.tune, size: 18, color: Color(0xFF1E3A5F)),
                              SizedBox(width: 8),
                              Text(
                                'CẤU HÌNH & BẢO MẬT',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E3A5F), letterSpacing: 0.5),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Hàng 3 cột đều nhau: Thời lượng | Vi phạm tối đa | Điểm sàn (%)
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _durationController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Thời lượng (p) *',
                                    border: OutlineInputBorder(),
                                    helperText: '30-300p',
                                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) return 'Bắt buộc';
                                    final d = int.tryParse(v.trim());
                                    if (d == null || d < 30 || d > 300) return '30-300';
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  controller: _maxViolationsController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Vi phạm tối đa',
                                    border: OutlineInputBorder(),
                                    helperText: 'Mặc định 3',
                                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                  ),
                                  validator: (v) => (v == null || int.tryParse(v) == null) ? 'Hợp lệ' : null,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  controller: _minPassController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Điểm sàn (%)',
                                    border: OutlineInputBorder(),
                                    helperText: 'Mặc định 50%',
                                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) return 'Bắt buộc';
                                    final p = int.tryParse(v.trim());
                                    if (p == null || p < 0 || p > 100) return '0-100';
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Tách dòng cho trường "Cách chấm điểm trắc nghiệm" (Dễ hiểu, rõ ràng)
                          DropdownButtonFormField<String>(
                            value: _selectedGradingMethod,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Cách tính điểm câu trắc nghiệm',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'ALL_CORRECT',
                                child: Text('Đúng hết mới có điểm (Không chia nhỏ điểm)', overflow: TextOverflow.ellipsis),
                              ),
                              DropdownMenuItem(
                                value: 'PARTIAL',
                                child: Text('Đúng phần nào tính điểm phần đó (Chia nhỏ điểm)', overflow: TextOverflow.ellipsis),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedGradingMethod = val);
                            },
                          ),
                          const SizedBox(height: 14),

                          /*
                          // Mã thoát Kiosk khẩn cấp (Quit PIN / Safe Exam Browser standard)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.emergency_outlined, color: Color(0xFFDC2626), size: 18),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text(
                                        'Mã thoát Kiosk khẩn cấp (Master Quit PIN)',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF2F2),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFFFECACA)),
                                      ),
                                      child: const Text('SEB Kiosk', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _quitPinController,
                                  keyboardType: TextInputType.number,
                                  maxLength: 6,
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Colors.white,
                                    hintText: 'Mặc định 888888',
                                    counterText: '',
                                    prefixIcon: const Icon(Icons.key, size: 18, color: Color(0xFF64748B)),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Dùng khi sinh viên bị treo máy hoặc gặp sự cố khẩn cấp cần thoát Kiosk Safe Exam Browser sớm.',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          */

                          // 3 Switch bảo mật
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              children: [
                                SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Cho phép xem lại bài thi sau khi nộp', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

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
                            'Cách tạo đề thi trắc nghiệm',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              // Cách 1: Tự chọn câu hỏi (Đề cố định)
                              Expanded(
                                child: InkWell(
                                  onTap: () => setState(() => _isDynamicMatrix = false),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                    decoration: BoxDecoration(
                                      color: !_isDynamicMatrix ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: !_isDynamicMatrix ? const Color(0xFF1E3A5F) : const Color(0xFFE2E8F0),
                                        width: !_isDynamicMatrix ? 1.5 : 1,
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.playlist_add_check,
                                          size: 20,
                                          color: !_isDynamicMatrix ? const Color(0xFF1E3A5F) : const Color(0xFF94A3B8),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Tự chọn câu hỏi',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.bold,
                                            color: !_isDynamicMatrix ? const Color(0xFF1E3A5F) : const Color(0xFF475569),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Cả lớp chung 1 đề',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: !_isDynamicMatrix ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Cách 2: Bốc đề ngẫu nhiên (Mỗi em 1 đề)
                              Expanded(
                                child: InkWell(
                                  onTap: () => setState(() => _isDynamicMatrix = true),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                    decoration: BoxDecoration(
                                      color: _isDynamicMatrix ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: _isDynamicMatrix ? const Color(0xFF1E3A5F) : const Color(0xFFE2E8F0),
                                        width: _isDynamicMatrix ? 1.5 : 1,
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.shuffle,
                                          size: 20,
                                          color: _isDynamicMatrix ? const Color(0xFF1E3A5F) : const Color(0xFF94A3B8),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Bốc đề ngẫu nhiên',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.bold,
                                            color: _isDynamicMatrix ? const Color(0xFF1E3A5F) : const Color(0xFF475569),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Mỗi em 1 đề khác nhau',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: _isDynamicMatrix ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
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
                        children: [
                          Expanded(
                            child: Text(
                              'Chọn câu hỏi (${_selectedQuestionIds.length}/${_availableQuestions.length}):',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                            ),
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
                            child: Text(_selectedQuestionIds.length == _availableQuestions.length ? 'Bỏ chọn' : 'Chọn tất cả', style: const TextStyle(fontSize: 12)),
                          ),
                          const SizedBox(width: 4),
                          OutlinedButton.icon(
                            onPressed: _selectedSubjectId == null ? null : _showQuickAddQuestionDialog,
                            icon: const Icon(Icons.add_circle_outline, size: 14),
                            label: const Text('+ Thêm câu hỏi nhanh', style: TextStyle(fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF1D4ED8),
                              side: const BorderSide(color: Color(0xFF93C5FD)),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              visualDensity: VisualDensity.compact,
                            ),
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

                              final diff = (q['difficulty_level'] ?? q['difficulty'] ?? 'MEDIUM').toString().toUpperCase();
                              Color diffColor;
                              String diffText;
                              if (diff == 'EASY') {
                                diffColor = const Color(0xFF10B981);
                                diffText = 'Dễ';
                              } else if (diff == 'HARD') {
                                diffColor = const Color(0xFFEF4444);
                                diffText = 'Khó';
                              } else {
                                diffColor = const Color(0xFFF59E0B);
                                diffText = 'Trung bình';
                              }

                              return CheckboxListTile(
                                controlAffinity: ListTileControlAffinity.leading,
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                                value: isChecked,
                                activeColor: const Color(0xFF1E3A5F),
                                title: Text(
                                  q['content'] ?? '',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isPublicQ ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: isPublicQ ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0)),
                                        ),
                                        child: Text(
                                          isPublicQ ? 'Kho Chung (Public)' : 'Kho Riêng (Private)',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: isPublicQ ? const Color(0xFF1D4ED8) : const Color(0xFF475569),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: diffColor.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: diffColor.withOpacity(0.3)),
                                        ),
                                        child: Text(
                                          diffText,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: diffColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
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
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }
}
