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
      body: {
        'identifier': identifier,
        'password': password,
      },
    );

    final data = response['data'];
    final token = data['token'];
    final user = UserModel.fromJson(data['user']);

    SessionService().saveSession(newToken: token, user: user);
    return user;
  }
}

