import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';

class CommentModel {
  final String id;
  final int movieId;
  final String userId;
  final String userName;
  final String username;
  final String? userAvatar;
  final String content;
  final String bananaVerdict; // 'golden_ripe', 'bruised', 'rotten'
  final double rating; // Skala 1.0 - 5.0 (Rotten Tomatoes audience style)
  final DateTime createdAt;
  final DateTime? updatedAt;

  const CommentModel({
    required this.id,
    required this.movieId,
    required this.userId,
    required this.userName,
    required this.username,
    this.userAvatar,
    required this.content,
    required this.bananaVerdict,
    this.rating = 5.0,
    required this.createdAt,
    this.updatedAt,
  });

  /// Mengonversi nilai rating 1.0 - 5.0 menjadi status Banana Verdict
  static String verdictFromRating(double rating) {
    if (rating >= 4.0) {
      return 'golden_ripe';
    } else if (rating >= 3.0) {
      return 'bruised';
    } else {
      return 'rotten';
    }
  }

  /// Keterangan ringkas deskripsi penilaian bintang
  static String verdictDescription(double rating) {
    if (rating >= 5.0) {
      return 'Sangat Bagus (Masterpiece)';
    } else if (rating >= 4.0) {
      return 'Bagus & Layak Tonton';
    } else if (rating >= 3.0) {
      return 'Cukup / Lumayan';
    } else if (rating >= 2.0) {
      return 'Kurang Memuaskan';
    } else {
      return 'Mengecewakan (Flop)';
    }
  }

  String get verdictLabel {
    if (rating >= 5.0) {
      return 'Top Markotop';
    } else if (rating >= 4.0) {
      return 'Cakep';
    } else if (rating >= 3.0) {
      return 'Medioker';
    } else if (rating >= 2.0) {
      return 'Kureng';
    } else {
      return 'Ampas';
    }
  }

  IconData get verdictIcon {
    if (rating >= 5.0) {
      return Icons.workspace_premium_rounded;
    } else if (rating >= 4.0) {
      return Icons.verified_rounded;
    } else if (rating >= 3.0) {
      return Icons.thumbs_up_down_rounded;
    } else if (rating >= 2.0) {
      return Icons.warning_amber_rounded;
    } else {
      return Icons.heart_broken_rounded;
    }
  }

  Color get verdictColor {
    if (rating >= 5.0) {
      return AppColors.accentYellow;
    } else if (rating >= 4.0) {
      return AppColors.statusFresh;
    } else if (rating >= 3.0) {
      return AppColors.statusBruised;
    } else if (rating >= 2.0) {
      return const Color(0xFFE76F51);
    } else {
      return AppColors.statusRotten;
    }
  }

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inSeconds < 60) {
      return 'Baru saja';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m lalu';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}j lalu';
    } else if (diff.inDays < 30) {
      return '${diff.inDays}h lalu';
    } else {
      return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    }
  }

  static DateTime _parseDateTime(dynamic val) {
    if (val == null) return DateTime.now();
    if (val is Timestamp) return val.toDate();
    if (val is DateTime) return val;
    if (val is String) {
      return DateTime.tryParse(val) ?? DateTime.now();
    }
    return DateTime.now();
  }

  static double _parseRating(dynamic val, String verdict) {
    if (val != null) {
      if (val is num) return val.toDouble();
      if (val is String) {
        final parsed = double.tryParse(val);
        if (parsed != null) return parsed;
      }
    }
    // Fallback cerdas untuk data ulasan terdahulu di Firestore
    switch (verdict) {
      case 'golden_ripe':
        return 5.0;
      case 'bruised':
        return 3.0;
      case 'rotten':
        return 1.0;
      default:
        return 5.0;
    }
  }

  factory CommentModel.fromMap(Map<String, dynamic> map, String docId) {
    final verdict = map['banana_verdict'] as String? ?? 'golden_ripe';
    final parsedRating = _parseRating(map['rating'], verdict);

    return CommentModel(
      id: docId,
      movieId: (map['movie_id'] as num?)?.toInt() ?? 0,
      userId: map['user_id'] as String? ?? '',
      userName: map['user_name'] as String? ?? 'Penggemar Film',
      username: map['username'] as String? ?? 'user',
      userAvatar: map['user_avatar'] as String?,
      content: map['content'] as String? ?? '',
      bananaVerdict: verdict,
      rating: parsedRating,
      createdAt: _parseDateTime(map['created_at']),
      updatedAt: map['updated_at'] != null ? _parseDateTime(map['updated_at']) : null,
    );
  }

  factory CommentModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return CommentModel.fromMap(doc.data() ?? {}, doc.id);
  }

  Map<String, dynamic> toFirestore() {
    return {
      'movie_id': movieId,
      'user_id': userId,
      'user_name': userName,
      'username': username,
      'user_avatar': userAvatar,
      'content': content,
      'rating': rating,
      'banana_verdict': bananaVerdict,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'movie_id': movieId,
      'user_id': userId,
      'user_name': userName,
      'username': username,
      'user_avatar': userAvatar,
      'content': content,
      'rating': rating,
      'banana_verdict': bananaVerdict,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
