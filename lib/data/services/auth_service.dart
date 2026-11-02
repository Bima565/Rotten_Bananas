import '../../core/password_hasher.dart';
import '../local/database_helper.dart';
import '../local/session_manager.dart';
import '../models/user_model.dart';

class AuthService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<UserModel> register({
    required String fullName,
    required String username,
    required String email,
    required String password,
    required List<int> favoriteGenreIds,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanUsername = username.trim().toLowerCase();

    final isTaken = await _dbHelper.isEmailOrUsernameTaken(cleanEmail, cleanUsername);
    if (isTaken) {
      throw Exception('Email atau Username sudah terdaftar.');
    }

    final now = DateTime.now().toIso8601String();
    final passwordHash = PasswordHasher.hash(password);

    final newUser = UserModel(
      fullName: fullName.trim(),
      username: cleanUsername,
      email: cleanEmail,
      passwordHash: passwordHash,
      favoriteGenres: favoriteGenreIds.join(','),
      createdAt: now,
      updatedAt: now,
    );

    final id = await _dbHelper.registerUser(newUser);
    final registeredUser = newUser.copyWith(id: id);

    await SessionManager.saveSession(
      userId: id,
      username: registeredUser.username,
      email: registeredUser.email,
    );

    return registeredUser;
  }

  Future<UserModel> login({
    required String identifier,
    required String password,
  }) async {
    final cleanIdentifier = identifier.trim().toLowerCase();
    final user = await _dbHelper.getUserByEmailOrUsername(cleanIdentifier);

    if (user == null) {
      throw Exception('Akun tidak ditemukan. Periksa email atau username Anda.');
    }

    final isMatch = PasswordHasher.verify(password, user.passwordHash);
    if (!isMatch) {
      throw Exception('Password salah. Silakan coba lagi.');
    }

    if (user.id != null) {
      await SessionManager.saveSession(
        userId: user.id!,
        username: user.username,
        email: user.email,
      );
    }

    return user;
  }

  Future<UserModel?> getCurrentUser() async {
    final userId = await SessionManager.getActiveUserId();
    if (userId == null) return null;
    return await _dbHelper.getUserById(userId);
  }

  Future<void> logout() async {
    await SessionManager.clearSession();
  }
}
