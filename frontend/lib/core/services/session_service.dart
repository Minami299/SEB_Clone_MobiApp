import '../../features/auth/data/models/user_model.dart';

class SessionService {
  static final SessionService _instance = SessionService._internal();
  factory SessionService() => _instance;
  SessionService._internal();

  String? token;
  UserModel? currentUser;

  bool get isAuthenticated => token != null && token!.isNotEmpty;

  void saveSession({required String newToken, required UserModel user}) {
    token = newToken;
    currentUser = user;
  }

  void clearSession() {
    token = null;
    currentUser = null;
  }
}

