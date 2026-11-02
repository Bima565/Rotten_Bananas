import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  static const String _keyIsLoggedIn = 'is_logged_in';
  static const String _keyActiveUserId = 'active_user_id';
  static const String _keyActiveUsername = 'active_username';
  static const String _keyActiveEmail = 'active_email';

  static Future<void> saveSession({
    required int userId,
    required String username,
    required String email,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, true);
    await prefs.setInt(_keyActiveUserId, userId);
    await prefs.setString(_keyActiveUsername, username);
    await prefs.setString(_keyActiveEmail, email);
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsLoggedIn) ?? false;
  }

  static Future<int?> getActiveUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyActiveUserId);
  }

  static Future<String?> getActiveUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyActiveUsername);
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyIsLoggedIn);
    await prefs.remove(_keyActiveUserId);
    await prefs.remove(_keyActiveUsername);
    await prefs.remove(_keyActiveEmail);
  }
}
