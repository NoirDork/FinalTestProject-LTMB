import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../model/Task.dart';
import '../model/User.dart';

class TaskDatabaseHelper {
  static final TaskDatabaseHelper instance = TaskDatabaseHelper._init();
  static Database? _database;

  TaskDatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('tasks.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    final dbExists = await databaseExists(path);
    if (!dbExists) {
      await Directory(dirname(path)).create(recursive: true);
      return openDatabase(path, version: 1, onCreate: _createDB);
    }
    return openDatabase(path);
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE tasks (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        status TEXT NOT NULL,
        priority INTEGER NOT NULL,
        dueDate TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        assignedTo TEXT,
        createdBy TEXT NOT NULL,
        category TEXT,
        attachments TEXT,
        completed INTEGER NOT NULL
      )
    ''');

    await db.execute('CREATE INDEX idx_tasks_createdBy ON tasks(createdBy)');
    await db.execute('CREATE INDEX idx_tasks_status ON tasks(status)');
    await db.execute('CREATE INDEX idx_tasks_priority ON tasks(priority)');
    await _insertSampleData(db);
  }

  // Hàm chèn dữ liệu mẫu (không có attachments)
  Future<void> _insertSampleData(Database db) async {
    debugPrint('Inserting sample tasks...');
    final now = DateTime.now().toIso8601String();
    final tomorrow = DateTime.now().add(Duration(days: 1)).toIso8601String();
    final nextWeek = DateTime.now().add(Duration(days: 7)).toIso8601String();
    final yesterday = DateTime.now().subtract(Duration(days: 1)).toIso8601String();

    final sampleTasks = [
      {
        'id': 'task1',
        'title': 'Hoàn thành bài tập Lập trình Mobile',
        'description': 'Làm bài tập lớn về ứng dụng TaskManager, nộp trước hạn.',
        'status': 'To do',
        'priority': 3,
        'dueDate': nextWeek,
        'createdAt': now,
        'updatedAt': now,
        'assignedTo': 'user1',
        'createdBy': 'user5',
        'category': 'Học tập',
        'attachments': null,
        'completed': 0,
      },
      {
        'id': 'task2',
        'title': 'Chuẩn bị báo cáo nhóm',
        'description': 'Soạn slide PowerPoint cho thuyết trình môn Quản lý dự án.',
        'status': 'In progress',
        'priority': 2,
        'dueDate': tomorrow,
        'createdAt': yesterday,
        'updatedAt': now,
        'assignedTo': 'user2',
        'createdBy': 'user5',
        'category': 'Học tập',
        'attachments': null,
        'completed': 0,
      },
      {
        'id': 'task3',
        'title': 'Gửi email cho khách hàng',
        'description': 'Soạn email giới thiệu sản phẩm mới cho danh sách khách hàng.',
        'status': 'Done',
        'priority': 3,
        'dueDate': yesterday,
        'createdAt': yesterday,
        'updatedAt': yesterday,
        'assignedTo': 'user3',
        'createdBy': 'user5',
        'category': 'Công việc',
        'attachments': null,
        'completed': 1,
      },
      {
        'id': 'task4',
        'title': 'Mua thực phẩm cuối tuần',
        'description': 'Mua rau củ, thịt, và đồ dùng gia đình tại siêu thị.',
        'status': 'To do',
        'priority': 1,
        'dueDate': nextWeek,
        'createdAt': now,
        'updatedAt': now,
        'assignedTo': 'user4',
        'createdBy': 'user5',
        'category': 'Cá nhân',
        'attachments': null,
        'completed': 0,
      },
      {
        'id': 'task5',
        'title': 'Kiểm tra tài liệu hợp đồng',
        'description': 'Xem lại hợp đồng với đối tác, đảm bảo các điều khoản rõ ràng.',
        'status': 'In progress',
        'priority': 3,
        'dueDate': tomorrow,
        'createdAt': yesterday,
        'updatedAt': now,
        'assignedTo': 'user3',
        'createdBy': 'user5',
        'category': 'Công việc',
        'attachments': null,
        'completed': 0,
      },
      {
        'id': 'task6',
        'title': 'Học Flutter nâng cao',
        'description': 'Hoàn thành khóa học Flutter trên Udemy, tập trung vào state management.',
        'status': 'To do',
        'priority': 2,
        'dueDate': nextWeek,
        'createdAt': now,
        'updatedAt': now,
        'assignedTo': 'user1',
        'createdBy': 'user5',
        'category': 'Học tập',
        'attachments': null,
        'completed': 0,
      },
      {
        'id': 'task7',
        'title': 'Hủy kế hoạch họp nhóm',
        'description': 'Thông báo hủy họp do lịch trình thay đổi.',
        'status': 'Cancelled',
        'priority': 2,
        'dueDate': yesterday,
        'createdAt': yesterday,
        'updatedAt': now,
        'assignedTo': 'user1',
        'createdBy': 'user5',
        'category': 'Công việc',
        'attachments': null,
        'completed': 0,
      },
      {
        'id': 'task8',
        'title': 'Tập thể dục buổi sáng',
        'description': 'Chạy bộ 30 phút và tập yoga tại công viên.',
        'status': 'Done',
        'priority': 1,
        'dueDate': now,
        'createdAt': yesterday,
        'updatedAt': now,
        'assignedTo': 'user4',
        'createdBy': 'user4',
        'category': 'Cá nhân',
        'attachments': null,
        'completed': 1,
      },
      {
        'id': 'task9',
        'title': 'Cập nhật hồ sơ cá nhân',
        'description': 'Cập nhật CV và LinkedIn để chuẩn bị ứng tuyển.',
        'status': 'To do',
        'priority': 2,
        'dueDate': nextWeek,
        'createdAt': now,
        'updatedAt': now,
        'assignedTo': 'user2',
        'createdBy': 'user2',
        'category': 'Cá nhân',
        'attachments': null,
        'completed': 0,
      },
      {
        'id': 'task10',
        'title': 'Tổ chức sinh nhật',
        'description': 'Chuẩn bị tiệc sinh nhật cho bạn, đặt bánh và trang trí.',
        'status': 'In progress',
        'priority': 3,
        'dueDate': tomorrow,
        'createdAt': yesterday,
        'updatedAt': now,
        'assignedTo': 'user4',
        'createdBy': 'user4',
        'category': 'Cá nhân',
        'attachments': null,
        'completed': 0,
      },
    ];

    // Chèn từng công việc và log kết quả
    for (var task in sampleTasks) {
      try {
        await db.insert('tasks', task);
        debugPrint('Inserted task: ${task['id']} - ${task['title']}');
      } catch (e) {
        debugPrint('Error inserting task ${task['id']}: $e');
      }
    }

    // Kiểm tra số lượng bản ghi sau khi chèn
    final count = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM tasks'));
    debugPrint('Inserted $count sample tasks');
  }

  Future<int> createTask(Task task) async {
    final db = await database;
    return db.insert('tasks', task.toMap());
  }

  Future<List<Task>> getTasksByUser(String userId) async {
    final db = await database;
    final result = await db.query(
      'tasks',
      where: 'createdBy = ? OR assignedTo = ?',
      whereArgs: [userId, userId],
    );
    return result.map(Task.fromMap).toList();
  }

  Future<int> updateTask(Task task) async {
    final db = await database;
    return db.update(
      'tasks',
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  Future<List<Task>> getAllTasks() async {
    final db = await database;
    final result = await db.query('tasks');
    return result.map(Task.fromMap).toList();
  }

  Future<int> deleteTask(String id) async {
    final db = await database;
    return db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
