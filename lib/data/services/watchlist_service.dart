import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/movie_model.dart';

class WatchlistService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _currentUid => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>>? get _watchlistRef {
    final uid = _currentUid;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid).collection('watchlist');
  }

  // Stream realtime daftar watchlist pengguna
  Stream<List<MovieModel>> getWatchlistStream() {
    final ref = _watchlistRef;
    if (ref == null) {
      return Stream.value([]);
    }

    return ref.orderBy('added_at', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return MovieModel.fromJson(data);
      }).toList();
    });
  }

  // Cek apakah film sudah ada di watchlist
  Future<bool> isMovieInWatchlist(int movieId) async {
    final ref = _watchlistRef;
    if (ref == null) return false;

    try {
      final doc = await ref.doc(movieId.toString()).get();
      return doc.exists;
    } catch (_) {
      return false;
    }
  }

  // Toggle simpan atau hapus film dari watchlist
  Future<bool> toggleWatchlist(MovieModel movie) async {
    final ref = _watchlistRef;
    if (ref == null) {
      throw Exception('Silakan masuk terlebih dahulu untuk menyimpan film.');
    }

    final docRef = ref.doc(movie.id.toString());
    final doc = await docRef.get();

    if (doc.exists) {
      await docRef.delete();
      return false; // Berhasil dihapus
    } else {
      final data = movie.toJson();
      data['added_at'] = DateTime.now().toIso8601String();
      await docRef.set(data);
      return true; // Berhasil disimpan
    }
  }

  // Hapus satu film dari watchlist
  Future<void> removeFromWatchlist(int movieId) async {
    final ref = _watchlistRef;
    if (ref == null) return;
    await ref.doc(movieId.toString()).delete();
  }
}
