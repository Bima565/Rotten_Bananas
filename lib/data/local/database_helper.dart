import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/password_hasher.dart';
import '../models/user_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('rotten_bananas_app.db');
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
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        full_name TEXT NOT NULL,
        username TEXT NOT NULL UNIQUE,
        email TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        bio TEXT DEFAULT 'Pecinta film & pemburu trailer.',
        avatar_path TEXT,
        favorite_genres TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE watchlist (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        movie_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        poster_path TEXT,
        backdrop_path TEXT,
        vote_average REAL NOT NULL,
        release_date TEXT,
        genre_ids TEXT,
        added_at TEXT NOT NULL,
        UNIQUE(user_id, movie_id) ON CONFLICT REPLACE
      )
    ''');

    // Seed Akun Demo Default
    final now = DateTime.now().toIso8601String();
    final demoPasswordHash = PasswordHasher.hash('password123');
    final altPasswordHash = PasswordHasher.hash('secretpassword');

    await db.insert('users', {
      'full_name': 'Bima Prawira Dharma',
      'username': 'bima_cinema',
      'email': 'demo@gmail.com',
      'password_hash': demoPasswordHash,
      'bio': 'Pecinta film & pemburu trailer.',
      'favorite_genres': '28,12,878',
      'created_at': now,
      'updated_at': now,
    });

    await db.insert('users', {
      'full_name': 'Rotten Bananas Tester',
      'username': 'demo_user',
      'email': 'demo@rottenbananas.app',
      'password_hash': altPasswordHash,
      'bio': 'Penguji aplikasi Rotten Bananas.',
      'favorite_genres': '28,35,878',
      'created_at': now,
      'updated_at': now,
    });
  }

  // --- CRUD User Operations ---
  Future<int> registerUser(UserModel user) async {
    final db = await instance.database;
    return await db.insert('users', user.toMap());
  }

  Future<UserModel?> getUserByEmailOrUsername(String identifier) async {
    final db = await instance.database;
    final results = await db.query(
      'users',
      where: 'email = ? OR username = ?',
      whereArgs: [identifier, identifier],
      limit: 1,
    );

    if (results.isNotEmpty) {
      return UserModel.fromMap(results.first);
    }
    return null;
  }

  Future<UserModel?> getUserById(int id) async {
    final db = await instance.database;
    final results = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (results.isNotEmpty) {
      return UserModel.fromMap(results.first);
    }
    return null;
  }

  Future<bool> isEmailOrUsernameTaken(String email, String username) async {
    final db = await instance.database;
    final results = await db.query(
      'users',
      where: 'email = ? OR username = ?',
      whereArgs: [email, username],
      limit: 1,
    );
    return results.isNotEmpty;
  }

  Future<int> updateUser(UserModel user) async {
    final db = await instance.database;
    return await db.update(
      'users',
      user.toMap(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
    }
  }
}
