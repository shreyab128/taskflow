
import 'package:flutter/material.dart';

import '../../data/task_service.dart';
import '../../../projects/data/project_service.dart';
import 'task_form_screen.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final TaskService _service = TaskService();
  final _projectService = ProjectService();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _tasks = [];
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _projects = [];
  bool _loading = true;

  String _statusFilter = 'all';
  String _priorityFilter = 'all';
  String _categoryFilter = 'all';
  String _projectFilter = 'all';
  bool _overdueOnly = false;

  @override
  void initState() {
    super.initState();
    _loadTasks();
    _loadOrganizerOptions();
  }

  Future<void> _loadOrganizerOptions() async {
    try {
      final lists = await Future.wait([_projectService.getCategories(), _projectService.getProjects()]);
      if (!mounted) return;
      setState(() {
        _categories = lists[0];
        _projects = lists[1].where((p) => p['archived_at'] == null).toList();
        if (_categoryFilter != 'all' && _categoryFilter != 'none' && !_categories.any((c) => c['id'].toString() == _categoryFilter)) _categoryFilter = 'all';
        if (_projectFilter != 'all' && _projectFilter != 'none' && !_projects.any((p) => p['id'].toString() == _projectFilter)) _projectFilter = 'all';
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    try {
      final tasks = await _service.getTasks();
      if (!mounted) return;

      setState(() {
        _tasks = tasks;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load tasks: $error')),
      );
    }
  }

  List<Map<String, dynamic>> get _filteredTasks {
    final query = _searchController.text.trim().toLowerCase();
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    return _tasks.where((task) {
      final title = task['title']?.toString().toLowerCase() ?? '';
      final description =
          task['description']?.toString().toLowerCase() ?? '';

      final matchesSearch =
          query.isEmpty || title.contains(query) || description.contains(query);

      final matchesStatus = _statusFilter == 'all' ||
          task['status']?.toString() == _statusFilter;

      final matchesPriority = _priorityFilter == 'all' ||
          task['priority']?.toString() == _priorityFilter;
      final matchesCategory = _categoryFilter == 'all' ||
          (_categoryFilter == 'none' ? task['category_id'] == null : task['category_id']?.toString() == _categoryFilter);
      final matchesProject = _projectFilter == 'all' ||
          (_projectFilter == 'none' ? task['project_id'] == null : task['project_id']?.toString() == _projectFilter);

      final dueDate =
          DateTime.tryParse(task['due_date']?.toString() ?? '');

      final isOverdue = dueDate != null &&
          DateTime(dueDate.year, dueDate.month, dueDate.day)
              .isBefore(todayDate) &&
          task['status'] != 'completed';

      final matchesOverdue = !_overdueOnly || isOverdue;

      return matchesSearch &&
          matchesStatus &&
          matchesPriority &&
          matchesCategory &&
          matchesProject &&
          matchesOverdue;
    }).toList();
  }

  Future<void> _openForm({Map<String, dynamic>? task}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TaskFormScreen(task: task),
      ),
    );

    if (result == true) await _loadTasks();
  }

  Future<void> _toggleTask(Map<String, dynamic> task) async {
    try {
      await _service.toggleCompletion(task);
      await _loadTasks();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update task: $error')),
      );
    }
  }

  Future<void> _deleteTask(Map<String, dynamic> task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete task?'),
        content: Text('Delete "${task['title']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _service.deleteTask(task['id'].toString());
      await _loadTasks();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete task: $error')),
      );
    }
  }

  String _dueLabel(Map<String, dynamic> task) {
    final raw = task['due_date']?.toString();
    if (raw == null) return 'No due date';

    final date = DateTime.tryParse(raw);
    if (date == null) return 'No due date';

    return 'Due ${date.day}/${date.month}/${date.year}';
  }

  Color _priorityColor(String? priority) {
    switch (priority) {
      case 'high':
        return Colors.red;
      case 'low':
        return Colors.green;
      default:
        return Colors.orange;
    }
  }

  Widget _filterDropdown({
    required String label,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Expanded(
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
        ),
        items: items,
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleTasks = _filteredTasks;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Tasks'),
        actions: [
          IconButton(
            onPressed: _loadTasks,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh tasks',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Add task'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadTasks,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search tasks...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                              icon: const Icon(Icons.clear),
                            ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      _filterDropdown(
                        label: 'Status',
                        value: _statusFilter,
                        items: const [
                          DropdownMenuItem(
                            value: 'all',
                            child: Text('All statuses'),
                          ),
                          DropdownMenuItem(
                            value: 'todo',
                            child: Text('To Do'),
                          ),
                          DropdownMenuItem(
                            value: 'in_progress',
                            child: Text('In Progress'),
                          ),
                          DropdownMenuItem(
                            value: 'completed',
                            child: Text('Completed'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _statusFilter = value);
                          }
                        },
                      ),
                      const SizedBox(width: 10),
                      _filterDropdown(
                        label: 'Priority',
                        value: _priorityFilter,
                        items: const [
                          DropdownMenuItem(
                            value: 'all',
                            child: Text('All priorities'),
                          ),
                          DropdownMenuItem(
                            value: 'high',
                            child: Text('High'),
                          ),
                          DropdownMenuItem(
                            value: 'medium',
                            child: Text('Medium'),
                          ),
                          DropdownMenuItem(
                            value: 'low',
                            child: Text('Low'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _priorityFilter = value);
                          }
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),
                  Row(children: [
                    _filterDropdown(label: 'Category', value: _categoryFilter,
                      items: [const DropdownMenuItem(value: 'all', child: Text('All categories')), const DropdownMenuItem(value: 'none', child: Text('Uncategorized')),
                        ..._categories.map((c) => DropdownMenuItem(value: c['id'].toString(), child: Text(c['name']?.toString() ?? 'Category', overflow: TextOverflow.ellipsis)))],
                      onChanged: (v) { if (v != null) setState(() => _categoryFilter = v); }),
                    const SizedBox(width: 10),
                    _filterDropdown(label: 'Project', value: _projectFilter,
                      items: [const DropdownMenuItem(value: 'all', child: Text('All projects')), const DropdownMenuItem(value: 'none', child: Text('No project')),
                        ..._projects.map((p) => DropdownMenuItem(value: p['id'].toString(), child: Text(p['name']?.toString() ?? 'Project', overflow: TextOverflow.ellipsis)))],
                      onChanged: (v) { if (v != null) setState(() => _projectFilter = v); }),
                  ]),

                  const SizedBox(height: 8),

                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Overdue tasks only'),
                    value: _overdueOnly,
                    onChanged: (value) {
                      setState(() => _overdueOnly = value);
                    },
                  ),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${visibleTasks.length} task(s)',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      TextButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _statusFilter = 'all';
                            _priorityFilter = 'all';
                            _categoryFilter = 'all';
                            _projectFilter = 'all';
                            _overdueOnly = false;
                          });
                        },
                        child: const Text('Clear filters'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  if (visibleTasks.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 60),
                      child: Column(
                        children: [
                          Icon(
                            Icons.inbox_outlined,
                            size: 56,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 12),
                          Text('No tasks match these filters.'),
                        ],
                      ),
                    )
                  else
                    ...visibleTasks.map((task) {
                      final completed = task['status'] == 'completed';
                      final priority = task['priority']?.toString();

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: Checkbox(
                            value: completed,
                            onChanged: (_) => _toggleTask(task),
                          ),
                          title: Text(
                            task['title']?.toString() ?? 'Untitled task',
                            style: TextStyle(
                              decoration: completed
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if ((task['description'] ?? '')
                                  .toString()
                                  .isNotEmpty)
                                Text(task['description'].toString()),
                              const SizedBox(height: 5),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  Text(
                                    _dueLabel(task),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  if (task['category_id'] != null)
                                    _organizerChip(_categories, task['category_id'], 'category'),
                                  if (task['project_id'] != null)
                                    _organizerChip(_projects, task['project_id'], 'project'),
                                  Text(
                                    (priority ?? 'medium').toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _priorityColor(priority),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (task['is_recurring'] == true)
                                    const Text(
                                      'RECURRING',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.indigo,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          isThreeLine: true,
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') {
                                _openForm(task: task);
                              } else if (value == 'delete') {
                                _deleteTask(task);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'edit',
                                child: Text('Edit'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }

  Widget _organizerChip(List<Map<String, dynamic>> values, dynamic id, String kind) {
    final match = values.where((v) => v['id'].toString() == id.toString()).firstOrNull;
    if (match == null) return const SizedBox.shrink();
    final name = match['name']?.toString() ?? kind;
    if (kind == 'project') return Chip(visualDensity: VisualDensity.compact, label: Text(name, style: const TextStyle(fontSize: 11)));
    final raw = match['color']?.toString() ?? '#6750A4';
    final value = int.tryParse(raw.replaceFirst('#', ''), radix: 16) ?? 0xFF6750A4;
    final color = Color(value <= 0xFFFFFF ? value | 0xFF000000 : value);
    return Chip(visualDensity: VisualDensity.compact, avatar: CircleAvatar(backgroundColor: color, radius: 7), label: Text(name, style: const TextStyle(fontSize: 11)));
  }
}
