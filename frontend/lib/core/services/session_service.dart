import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/auth/data/models/user_model.dart';

class SessionService {
  static final SessionService _instance = SessionService._internal();
  factory SessionService() => _instance;
  SessionService._internal();

  static const String _keyToken = 'auth_token';
  static const String _keyUser = 'auth_user';

  String? token;
  UserModel? currentUser;

  bool get isAuthenticated => token != null && token!.isNotEmpty && currentUser != null;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      token = prefs.getString(_keyToken);
      final userStr = prefs.getString(_keyUser);
      if (userStr != null && userStr.isNotEmpty) {
        final Map<String, dynamic> jsonMap = jsonDecode(userStr);
        currentUser = UserModel.fromJson(jsonMap);
      }
    } catch (_) {
      token = null;
      currentUser = null;
    }
  }

  void saveSession({required String newToken, required UserModel user}) {
    token = newToken;
    currentUser = user;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(_keyToken, newToken);
      prefs.setString(_keyUser, jsonEncode(user.toJson()));
    }).catchError((_) {});
  }

  void clearSession() {
    token = null;
    currentUser = null;
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove(_keyToken);
      prefs.remove(_keyUser);
    }).catchError((_) {});
  }
}
