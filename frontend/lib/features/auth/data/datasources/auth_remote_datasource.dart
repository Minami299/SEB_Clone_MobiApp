import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/services/session_service.dart';
import '../models/user_model.dart';

class AuthRemoteDataSource {
  final ApiClient apiClient;

  AuthRemoteDataSource({ApiClient? apiClient})
    : apiClient = apiClient ?? ApiClient();

  Future<UserModel> login({
    required String identifier,
    required String password,
  }) async {
    final response = await apiClient.post(
      ApiEndpoints.authLogin,
      body: {'identifier': identifier, 'password': password},
    );

    final data = response['data'];
    final token = data['token'];
    final user = UserModel.fromJson(data['user']);

    SessionService().saveSession(newToken: token, user: user);
    return user;
  }

  Future<Map<String, dynamic>> sendForgotOtp(String identifier) async {
    final response = await apiClient.post(
      ApiEndpoints.authForgotSendOtp,
      body: {'identifier': identifier},
    );
    return response as Map<String, dynamic>;
  }

  Future<String> verifyForgotOtpAndReset({
    required String identifier,
    required String otp,
    required String newPassword,
  }) async {
    final response = await apiClient.post(
      ApiEndpoints.authForgotVerifyOtp,
      body: {
        'identifier': identifier,
        'otp': otp,
        'new_password': newPassword,
      },
    );
    return response['message'] as String? ?? 'Đặt lại mật khẩu thành công';
  }

  Future<Map<String, dynamic>> sendProfileOtp() async {
    final response = await apiClient.post(ApiEndpoints.authProfileSendOtp);
    return response as Map<String, dynamic>;
  }

  Future<String> forgotPassword({
    required String identifier,
    required String newPassword,
  }) async {
    final response = await apiClient.post(
      ApiEndpoints.authForgotPassword,
      body: {
        'identifier': identifier,
        'new_password': newPassword,
      },
    );
    return response['message'] as String? ?? 'Đặt lại mật khẩu thành công';
  }

  Future<UserModel> getProfile() async {
    final response = await apiClient.get(ApiEndpoints.authMe);
    final user = UserModel.fromJson(response['data'] as Map<String, dynamic>);
    final currentToken = SessionService().token;
    if (currentToken != null) {
      SessionService().saveSession(newToken: currentToken, user: user);
    }
    return user;
  }

  Future<UserModel> updateProfile({
    String? fullName,
    String? email,
    String? currentPassword,
    String? newPassword,
    String? otp,
  }) async {
    final body = <String, dynamic>{};
    if (fullName != null && fullName.isNotEmpty) body['full_name'] = fullName;
    if (email != null && email.isNotEmpty) body['email'] = email;
    if (currentPassword != null && currentPassword.isNotEmpty)
      body['current_password'] = currentPassword;
    if (newPassword != null && newPassword.isNotEmpty)
      body['new_password'] = newPassword;
    if (otp != null && otp.isNotEmpty) body['otp'] = otp;

    final response = await apiClient.put(ApiEndpoints.authMe, body: body);

    final updated = UserModel.fromJson(
      response['data'] as Map<String, dynamic>,
    );
    final currentToken = SessionService().token;
    if (currentToken != null) {
      SessionService().saveSession(newToken: currentToken, user: updated);
    }
    return updated;
  }

  Future<List<UserModel>> getAllUsers({String? role, String? search}) async {
    final queryParams = <String, String>{};
    if (role != null && role.isNotEmpty) queryParams['role'] = role;
    if (search != null && search.isNotEmpty) queryParams['search'] = search;

    final uri = Uri.parse(ApiEndpoints.authUsers)
        .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
    final response = await apiClient.get(uri.toString());
    final list = response['data'] as List? ?? [];
    return list
        .map((item) => UserModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<UserModel> createUser({
    required String userCode,
    required String email,
    required String password,
    required String fullName,
    required String role,
    String? departmentId,
  }) async {
    final response = await apiClient.post(
      ApiEndpoints.authUsers,
      body: {
        'user_code': userCode,
        'email': email,
        'password': password,
        'full_name': fullName,
        'role': role,
        'department_id': ?departmentId,
      },
    );
    return UserModel.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<UserModel> updateUserRole({
    required String userId,
    required String role,
  }) async {
    final response = await apiClient.patch(
      ApiEndpoints.authUserRole(userId),
      body: {'role': role},
    );
    return UserModel.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<void> deleteUser(String userId) async {
    await apiClient.delete(ApiEndpoints.authUserDetail(userId));
  }
}
