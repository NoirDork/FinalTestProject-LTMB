import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../model/Task.dart';
import '../../model/User.dart';
import '../../db/UserDatabaseHelper.dart';
import '../../db/TaskDatabaseHelper.dart';

class EditTaskScreen extends StatefulWidget {
  final Task task;
  final String currentUserId;
  final bool isReadOnly;

  const EditTaskScreen({
    super.key,
    required this.task,
    required this.currentUserId,
    this.isReadOnly = false,
  });

  @override
  State<EditTaskScreen> createState() => _EditTaskScreenState();
}

class _EditTaskScreenState extends State<EditTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late String _status;
  late int _priority;
  late DateTime? _dueDate;
  late String? _assignedTo;
  late List<String> _attachments;
  List<User> _users = [];
  bool _isLoading = false;
  bool _isAdmin = false;
  bool _isCreator = false;

  static const _statusOptions = ['To do', 'In progress', 'Done', 'Cancelled'];
  static const _priorityOptions = [
    {'value': 3, 'label': 'Cao'},
    {'value': 2, 'label': 'Trung Bình'},
    {'value': 1, 'label': 'Thấp'},
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task.title);
    _descriptionController = TextEditingController(text: widget.task.description);
    _status = widget.task.status;
    _priority = widget.task.priority;
    _dueDate = widget.task.dueDate;
    _assignedTo = widget.task.assignedTo;
    _attachments = widget.task.attachments ?? [];
    _isCreator = widget.task.createdBy == widget.currentUserId;
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final currentUser = await UserDatabaseHelper.instance.getUserById(widget.currentUserId);
      _isAdmin = currentUser?.isAdmin ?? false;
      _users = _isAdmin
          ? await UserDatabaseHelper.instance.getAllUsersExcept(widget.currentUserId)
          : [];
    } catch (e) {
      _showErrorSnackBar('Lỗi khi tải danh sách người dùng: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickFiles() async {
    if (!_isAdmin || widget.isReadOnly) return;
    try {
      final result = await FilePicker.platform.pickFiles(allowMultiple: true, type: FileType.any);
      if (result != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final newAttachments = <String>[];
        for (final file in result.files) {
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
    if (!_isAdmin || widget.isReadOnly) return;
    setState(() => _attachments.removeAt(index));
  }

  Future<void> _selectDueDate(BuildContext context) async {
    if (!_isAdmin || widget.isReadOnly) return;
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
      builder: (context, child) => Theme(
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
      ),
    );
    if (picked != null && picked != _dueDate) {
      setState(() => _dueDate = picked);
    }
  }

  void _handleSave() {
    if (_formKey.currentState!.validate()) {
      final updatedTask = widget.task.copyWith(
        title: (_isAdmin || _isCreator) ? _titleController.text : widget.task.title,
        description: (_isAdmin || _isCreator) ? _descriptionController.text : widget.task.description,
        status: _status,
        priority: _isAdmin ? _priority : widget.task.priority,
        dueDate: _isAdmin ? _dueDate : widget.task.dueDate,
        assignedTo: _isAdmin ? _assignedTo : widget.task.assignedTo,
        attachments: _isAdmin ? (_attachments.isNotEmpty ? _attachments : null) : widget.task.attachments,
        updatedAt: DateTime.now(),
        completed: _status == 'Done',
      );
      Navigator.pop(context, updatedTask);
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
        title: Text(widget.isReadOnly ? 'Chi tiết công việc' : 'Chỉnh sửa công việc'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
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
                      const Icon(Icons.edit, size: 40, color: Colors.blue),
                      const SizedBox(height: 10),
                      const Text(
                        'Chỉnh sửa công việc',
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
                        readOnly: !(_isAdmin || _isCreator) || widget.isReadOnly,
                        decoration: _inputDecoration(labelText: 'Tiêu đề'),
                        validator: (value) =>
                        (_isAdmin || _isCreator) && (value == null || value.isEmpty)
                            ? 'Vui lòng nhập tiêu đề'
                            : null,
                      ),
                      const SizedBox(height: 20),
                      _buildSectionTitle('Mô tả'),
                      TextFormField(
                        controller: _descriptionController,
                        readOnly: !(_isAdmin || _isCreator) || widget.isReadOnly,
                        maxLines: 3,
                        decoration: _inputDecoration(labelText: 'Mô tả'),
                      ),
                      const SizedBox(height: 20),
                      _buildSectionTitle('Trạng thái'),
                      DropdownButtonFormField<String>(
                        value: _status,
                        items: _statusOptions
                            .map((status) => DropdownMenuItem(
                          value: status,
                          child: Text(status),
                        ))
                            .toList(),
                        onChanged: widget.isReadOnly
                            ? null
                            : (value) => setState(() => _status = value!),
                        decoration: _inputDecoration(labelText: 'Trạng thái'),
                      ),
                      const SizedBox(height: 20),
                      _buildSectionTitle('Độ ưu tiên'),
                      DropdownButtonFormField<int>(
                        value: _priority,
                        items: _priorityOptions
                            .map((option) => DropdownMenuItem<int>(
                          value: option['value'] as int,
                          child: Text(option['label'] as String),
                        ))
                            .toList(),
                        onChanged: widget.isReadOnly || !(_isAdmin)
                            ? null
                            : (value) => setState(() => _priority = value!),
                        decoration: _inputDecoration(labelText: 'Độ ưu tiên'),
                      ),
                      if (_isAdmin && !widget.isReadOnly) ...[
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
                              ),
                            ),
                          ),
                        ),
                        if (_users.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          _buildSectionTitle('Gán cho người dùng'),
                          DropdownButtonFormField<String>(
                            value: _assignedTo,
                            decoration: _inputDecoration(labelText: 'Gán cho người dùng'),
                            items: [
                              const DropdownMenuItem<String>(
                                value: null,
                                child: Text('Không gán'),
                              ),
                              ..._users.map((user) => DropdownMenuItem<String>(
                                value: user.id,
                                child: Text(user.username),
                              )),
                            ],
                            onChanged: widget.isReadOnly
                                ? null
                                : (value) => setState(() => _assignedTo = value),
                          ),
                        ],
                        const SizedBox(height: 20),
                        _buildSectionTitle('Tệp đính kèm'),
                        OutlinedButton(
                          onPressed: _pickFiles,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.blue.shade600),
                            minimumSize: const Size(double.infinity, 50),
                          ),
                          child: Text(
                            'Chọn tệp đính kèm',
                            style: TextStyle(color: Colors.blue.shade600),
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
                                label: Text(path.split('/').last),
                                deleteIcon: const Icon(Icons.close, size: 18),
                                onDeleted: () => _removeAttachment(index),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                      if (!widget.isReadOnly) ...[
                        const SizedBox(height: 30),
                        ElevatedButton(
                          onPressed: _handleSave,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade600,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Lưu thay đổi'),
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: _handleCancel,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.grey.shade600,
                            minimumSize: const Size(double.infinity, 50),
                          ),
                          child: const Text('Hủy'),
                        ),
                      ],
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
  );

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}