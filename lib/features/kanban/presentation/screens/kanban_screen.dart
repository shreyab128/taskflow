
import 'package:flutter/material.dart';

import '../../../tasks/data/task_service.dart';

class KanbanScreen extends StatefulWidget {
  const KanbanScreen({super.key});

  @override
  State<KanbanScreen> createState() => _KanbanScreenState();
}

class _KanbanScreenState extends State<KanbanScreen> {
  final TaskService _service = TaskService();

  List<Map<String, dynamic>> _tasks = [];
  bool _loading = true;

  final List<Map<String, String>> _columns = [
    {'title': 'To Do', 'status': 'todo'},
    {'title': 'In Progress', 'status': 'in_progress'},
    {'title': 'Completed', 'status': 'completed'},
  ];

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    try {
      final result = await _service.getTasks();
      if (!mounted) return;
      setState(() {
        _tasks = result;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _message('Could not load tasks: $error');
    }
  }

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value)),
    );
  }

  Future<void> _changeStatus(
    Map<String, dynamic> task,
    String status,
  ) async {
    try {
      await _service.updateTask(
        id: task['id'].toString(),
        title: task['title'].toString(),
        description: task['description']?.toString(),
        priority: task['priority']?.toString() ?? 'medium',
        status: status,
        dueDate: task['due_date'] == null
            ? null
            : DateTime.tryParse(task['due_date'].toString()),
      );

      await _loadTasks();
    } catch (error) {
      _message('Could not move task: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Kanban Board',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: _loadTasks,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadTasks,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(12),
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _columns.map((column) {
                    final status = column['status']!;
                    final columnTasks = _tasks
                        .where((task) => task['status'] == status)
                        .toList();

                    return Container(
                      width: 290,
                      margin: const EdgeInsets.only(right: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .secondaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    column['title']!,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                CircleAvatar(
                                  radius: 13,
                                  child: Text('${columnTasks.length}'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: SizedBox(
                              width: 290,
                              child: ListView(
                                children: columnTasks.map((task) {
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            task['title']?.toString() ?? '',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Priority: ${task['priority'] ?? 'medium'}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          DropdownButtonFormField<String>(
                                            value: status,
                                            isExpanded: true,
                                            decoration: const InputDecoration(
                                              labelText: 'Move to',
                                              isDense: true,
                                            ),
                                            items: _columns.map((item) {
                                              return DropdownMenuItem(
                                                value: item['status'],
                                                child: Text(item['title']!),
                                              );
                                            }).toList(),
                                            onChanged: (value) {
                                              if (value != null &&
                                                  value != status) {
                                                _changeStatus(task, value);
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
    );
  }
}
