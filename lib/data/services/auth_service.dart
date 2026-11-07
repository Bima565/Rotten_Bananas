import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../local/session_manager.dart';
import '../models/user_model.dart';

class AuthService {
  FirebaseAuth? get _firebaseAuth {
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  FirebaseFirestore? get _firestore {
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: '703192737059-nu1lrh1id87me0r1gckosuqp7edj4r2o.apps.googleusercontent.com',
    scopes: ['email', 'profile'],
  );

  // --- REGISTER (100% Firebase Authentication + Cloud Firestore) ---
  Future<UserModel> register({
    required String fullName,
    required String username,
    required String email,
    required String password,
    required List<int> favoriteGenreIds,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanUsername = username.trim().toLowerCase();

    // 1. Cek apakah username sudah ada di Cloud Firestore (koleksi users)
    if (_firestore != null) {
      final usernameCheck = await _firestore!
          .collection('users')
          .where('username', isEqualTo: cleanUsername)
          .limit(1)
          .get();

      if (usernameCheck.docs.isNotEmpty) {
        throw Exception('Username "$cleanUsername" sudah digunakan.');
      }
    }

    // 2. Buat akun di Firebase Authentication
    if (_firebaseAuth == null) {
      throw Exception('Firebase Auth belum terhubung.');
    }

    UserCredential credential;
    try {
      credential = await _firebaseAuth!.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw Exception('Email sudah terdaftar. Silakan gunakan email lain atau langsung masuk.');
      } else if (e.code == 'weak-password') {
        throw Exception('Password terlalu lemah. Minimal 6 karakter.');
      } else if (e.code == 'invalid-email') {
        throw Exception('Format email tidak valid.');
      } else {
        throw Exception(e.message ?? 'Registrasi gagal.');
      }
    }

    final uid = credential.user!.uid;
    await credential.user?.updateDisplayName(fullName);

    final now = DateTime.now().toIso8601String();
    final newUser = UserModel(
      uid: uid,
      fullName: fullName.trim(),
      username: cleanUsername,
      email: cleanEmail,
      favoriteGenres: favoriteGenreIds.join(','),
      createdAt: now,
      updatedAt: now,
    );

    // 3. Simpan data profil pengguna ke Cloud Firestore
    if (_firestore != null) {
      await _firestore!.collection('users').doc(uid).set(newUser.toFirestore());
    }

    // Setelah mendaftar, sign out agar pengguna masuk ke halaman login untuk masuk
    await _firebaseAuth!.signOut();

    return newUser;
  }

  // --- LOGIN (100% Firebase Authentication + Cloud Firestore) ---
  Future<UserModel> login({
    required String identifier,
    required String password,
  }) async {
    final cleanId = identifier.trim().toLowerCase();
    String targetEmail = cleanId;

    if (_firestore == null || _firebaseAuth == null) {
      throw Exception('Firebase belum siap.');
    }

    // Jika identifier adalah username (tidak ada '@'), cari emailnya di Cloud Firestore
    if (!cleanId.contains('@')) {
      final query = await _firestore!
          .collection('users')
          .where('username', isEqualTo: cleanId)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        targetEmail = query.docs.first.data()['email'] as String? ?? cleanId;
      } else {
        throw Exception('Akun belum terdaftar. Silakan daftar terlebih dahulu.');
      }
    }

    // Login ke Firebase Auth dengan Email & Password
    UserCredential? credential;
    try {
      credential = await _firebaseAuth!.signInWithEmailAndPassword(
        email: targetEmail,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      // Jika Firebase Auth gagal, periksa apakah ada password baru di Cloud Firestore (dari Reset Password)
      final userQuery = await _firestore!
          .collection('users')
          .where('email', isEqualTo: targetEmail)
          .limit(1)
          .get();

      if (userQuery.docs.isNotEmpty) {
        final userData = userQuery.docs.first.data();
        final storedPassword = userData['password_hash'] as String?;
        if (storedPassword != null && storedPassword == password) {
          final uid = userQuery.docs.first.id;
          final user = UserModel.fromFirestore(userData, uid);
          await SessionManager.saveSession(
            userId: 1,
            username: user.username,
            email: user.email,
          );
          return user;
        } else {
          throw Exception('Password salah. Silakan periksa kembali kata sandi Anda.');
        }
      }

      if (e.code == 'user-not-found') {
        throw Exception('Akun belum terdaftar. Silakan daftar terlebih dahulu.');
      } else if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw Exception('Password salah. Silakan periksa kembali kata sandi Anda.');
      } else {
        throw Exception(e.message ?? 'Login gagal.');
      }
    }

    final uid = credential.user!.uid;

    // Ambil data profil dari Cloud Firestore
    UserModel? user;
    final doc = await _firestore!.collection('users').doc(uid).get();
    if (doc.exists && doc.data() != null) {
      user = UserModel.fromFirestore(doc.data()!, uid);
    }

    user ??= UserModel(
      uid: uid,
      fullName: credential.user!.displayName ?? cleanId,
      username: cleanId.contains('@') ? cleanId.split('@').first : cleanId,
      email: credential.user!.email ?? targetEmail,
      createdAt: DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
    );

    // Simpan status session aktif
    await SessionManager.saveSession(
      userId: 1,
      username: user.username,
      email: user.email,
    );

    return user;
  }

  // --- GOOGLE SIGN IN (100% Firebase Authentication + Cloud Firestore) ---
  Future<UserModel?> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      return null;
    }

    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final OAuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    if (_firebaseAuth == null) {
      throw Exception('Firebase Auth belum terhubung.');
    }

    final userCredential = await _firebaseAuth!.signInWithCredential(credential);
    final User? firebaseUser = userCredential.user;
    if (firebaseUser == null) return null;

    final uid = firebaseUser.uid;
    final email = firebaseUser.email ?? googleUser.email;
    final fullName = firebaseUser.displayName ?? googleUser.displayName ?? 'Google User';
    final username = email.split('@').first.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');

    // Cek apakah dokumen user sudah ada di Cloud Firestore
    UserModel? user;
    if (_firestore != null) {
      final doc = await _firestore!.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        user = UserModel.fromFirestore(doc.data()!, uid);
      } else {
        final now = DateTime.now().toIso8601String();
        user = UserModel(
          uid: uid,
          fullName: fullName,
          username: username,
          email: email,
          bio: 'Pengguna Rotten Bananas via Google.',
          avatarPath: firebaseUser.photoURL ?? googleUser.photoUrl,
          favoriteGenres: '28,12,878',
          createdAt: now,
          updatedAt: now,
        );
        await _firestore!.collection('users').doc(uid).set(user.toFirestore());
      }
    }

    user ??= UserModel(
      uid: uid,
      fullName: fullName,
      username: username,
      email: email,
      bio: 'Pengguna Rotten Bananas via Google.',
      avatarPath: firebaseUser.photoURL ?? googleUser.photoUrl,
      favoriteGenres: '28,12,878',
      createdAt: DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
    );

    await SessionManager.saveSession(
      userId: 1,
      username: user.username,
      email: user.email,
    );

    return user;
  }

  // --- AMBIL USER AKTIF DARI FIREBASE / LOCAL SESSION ---
  Future<UserModel?> getCurrentUser() async {
    final currentFirebaseUser = _firebaseAuth?.currentUser;
    if (currentFirebaseUser != null) {
      if (_firestore != null) {
        try {
          final doc = await _firestore!.collection('users').doc(currentFirebaseUser.uid).get();
          if (doc.exists && doc.data() != null) {
            return UserModel.fromFirestore(doc.data()!, currentFirebaseUser.uid);
          }
        } catch (_) {}
      }

      return UserModel(
        uid: currentFirebaseUser.uid,
        fullName: currentFirebaseUser.displayName ?? 'User',
        username: (currentFirebaseUser.email ?? 'user').split('@').first,
        email: currentFirebaseUser.email ?? '',
        avatarPath: currentFirebaseUser.photoURL,
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      );
    }

    // Jika Firebase currentUser null, periksa sesi aktif di SessionManager
    final isLoggedIn = await SessionManager.isLoggedIn();
    if (isLoggedIn && _firestore != null) {
      try {
        final email = await SessionManager.getActiveEmail();
        final username = await SessionManager.getActiveUsername();
        if (email != null && email.isNotEmpty) {
          final query = await _firestore!
              .collection('users')
              .where('email', isEqualTo: email)
              .limit(1)
              .get();
          if (query.docs.isNotEmpty) {
            return UserModel.fromFirestore(
                query.docs.first.data(), query.docs.first.id);
          }
        } else if (username != null && username.isNotEmpty) {
          final query = await _firestore!
              .collection('users')
              .where('username', isEqualTo: username)
              .limit(1)
              .get();
          if (query.docs.isNotEmpty) {
            return UserModel.fromFirestore(
                query.docs.first.data(), query.docs.first.id);
          }
        }
      } catch (_) {}
    }

    return null;
  }

  Future<void> logout() async {
    try {
      await _firebaseAuth?.signOut();
      await _googleSignIn.signOut();
    } catch (_) {}
    await SessionManager.clearSession();
  }

  /// Cek apakah akun saat ini sudah memiliki password
  Future<bool> userHasPassword() async {
    final user = _firebaseAuth?.currentUser;
    if (user == null) return false;

    final hasPasswordProvider =
        user.providerData.any((p) => p.providerId == 'password');
    if (hasPasswordProvider) return true;

    if (_firestore != null) {
      try {
        final doc =
            await _firestore!.collection('users').doc(user.uid).get();
        if (doc.exists && doc.data() != null) {
          if (doc.data()!['has_password'] == true) return true;
        }
      } catch (_) {}
    }
    return false;
  }

  /// Pasang / perbarui password (link Google ke Native Email & Password)
  Future<void> setAccountPassword(
    String newPassword, {
    String? currentPassword,
  }) async {
    final user = _firebaseAuth?.currentUser;
    if (user == null || user.email == null) {
      throw Exception('Pengguna tidak sedang login.');
    }

    if (currentPassword != null && currentPassword.isNotEmpty) {
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
    }

    final hasPasswordProvider =
        user.providerData.any((p) => p.providerId == 'password');

    if (hasPasswordProvider) {
      await user.updatePassword(newPassword);
    } else {
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: newPassword,
      );
      try {
        await user.linkWithCredential(credential);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'provider-already-linked' ||
            e.code == 'credential-already-in-use') {
          await user.updatePassword(newPassword);
        } else {
          rethrow;
        }
      }
    }

    try {
      await user.reload();
    } catch (_) {}

    if (_firestore != null) {
      try {
        await _firestore!.collection('users').doc(user.uid).set({
          'has_password': true,
          'password_hash': newPassword,
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {}
    }
  }

  /// Kirim link reset password resmi Firebase ke email
  Future<void> sendPasswordResetEmail(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    await _firebaseAuth?.sendPasswordResetEmail(email: cleanEmail);
  }
}
