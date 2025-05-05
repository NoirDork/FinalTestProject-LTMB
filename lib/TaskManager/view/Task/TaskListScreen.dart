import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:taskmanager/TaskManager/view/Task/AddTaskScreen.dart';
import 'package:taskmanager/TaskManager/view/Task/EditTaskScreen.dart';
import 'package:taskmanager/TaskManager/model/Task.dart';
import 'package:taskmanager/TaskManager/view/Task/TaskDetailScreen.dart';
import 'package:taskmanager/TaskManager/view/Authentication/LoginScreen.dart';
import 'package:taskmanager/TaskManager/db/TaskDatabaseHelper.dart';
import 'package:taskmanager/TaskManager/db/UserDatabaseHelper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';

final appTheme = ThemeData(
  primaryColor: Colors.blue.shade600,
  colorScheme: ColorScheme.light(
    primary: Colors.blue.shade600,
    onPrimary: Colors.white,
    error: Colors.red.shade600,
    onSurface: Colors.black87,
  ),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(fontSize: 16, color: Colors.black87),
    titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    bodySmall: TextStyle(fontSize: 12, color: Colors.grey),
  ),
  cardTheme: CardTheme(
    elevation: 1,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    margin: const EdgeInsets.only(bottom: 16),
  ),
  appBarTheme: AppBarTheme(
    backgroundColor: Colors.blue.shade600,
    foregroundColor: Colors.white,
    elevation: 0,
    centerTitle: true,
  ),
  inputDecorationTheme: const InputDecorationTheme(
    border: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
    ),
    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  ),
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: Colors.blue.shade400,
    foregroundColor: Colors.white,
  ),
);

class TaskListScreen extends StatefulWidget {
  final String currentUserId;

  const TaskListScreen({Key? key, required this.currentUserId})
      : super(key: key);

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  List<Task> tasks = [];
  List<Task> filteredTasks = [];
  bool isGrid = false;
  String selectedStatus = 'Tất cả';
  String searchKeyword = '';
  bool _isLoading = false;
  bool _dbInitialized = false;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _initializeDatabase();
  }

  Future<void> _initializeDatabase() async {
    try {
      setState(() => _isLoading = true);
      await TaskDatabaseHelper.instance.database;
      setState(() => _dbInitialized = true);

      final user = await UserDatabaseHelper.instance.getUserById(
        widget.currentUserId,
      );
      _isAdmin = user?.isAdmin ?? false;

      await _loadTasks();
      debugPrint(
        'Initialized database, isAdmin: $_isAdmin, userId: ${widget.currentUserId}',
      );
    } catch (e) {
      debugPrint('Error initializing database: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khởi tạo database: $e'),
          backgroundColor: appTheme.colorScheme.error,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  bool _isTaskUpcoming(Task task) {
    if (task.dueDate == null) return false;
    final now = DateTime.now();
    final difference = task.dueDate!.difference(now).inDays;
    return difference >= 0 && difference <= 3;
  }

  bool _isTaskEnded(Task task) {
    if (task.dueDate == null) return false;
    final now = DateTime.now();
    final difference = task.dueDate!.difference(now).inDays;
    return difference < 0;
  }

  Future<void> _loadTasks() async {
    if (!_dbInitialized) return;

    try {
      setState(() => _isLoading = true);

      if (_isAdmin) {
        tasks = await TaskDatabaseHelper.instance.getAllTasks();
      } else {
        tasks = await TaskDatabaseHelper.instance.getTasksByUser(
          widget.currentUserId,
        );
      }

      debugPrint(
        'Loaded ${tasks.length} tasks for user ${widget.currentUserId}',
      );
      _applyFilters();
    } catch (e) {
      debugPrint('Error loading tasks: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi tải công việc: $e'),
          backgroundColor: appTheme.colorScheme.error,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    setState(() {
      filteredTasks =
          tasks.where((task) {
            final matchesStatus =
                selectedStatus == 'Tất cả' || task.status == selectedStatus;
            final matchesSearch =
                searchKeyword.isEmpty ||
                    task.title.toLowerCase().contains(
                      searchKeyword.toLowerCase(),
                    ) ||
                    task.description.toLowerCase().contains(
                      searchKeyword.toLowerCase(),
                    );
            return matchesStatus && matchesSearch;
          }).toList();

      filteredTasks.sort((a, b) => b.priority.compareTo(a.priority));
    });
  }

  Future<void> _deleteTask(String taskId) async {
    // Lấy công việc để kiểm tra người tạo
    final task = tasks.firstWhere((t) => t.id == taskId, orElse: () => throw Exception('Task not found'));

    // Kiểm tra quyền xóa
    bool canDelete = false;
    String? errorMessage;

    if (_isAdmin) {
      canDelete = true; // Admin luôn được xóa
    } else if (task.createdBy == widget.currentUserId) {
      // Kiểm tra xem công việc có do admin tạo không
      final creator = await UserDatabaseHelper.instance.getUserById(task.createdBy);
      if (creator?.isAdmin == false) {
        canDelete = true; // User có thể xóa công việc do họ tạo nếu không phải admin
      } else {
        errorMessage = 'Bạn không thể xóa Task của Admin gán cho bạn';
      }
    } else {
      // Kiểm tra xem công việc có do admin tạo không
      final creator = await UserDatabaseHelper.instance.getUserById(task.createdBy);
      if (creator?.isAdmin == true) {
        errorMessage = 'Bạn không thể xóa Task của Admin gán cho bạn';
      } else {
        errorMessage = 'Bạn chỉ có thể xóa công việc do bạn tạo';
      }
    }

    if (!canDelete) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage ?? 'Bạn không có quyền xóa công việc này'),
          backgroundColor: appTheme.colorScheme.error,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text(
          'Bạn có chắc chắn muốn xóa công việc này không?',
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Xóa',
              style: TextStyle(color: appTheme.colorScheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        setState(() => _isLoading = true);
        await TaskDatabaseHelper.instance.deleteTask(taskId);
        await _loadTasks();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Xóa công việc thành công'),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
        );
      } catch (e) {
        debugPrint('Error deleting task: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi xóa công việc: $e'),
            backgroundColor: appTheme.colorScheme.error,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: appTheme,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Danh sách Công việc'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadTasks,
              tooltip: 'Làm mới',
            ),
            IconButton(
              icon: Icon(isGrid ? Icons.view_list : Icons.grid_view),
              onPressed: () => setState(() => isGrid = !isGrid),
              tooltip: 'Chuyển dạng hiển thị',
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'logout') {
                  _showLogoutDialog();
                }
              },
              itemBuilder:
                  (ctx) => [
                PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(
                        Icons.exit_to_app,
                        color: appTheme.colorScheme.error,
                      ),
                      const SizedBox(width: 8),
                      const Text('Đăng xuất'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body:
        _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm công việc...',
                  prefixIcon: Icon(Icons.search, color: Colors.blue.shade600),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(color: Colors.blue.shade600),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(color: Colors.blue.shade600),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
                  ),
                ),
                onChanged: (value) {
                  searchKeyword = value;
                  _applyFilters();
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: DropdownButtonFormField<String>(
                value: selectedStatus,
                decoration: const InputDecoration(
                  labelText: 'Lọc theo trạng thái',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                ),
                items:
                [
                  'Tất cả',
                  'To do',
                  'In progress',
                  'Done',
                  'Cancelled',
                ]
                    .map(
                      (status) => DropdownMenuItem<String>(
                    value: status,
                    child: Text(status),
                  ),
                )
                    .toList(),
                onChanged: (value) {
                  selectedStatus = value!;
                  _applyFilters();
                },
              ),
            ),
            Expanded(
              child:
              isGrid ? _buildTaskGridView() : _buildTaskListView(),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) =>
                    AddTaskScreen(currentUserId: widget.currentUserId),
              ),
            );
            if (result == true) await _loadTasks();
          },
          child: const Icon(Icons.add),
          tooltip: 'Thêm công việc',
        ),
      ),
    );
  }

  Widget _buildTaskListView() {
    return ListView.builder(
      itemCount: filteredTasks.length,
      itemBuilder: (context, index) {
        final task = filteredTasks[index];
        final isUpcoming = _isTaskUpcoming(task);
        final isEnded = _isTaskEnded(task);
        final isDone = task.status == 'Done';
        final isCancelled = task.status == 'Cancelled';

        return Opacity(
          opacity: isCancelled && !_isAdmin ? 0.5 : 1.0,
          child: Card(
            color: _getPriorityColor(task.priority),
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: isDone ? 6 : (isUpcoming ? 8 : 2),
            shadowColor:
            isDone
                ? Colors.green
                : isUpcoming
                ? Colors.red
                : (isEnded ? Colors.black : Colors.grey),
            child: Container(
              decoration: BoxDecoration(
                border:
                isUpcoming && isDone
                    ? Border.all(color: Colors.green, width: 2)
                    : isUpcoming
                    ? Border.all(color: Colors.red, width: 2)
                    : null,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                title: Text(
                  task.title,
                  style: appTheme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  'Trạng thái: ${task.status} • Ưu tiên: ${_priorityText(task.priority)}',
                  style: appTheme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit, color: appTheme.primaryColor),
                      onPressed:
                      isCancelled && !_isAdmin
                          ? null
                          : () async {
                        final updatedTask = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => EditTaskScreen(
                              task: task,
                              currentUserId: widget.currentUserId,
                            ),
                          ),
                        );
                        if (updatedTask != null) {
                          await TaskDatabaseHelper.instance.updateTask(
                            updatedTask,
                          );
                          await _loadTasks();
                        }
                      },
                      tooltip: 'Chỉnh sửa',
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.delete,
                        color: appTheme.colorScheme.error,
                      ),
                      onPressed: () => _deleteTask(task.id),
                      tooltip: 'Xóa',
                    ),
                  ],
                ),
                onTap:
                isCancelled && !_isAdmin
                    ? null
                    : () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => TaskDetailScreen(task: task),
                    ),
                  );
                  await _loadTasks();
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTaskGridView() {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth < 400 ? 1 : 2; // Responsive: 1 cột cho màn hình nhỏ

    return GridView.builder(
      padding: const EdgeInsets.all(10),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 3 / 4, // Tăng chiều cao để chứa nội dung và nút
      ),
      itemCount: filteredTasks.length,
      itemBuilder: (context, index) {
        final task = filteredTasks[index];
        final isUpcoming = _isTaskUpcoming(task);
        final isEnded = _isTaskEnded(task);
        final isDone = task.status == 'Done';
        final isCancelled = task.status == 'Cancelled';

        return Opacity(
          opacity: isCancelled && !_isAdmin ? 0.5 : 1.0,
          child: GestureDetector(
            onTap: isCancelled && !_isAdmin
                ? null
                : () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TaskDetailScreen(task: task),
                ),
              );
              await _loadTasks();
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getPriorityColor(task.priority),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: isDone
                        ? Colors.green
                        : isUpcoming
                        ? Colors.red
                        : (isEnded ? Colors.black : Colors.grey.shade300),
                    blurRadius: isDone ? 6 : (isUpcoming ? 8 : 6),
                    offset: const Offset(2, 2),
                  ),
                ],
                border: isUpcoming && isDone
                    ? Border.all(color: Colors.green, width: 2)
                    : isUpcoming
                    ? Border.all(color: Colors.red, width: 2)
                    : null,
              ),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: appTheme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Trạng thái: ${task.status}',
                        style: appTheme.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Ưu tiên: ${_priorityText(task.priority)}',
                        style: appTheme.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (isUpcoming && task.dueDate != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Hạn: ${DateFormat('dd/MM').format(task.dueDate!)}',
                            style: appTheme.textTheme.bodySmall?.copyWith(
                              color: isDone ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                  if (!isCancelled || _isAdmin)
                    Positioned(
                      bottom: 8, // Move to bottom
                      right: 8, // Move to right
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.edit, color: appTheme.primaryColor),
                            onPressed: isCancelled && !_isAdmin
                                ? null
                                : () async {
                              final updatedTask = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => EditTaskScreen(
                                    task: task,
                                    currentUserId: widget.currentUserId,
                                  ),
                                ),
                              );
                              if (updatedTask != null) {
                                await TaskDatabaseHelper.instance.updateTask(updatedTask);
                                await _loadTasks();
                              }
                            },
                            tooltip: 'Chỉnh sửa',
                          ),
                          IconButton(
                            icon: Icon(Icons.delete, color: appTheme.colorScheme.error),
                            onPressed: () => _deleteTask(task.id),
                            tooltip: 'Xóa',
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
        title: const Text('Xác nhận đăng xuất'),
        content: const Text('Bạn có chắc chắn muốn đăng xuất?'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => const LoginScreen(),
                ),
                    (route) => false,
              );
            },
            child: Text(
              'Đăng xuất',
              style: TextStyle(color: appTheme.colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  Color _getPriorityColor(int priority) {
    switch (priority) {
      case 1:
        return Colors.green.shade100;
      case 2:
        return Colors.orange.shade100;
      case 3:
        return Colors.red.shade100;
      default:
        return Colors.grey.shade200;
    }
  }

  String _priorityText(int priority) {
    switch (priority) {
      case 1:
        return 'Thấp';
      case 2:
        return 'Trung Bình';
      case 3:
        return 'Cao';
      default:
        return 'Không xác định';
    }
  }
}