import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../model/User.dart';

class UserDatabaseHelper {
  static final UserDatabaseHelper instance = UserDatabaseHelper._init();
  static Database? _database;

  UserDatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('app_database.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        username TEXT NOT NULL,
        password TEXT NOT NULL,
        email TEXT NOT NULL,
        avatar TEXT,
        createdAt TEXT NOT NULL,
        lastActive TEXT NOT NULL,
        isAdmin INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('CREATE INDEX idx_users_username ON users(username)');
    await db.execute('CREATE INDEX idx_users_email ON users(email)');
    await _insertSampleData(db);
  }

  Future<void> _insertSampleData(Database db) async {
    const sampleUsers = [
      {
        'id': 'user1',
        'username': 'Nguyễn Văn A',
        'password': '123456a@',
        'email': 'nguyenvana@gmail.com',
        'avatar': null,
        'createdAt': '2023-01-01T00:00:00.000Z',
        'lastActive': '2023-04-01T00:00:00.000Z',
        'isAdmin': 0,
      },
      {
        'id': 'user2',
        'username': 'Nguyễn Văn B',
        'password': '123456a@',
        'email': 'nguyenvanb@gmail.com',
        'avatar': null,
        'createdAt': '2023-02-10T00:00:00.000Z',
        'lastActive': '2023-04-10T00:00:00.000Z',
        'isAdmin': 0,
      },
      {
        'id': 'user3',
        'username': 'Nguyễn Văn C',
        'password': '123456a@',
        'email': 'nguyenvanc@gmail.com',
        'avatar': null,
        'createdAt': '2023-03-05T00:00:00.000Z',
        'lastActive': '2023-04-05T00:00:00.000Z',
        'isAdmin': 0,
      },
      {
        'id': 'user4',
        'username': 'Nguyễn Văn D',
        'password': '123456a@',
        'email': 'nguyenvand@gmail.com',
        'avatar': null,
        'createdAt': '2023-04-07T00:00:00.000Z',
        'lastActive': '2023-04-12T00:00:00.000Z',
        'isAdmin': 0,
      },
      {
        'id': 'user5',
        'username': 'Administrator',
        'password': '123456a@',
        'email': 'binhadmin@gmail.com',
        'avatar': null,
        'createdAt': '2023-05-10T00:00:00.000Z',
        'lastActive': '2023-05-15T00:00:00.000Z',
        'isAdmin': 1,
      },
    ];

    for (final userData in sampleUsers) {
      await db.insert('users', userData);
    }
  }

  Future<int> createUser(User user) async {
    final db = await database;
    return db.insert('users', user.toMap());
  }

  Future<List<User>> getAllUsers() async {
    final db = await database;
    final result = await db.query('users');
    return result.map(User.fromMap).toList();
  }

  Future<User?> getUserById(String id) async {
    final db = await database;
    final maps = await db.query('users', where: 'id = ?', whereArgs: [id]);
    return maps.isNotEmpty ? User.fromMap(maps.first) : null;
  }

  Future<User?> getUserByEmailAndPassword(String email, String password) async {
    final db = await database;
    final maps = await db.query(
      'users',
      where: 'email = ? AND password = ?',
      whereArgs: [email, password],
    );
    return maps.isNotEmpty ? User.fromMap(maps.first) : null;
  }

  Future<int> updateUser(User user) async {
    final db = await database;
    return db.update(
      'users',
      user.toMap(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  Future<int> deleteUser(String id) async {
    final db = await database;
    return db.delete('users', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<User>> searchUsersByUsername(String keyword) async {
    final db = await database;
    final result = await db.query(
      'users',
      where: 'username LIKE ?',
      whereArgs: ['%$keyword%'],
    );
    return result.map(User.fromMap).toList();
  }

  Future<List<User>> getAllUsersExcept(String exceptUserId) async {
    final db = await database;
    final result = await db.query(
      'users',
      where: 'id != ?',
      whereArgs: [exceptUserId],
    );
    return result.map(User.fromMap).toList();
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}