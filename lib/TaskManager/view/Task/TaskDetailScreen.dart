import 'package:flutter/material.dart';
import 'package:taskmanager/TaskManager/model/Task.dart';
import 'package:taskmanager/TaskManager/db/UserDatabaseHelper.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';

class TaskDetailScreen extends StatefulWidget {
  final Task task;

  const TaskDetailScreen({Key? key, required this.task}) : super(key: key);

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  late Task task;
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm');
  String? assignedToUsername;
  String? createdByUsername;

  @override
  void initState() {
    super.initState();
    task = widget.task;
    _loadUserDetails();
  }

  Future<void> _loadUserDetails() async {
    try {
      // Fetch assigned user
      if (task.assignedTo != null) {
        final assignedUser = await UserDatabaseHelper.instance.getUserById(task.assignedTo!);
        setState(() {
          assignedToUsername = assignedUser?.username ?? 'Không xác định';
        });
      } else {
        setState(() {
          assignedToUsername = 'Không gán';
        });
      }

      // Fetch creator user
      final creatorUser = await UserDatabaseHelper.instance.getUserById(task.createdBy);
      setState(() {
        createdByUsername = creatorUser?.username ?? 'Không xác định';
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi tải thông tin người dùng: $e')),
      );
    }
  }

  void _updateStatus(String newStatus) {
    setState(() {
      task = task.copyWith(status: newStatus, updatedAt: DateTime.now());
    });
  }

  Widget _buildAttachments() {
    if (task.attachments == null || task.attachments!.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text('Không có tệp đính kèm.',
            style: TextStyle(color: Colors.grey)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: task.attachments!.map((attachment) {
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: attachment.toLowerCase().endsWith('.jpg') ||
                attachment.toLowerCase().endsWith('.png')
                ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => _openFile(attachment),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.file(
                      File(attachment),
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 200,
                          color: Colors.grey[200],
                          child: const Center(
                            child: Text('Không tải được ảnh',
                                style: TextStyle(color: Colors.grey)),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tệp đính kèm',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            )
                : InkWell(
              onTap: () => _openFile(attachment),
              child: Row(
                children: [
                  Icon(Icons.attach_file,
                      color: Theme.of(context).primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          attachment.split('/').last,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          'Tệp đính kèm',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _openFile(String filePath) async {
    final result = await OpenFile.open(filePath);
    if (result.type != ResultType.done) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể mở tệp: ${result.message}')),
      );
    }
  }

  Widget _buildInfoCard(String title, String content, {Widget? trailing}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    content,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết Công việc'),
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.blue.shade600,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoCard(
                'Tiêu đề',
                task.title,
              ),
              _buildInfoCard(
                'Mô tả',
                task.description.isNotEmpty ? task.description : 'Không có mô tả',
              ),
              _buildInfoCard(
                'Trạng thái',
                task.status,
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(task.status),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    task.status,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              _buildInfoCard(
                'Ưu tiên',
                _priorityText(task.priority),
              ),
              _buildInfoCard(
                'Ngày tới hạn',
                task.dueDate != null
                    ? DateFormat('dd/MM/yyyy').format(task.dueDate!)
                    : 'Chưa đặt ngày tới hạn',
              ),
              _buildInfoCard(
                'Ngày tạo',
                _dateFormat.format(task.createdAt),
              ),
              _buildInfoCard(
                'Ngày cập nhật',
                _dateFormat.format(task.updatedAt),
              ),
              _buildInfoCard(
                'Người được gán',
                assignedToUsername ?? 'Đang tải...',
              ),
              _buildInfoCard(
                'Người tạo',
                createdByUsername ?? 'Đang tải...',
              ),
              const SizedBox(height: 8),
              const Text(
                'Tệp đính kèm',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              _buildAttachments(),
              const SizedBox(height: 24),
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'To do':
        return Colors.blue;
      case 'In progress':
        return Colors.orange;
      case 'Done':
        return Colors.green;
      case 'Cancelled':
        return Colors.red;
      default:
        return Colors.grey;
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