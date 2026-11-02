class UserModel {
  final String? uid;
  final int? id;
  final String fullName;
  final String username;
  final String email;
  final String passwordHash;
  final String bio;
  final String? avatarPath;
  final String favoriteGenres; // comma separated: "28,12,878"
  final String createdAt;
  final String updatedAt;

  UserModel({
    this.uid,
    this.id,
    required this.fullName,
    required this.username,
    required this.email,
    this.passwordHash = '',
    this.bio = 'Pecinta film & pemburu trailer.',
    this.avatarPath,
    this.favoriteGenres = '',
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'full_name': fullName,
      'username': username,
      'email': email,
      'password_hash': passwordHash,
      'bio': bio,
      'avatar_path': avatarPath,
      'favorite_genres': favoriteGenres,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'full_name': fullName,
      'username': username,
      'email': email,
      'bio': bio,
      'avatar_path': avatarPath,
      'favorite_genres': favoriteGenres,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map, [String? docId]) {
    return UserModel(
      uid: docId ?? map['uid'] as String?,
      id: map['id'] as int?,
      fullName: map['full_name'] as String? ?? '',
      username: map['username'] as String? ?? '',
      email: map['email'] as String? ?? '',
      passwordHash: map['password_hash'] as String? ?? '',
      bio: map['bio'] as String? ?? 'Pecinta film & pemburu trailer.',
      avatarPath: map['avatar_path'] as String?,
      favoriteGenres: map['favorite_genres'] as String? ?? '',
      createdAt: map['created_at'] as String? ?? '',
      updatedAt: map['updated_at'] as String? ?? '',
    );
  }

  factory UserModel.fromFirestore(Map<String, dynamic> data, String uid) {
    return UserModel.fromMap(data, uid);
  }

  UserModel copyWith({
    String? uid,
    int? id,
    String? fullName,
    String? username,
    String? email,
    String? passwordHash,
    String? bio,
    String? avatarPath,
    String? favoriteGenres,
    String? createdAt,
    String? updatedAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      username: username ?? this.username,
      email: email ?? this.email,
      passwordHash: passwordHash ?? this.passwordHash,
      bio: bio ?? this.bio,
      avatarPath: avatarPath ?? this.avatarPath,
      favoriteGenres: favoriteGenres ?? this.favoriteGenres,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
