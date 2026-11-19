import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/movie_model.dart';
import '../models/user_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('rotten_bananas.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Tabel Pengguna Lokal (SQLite)
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uid TEXT,
        full_name TEXT NOT NULL,
        username TEXT NOT NULL,
        email TEXT NOT NULL,
        password_hash TEXT,
        bio TEXT,
        avatar_path TEXT,
        favorite_genres TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    // Tabel Watchlist Lokal (SQLite)
    await db.execute('''
      CREATE TABLE watchlist (
        id INTEGER PRIMARY KEY,
        title TEXT NOT NULL,
        poster_path TEXT,
        backdrop_path TEXT,
        vote_average REAL,
        vote_count INTEGER,
        release_date TEXT,
        overview TEXT,
        genre_ids TEXT,
        added_at TEXT
      )
    ''');
  }

  // ==================== USER OPERATIONS ====================

  Future<int> saveOrUpdateUser(UserModel user) async {
    final db = await instance.database;
    final existing = await getUserByEmail(user.email);

    if (existing != null) {
      return await db.update(
        'users',
        user.toMap(),
        where: 'email = ?',
        whereArgs: [user.email],
      );
    } else {
      return await db.insert(
        'users',
        user.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<UserModel?> getUserByEmail(String email) async {
    final db = await instance.database;
    final maps = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email.trim().toLowerCase()],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return UserModel.fromMap(maps.first);
    }
    return null;
  }

  Future<UserModel?> getFirstUser() async {
    final db = await instance.database;
    final maps = await db.query(
      'users',
      orderBy: 'updated_at DESC',
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return UserModel.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateUserProfile({
    required String email,
    required String fullName,
    required String username,
    required String bio,
    required String favoriteGenres,
    String? avatarPath,
  }) async {
    final db = await instance.database;
    final now = DateTime.now().toIso8601String();
    final data = <String, dynamic>{
      'full_name': fullName,
      'username': username,
      'bio': bio,
      'favorite_genres': favoriteGenres,
      'updated_at': now,
    };
    if (avatarPath != null) {
      data['avatar_path'] = avatarPath;
    }
    return await db.update(
      'users',
      data,
      where: 'email = ?',
      whereArgs: [email.trim().toLowerCase()],
    );
  }

  Future<int> updateUserPassword({
    required String email,
    required String passwordHash,
  }) async {
    final db = await instance.database;
    final now = DateTime.now().toIso8601String();
    return await db.update(
      'users',
      {
        'password_hash': passwordHash,
        'updated_at': now,
      },
      where: 'email = ?',
      whereArgs: [email.trim().toLowerCase()],
    );
  }

  // ==================== WATCHLIST OPERATIONS ====================

  Future<int> insertWatchlist(MovieModel movie) async {
    final db = await instance.database;
    final map = movie.toJson();
    map['added_at'] = DateTime.now().toIso8601String();
    map['genre_ids'] = movie.genreIds.join(',');

    return await db.insert(
      'watchlist',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> getWatchlistCount() async {
    final db = await instance.database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM watchlist'),
    );
    return count ?? 0;
  }

  Future<List<MovieModel>> getWatchlist() async {
    final db = await instance.database;
    final maps = await db.query('watchlist', orderBy: 'added_at DESC');
    return maps.map((map) {
      final copy = Map<String, dynamic>.from(map);
      if (copy['genre_ids'] is String) {
        final str = copy['genre_ids'] as String;
        copy['genre_ids'] = str.isEmpty
            ? <int>[]
            : str.split(',').map((e) => int.tryParse(e) ?? 0).toList();
      }
      return MovieModel.fromJson(copy);
    }).toList();
  }

  Future<int> deleteFromWatchlist(int movieId) async {
    final db = await instance.database;
    return await db.delete(
      'watchlist',
      where: 'id = ?',
      whereArgs: [movieId],
    );
  }

  Future<int> clearWatchlist() async {
    final db = await instance.database;
    return await db.delete('watchlist');
  }

  Future<void> close() async {
    final db = await instance.database;
    await db.close();
  }
}
