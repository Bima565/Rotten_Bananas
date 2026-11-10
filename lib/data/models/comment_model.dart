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
    required this.createdAt,
    this.updatedAt,
  });

  String get verdictLabel {
    switch (bananaVerdict) {
      case 'golden_ripe':
        return 'Golden Ripe';
      case 'bruised':
        return 'Bruised';
      case 'rotten':
        return 'Rotten Bananas';
      default:
        return 'Golden Ripe';
    }
  }

  String get verdictIcon {
    switch (bananaVerdict) {
      case 'golden_ripe':
        return '🍌';
      case 'bruised':
        return '🍌';
      case 'rotten':
        return '🤢';
      default:
        return '🍌';
    }
  }

  Color get verdictColor {
    switch (bananaVerdict) {
      case 'golden_ripe':
        return AppColors.statusFresh;
      case 'bruised':
        return AppColors.statusBruised;
      case 'rotten':
        return AppColors.statusRotten;
      default:
        return AppColors.statusFresh;
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

  factory CommentModel.fromMap(Map<String, dynamic> map, String docId) {
    return CommentModel(
      id: docId,
      movieId: (map['movie_id'] as num?)?.toInt() ?? 0,
      userId: map['user_id'] as String? ?? '',
      userName: map['user_name'] as String? ?? 'Penggemar Film',
      username: map['username'] as String? ?? 'user',
      userAvatar: map['user_avatar'] as String?,
      content: map['content'] as String? ?? '',
      bananaVerdict: map['banana_verdict'] as String? ?? 'golden_ripe',
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
      'banana_verdict': bananaVerdict,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
