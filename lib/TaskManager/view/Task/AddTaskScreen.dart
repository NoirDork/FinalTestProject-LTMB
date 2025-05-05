import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../model/Task.dart';
import '../../model/User.dart';
import '../../db/TaskDatabaseHelper.dart';
import '../../db/UserDatabaseHelper.dart';

class AddTaskScreen extends StatefulWidget {
  final String currentUserId;

  const AddTaskScreen({Key? key, required this.currentUserId}) : super(key: key);

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _status = 'To do';
  int _priority = 1; // 1: Thấp, 2: Trung Bình, 3: Cao
  DateTime? _dueDate;
  String? _assignedTo;
  List<String> _attachments = [];
  List<User> _users = [];
  bool _isLoading = false;
  bool _isAdmin = false;

  final List<String> _statusOptions = ['To do', 'In progress', 'Done', 'Cancelled'];
  final List<Map<String, dynamic>> _priorityOptions = [
    {'value': 3, 'label': 'Cao'},
    {'value': 2, 'label': 'Trung Bình'},
    {'value': 1, 'label': 'Thấp'},
  ];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      User? currentUser = await UserDatabaseHelper.instance.getUserById(widget.currentUserId);
      _isAdmin = currentUser?.isAdmin ?? false;
      if (_isAdmin) {
        _users = await UserDatabaseHelper.instance.getAllUsers();
        _users.removeWhere((user) => user.id == widget.currentUserId);
      } else {
        _users = [];
      }
    } catch (e) {
      _showErrorSnackBar('Lỗi khi tải user: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickFiles() async {
    if (!_isAdmin) return;
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );
      if (result != null && result.files.isNotEmpty) {
        final appDir = await getApplicationDocumentsDirectory();
        List<String> newAttachments = [];
        for (var file in result.files) {
          if (file.path != null) {
            final newFileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
            final newFilePath = '${appDir.path}/$newFileName';
            await File(file.path!).copy(newFilePath);
            newAttachments.add(newFilePath);
          }
        }
        setState(() => _attachments.addAll(newAttachments));
      }
    } catch (e) {
      _showErrorSnackBar('Lỗi khi chọn file: $e');
    }
  }

  void _removeAttachment(int index) {
    if (!_isAdmin) return;
    setState(() => _attachments.removeAt(index));
  }

  Future<void> _selectDueDate(BuildContext context) async {
    if (!_isAdmin) return;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue.shade600,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: Colors.blue.shade600),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _dueDate) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _handleAddTask() async {
    if (_formKey.currentState!.validate()) {
      try {
        setState(() => _isLoading = true);
        List<Task> tasksToCreate = [];
        if (_assignedTo == 'all' && _isAdmin) {
          for (final user in _users) {
            tasksToCreate.add(Task(
              id: '${DateTime.now().millisecondsSinceEpoch}_${user.id}',
              title: _titleController.text,
              description: _descriptionController.text,
              status: _status,
              priority: _priority,
              dueDate: _dueDate,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              assignedTo: user.id,
              createdBy: widget.currentUserId,
              category: null,
              attachments: _attachments.isNotEmpty ? _attachments : null,
              completed: _status == 'Done',
            ));
          }
        } else {
          tasksToCreate.add(Task(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: _titleController.text,
            description: _descriptionController.text,
            status: _status,
            priority: _priority,
            dueDate: _dueDate,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            assignedTo: _isAdmin ? _assignedTo : widget.currentUserId,
            createdBy: widget.currentUserId,
            category: null,
            attachments: _attachments.isNotEmpty ? _attachments : null,
            completed: _status == 'Done',
          ));
        }
        for (final task in tasksToCreate) {
          await TaskDatabaseHelper.instance.createTask(task);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã thêm ${tasksToCreate.length} công việc'),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      } catch (e) {
        _showErrorSnackBar('Lỗi khi thêm công việc: $e');
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleCancel() {
    Navigator.pop(context);
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thêm công việc mới'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade600, Colors.blue.shade400],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : Center(
          child: Card(
            margin: const EdgeInsets.all(16),
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.add_task, size: 40, color: Colors.blue),
                      const SizedBox(height: 10),
                      const Text(
                        'Thêm công việc mới',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildSectionTitle('Tiêu đề'),
                      TextFormField(
                        controller: _titleController,
                        decoration: _inputDecoration(labelText: 'Tiêu đề *'),
                        validator: (value) =>
                        value == null || value.isEmpty ? 'Vui lòng nhập tiêu đề' : null,
                      ),
                      const SizedBox(height: 20),
                      _buildSectionTitle('Mô tả'),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: _inputDecoration(labelText: 'Mô tả'),
                      ),
                      const SizedBox(height: 20),
                      _buildSectionTitle('Trạng thái'),
                      DropdownButtonFormField<String>(
                        value: _status,
                        isExpanded: true,
                        decoration: _inputDecoration(labelText: 'Trạng thái'),
                        items: _statusOptions
                            .map((status) => DropdownMenuItem(
                          value: status,
                          child: Flexible(
                            child: Text(
                              status,
                              style: const TextStyle(fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ))
                            .toList(),
                        onChanged: (value) => setState(() => _status = value!),
                      ),
                      const SizedBox(height: 20),
                      _buildSectionTitle('Độ ưu tiên'),
                      DropdownButtonFormField<int>(
                        value: _priority,
                        isExpanded: true,
                        decoration: _inputDecoration(labelText: 'Độ ưu tiên'),
                        items: _priorityOptions
                            .map((option) => DropdownMenuItem<int>(
                          value: option['value'] as int,
                          child: Flexible(
                            child: Text(
                              option['label'] as String,
                              style: const TextStyle(fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ))
                            .toList(),
                        onChanged: (value) => setState(() => _priority = value!),
                      ),
                      if (_isAdmin) ...[
                        const SizedBox(height: 20),
                        _buildSectionTitle('Ngày đến hạn'),
                        InkWell(
                          onTap: () => _selectDueDate(context),
                          child: InputDecorator(
                            decoration: _inputDecoration(labelText: 'Ngày đến hạn'),
                            child: Text(
                              _dueDate == null
                                  ? 'Chọn ngày'
                                  : DateFormat('dd/MM/yyyy').format(_dueDate!),
                              style: TextStyle(
                                color: _dueDate == null ? Colors.grey : Colors.black,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        if (_users.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          _buildSectionTitle('Gán cho người dùng'),
                          DropdownButtonFormField<String>(
                            value: _assignedTo,
                            isExpanded: true,
                            decoration: _inputDecoration(labelText: 'Gán cho người dùng'),
                            items: [
                              const DropdownMenuItem<String>(
                                value: null,
                                child: Text('Không gán', style: TextStyle(fontSize: 14)),
                              ),
                              const DropdownMenuItem<String>(
                                value: 'all',
                                child: Text('Gán cho tất cả', style: TextStyle(fontSize: 14)),
                              ),
                              ..._users.map((user) => DropdownMenuItem<String>(
                                value: user.id,
                                child: Flexible(
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 12,
                                        backgroundColor: Colors.blue.shade100,
                                        child: Text(
                                          user.username[0].toUpperCase(),
                                          style: TextStyle(
                                            color: Colors.blue.shade800,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          user.username,
                                          style: const TextStyle(fontSize: 14),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )),
                            ],
                            onChanged: (value) => setState(() => _assignedTo = value),
                          ),
                        ],
                        const SizedBox(height: 20),
                        _buildSectionTitle('Tệp đính kèm'),
                        OutlinedButton(
                          onPressed: _pickFiles,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.blue.shade600),
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            'Chọn tệp đính kèm',
                            style: TextStyle(color: Colors.blue.shade600, fontSize: 14),
                          ),
                        ),
                        if (_attachments.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _attachments.asMap().entries.map((entry) {
                              final index = entry.key;
                              final path = entry.value;
                              return Chip(
                                label: Text(
                                  path.split('/').last,
                                  style: const TextStyle(fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                deleteIcon: const Icon(Icons.close, size: 18),
                                onDeleted: () => _removeAttachment(index),
                                backgroundColor: Colors.blue.shade50,
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                      const SizedBox(height: 30),
                      ElevatedButton(
                        onPressed: _handleAddTask,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Thêm công việc', style: TextStyle(fontSize: 16)),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: _handleCancel,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey.shade600,
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        child: const Text('Hủy', style: TextStyle(fontSize: 16)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      title,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        color: Colors.blue.shade800,
        fontSize: 16,
      ),
    ),
  );

  InputDecoration _inputDecoration({String? labelText}) => InputDecoration(
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: Colors.blue.shade600),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: Colors.blue.shade600),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
    ),
    labelText: labelText,
    labelStyle: TextStyle(color: Colors.blue.shade600),
    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
  );

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}