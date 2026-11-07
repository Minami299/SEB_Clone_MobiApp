class UserModel {
  final String id;
  final String userCode;
  final String fullName;
  final String email;
  final String role;
  final String? departmentId;

  UserModel({
    required this.id,
    required this.userCode,
    required this.fullName,
    required this.email,
    required this.role,
    this.departmentId,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? json['_id'] ?? '',
      userCode: json['user_code'] ?? '',
      fullName: json['full_name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'STUDENT',
      departmentId: json['department_id']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_code': userCode,
      'full_name': fullName,
      'email': email,
      'role': role,
      'department_id': departmentId,
    };
  }
}

