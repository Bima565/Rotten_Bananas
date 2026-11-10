import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/comment_model.dart';
import 'auth_service.dart';

class CommentService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final AuthService _authService;

  CommentService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    AuthService? authService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _authService = authService ?? AuthService();

  String? get currentUserId => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> _commentsRef(int movieId) {
    return _firestore
        .collection('movies')
        .doc(movieId.toString())
        .collection('comments');
  }

  /// Stream realtime seluruh komentar untuk satu film tertentu
  Stream<List<CommentModel>> getCommentsStream(int movieId, {int limit = 50}) {
    return _commentsRef(movieId)
        .orderBy('created_at', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => CommentModel.fromFirestore(doc))
          .toList();
    });
  }

  /// Tambah komentar & ulasan baru untuk sebuah film
  Future<void> addComment({
    required int movieId,
    required String content,
    required String bananaVerdict,
  }) async {
    final cleanContent = content.trim();
    if (cleanContent.isEmpty) {
      throw Exception('Isi ulasan komentar tidak boleh kosong.');
    }

    final currentUser = _auth.currentUser;
    final userProfile = await _authService.getCurrentUser();

    final uid = currentUser?.uid ?? userProfile?.uid;
    if (uid == null || uid.isEmpty) {
      throw Exception('Silakan masuk terlebih dahulu untuk memberikan ulasan.');
    }

    final fullName = (userProfile?.fullName.isNotEmpty == true)
        ? userProfile!.fullName
        : (currentUser?.displayName ?? 'Penggemar Film');

    final username = (userProfile?.username.isNotEmpty == true)
        ? userProfile!.username
        : (currentUser?.email?.split('@').first ?? 'user');

    final avatar = userProfile?.avatarPath ?? currentUser?.photoURL;

    final docRef = _commentsRef(movieId).doc();
    await docRef.set({
      'movie_id': movieId,
      'user_id': uid,
      'user_name': fullName,
      'username': username,
      'user_avatar': avatar,
      'content': cleanContent,
      'banana_verdict': bananaVerdict,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  /// Hapus komentar milik user sendiri
  Future<void> deleteComment({
    required int movieId,
    required String commentId,
  }) async {
    final uid = currentUserId;
    if (uid == null) {
      throw Exception('Silakan masuk terlebih dahulu.');
    }

    final docRef = _commentsRef(movieId).doc(commentId);
    final docSnapshot = await docRef.get();

    if (!docSnapshot.exists) {
      throw Exception('Komentar tidak ditemukan.');
    }

    final ownerId = docSnapshot.data()?['user_id'] as String?;
    if (ownerId != uid) {
      throw Exception('Anda hanya dapat menghapus komentar milik Anda sendiri.');
    }

    await docRef.delete();
  }
}
