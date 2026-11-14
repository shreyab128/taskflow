import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../tasks/data/task_service.dart';
import '../../../tasks/presentation/screens/task_form_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TaskService _taskService = TaskService();
  late Future<List<Map<String, dynamic>>> _tasksFuture;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  void _loadTasks() {
    _tasksFuture = _fetchTasks();
  }

  Future<List<Map<String, dynamic>>> _fetchTasks() async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Please sign in again.');

    final response = await _supabase
        .from('tasks')
        .select(
          'id, title, status, priority, due_date, '
          'is_recurring, recurrence_active, recurrence_series_id, '
          'recurrence_rule, category_id, project_id',
        )
        .eq('user_id', user.id)
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> _refreshTasks() async {
    setState(_loadTasks);
    await _tasksFuture;
  }

  Future<void> _addTask() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const TaskFormScreen()),
    );

    if (!mounted) return;
    if (saved == true) {
      setState(_loadTasks);
      _showMessage('Task added successfully!');
    }
  }

  Future<void> _toggleTask(Map<String, dynamic> task) async {
    try {
      await _taskService.toggleCompletion(task);

      if (!mounted) return;
      setState(_loadTasks);
    } catch (error) {
      if (!mounted) return;
      _showMessage('Could not update task: $error');
    }
  }

  Future<void> _deleteTask(Map<String, dynamic> task) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      await _supabase
          .from('tasks')
          .update({
            'deleted_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', task['id'])
          .eq('user_id', user.id);

      if (!mounted) return;
      setState(_loadTasks);
      _showMessage('Task deleted.');
    } catch (error) {
      if (!mounted) return;
      _showMessage('Could not delete task: $error');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _formatDate(dynamic value) {
    if (value == null) return 'No due date';
    final date = DateTime.tryParse(value.toString());
    if (date == null) return 'No due date';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final user = _supabase.auth.currentUser;
    final name = user?.userMetadata?['full_name'] as String? ?? 'there';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'TaskFlow',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => _supabase.auth.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addTask,
        icon: const Icon(Icons.add),
        label: const Text('Add task'),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshTasks,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _tasksFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 100),
                  const Icon(Icons.error_outline, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'Could not load tasks',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: FilledButton(
                      onPressed: _refreshTasks,
                      child: const Text('Try again'),
                    ),
                  ),
                ],
              );
            }

            final tasks = snapshot.data ?? [];
            final completed =
                tasks.where((task) => task['status'] == 'completed').length;
            final pending = tasks.length - completed;

            final today = DateTime.now();
            final todayKey =
                '${today.year.toString().padLeft(4, '0')}-'
                '${today.month.toString().padLeft(2, '0')}-'
                '${today.day.toString().padLeft(2, '0')}';

            final overdue = tasks.where((task) {
              final dueDate = task['due_date']?.toString();
              return task['status'] != 'completed' &&
                  dueDate != null &&
                  dueDate.length >= 10 &&
                  dueDate.substring(0, 10).compareTo(todayKey) < 0;
            }).length;

            final progress = tasks.isEmpty ? 0.0 : completed / tasks.length;
            final categorized = tasks.where((task) => task['category_id'] != null).length;
            final inProjects = tasks.where((task) => task['project_id'] != null).length;

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              children: [
                Text(
                  'Hello, $name!',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Here is your productivity overview.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),
                Text(
                  'Your overview',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 14),
                GridView.count(
                  crossAxisCount:
                      MediaQuery.of(context).size.width > 650 ? 4 : 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.65,
                  children: [
                    _SummaryCard(
                      title: 'Total tasks',
                      value: '${tasks.length}',
                      icon: Icons.checklist,
                      color: AppColors.primary,
                    ),
                    _SummaryCard(
                      title: 'Pending',
                      value: '$pending',
                      icon: Icons.pending_actions,
                      color: AppColors.warning,
                    ),
                    _SummaryCard(
                      title: 'Completed',
                      value: '$completed',
                      icon: Icons.task_alt,
                      color: AppColors.success,
                    ),
                    _SummaryCard(
                      title: 'Overdue',
                      value: '$overdue',
                      icon: Icons.warning_amber,
                      color: AppColors.danger,
                    ),
                    _SummaryCard(
                      title: 'Categorized',
                      value: '$categorized',
                      icon: Icons.category_outlined,
                      color: Colors.deepPurple,
                    ),
                    _SummaryCard(
                      title: 'In projects',
                      value: '$inProjects',
                      icon: Icons.folder_outlined,
                      color: Colors.blue,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Overall progress',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                          value: progress,
                          minHeight: 9,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        const SizedBox(height: 8),
                        Text('${(progress * 100).round()}% completed'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Recent tasks',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                if (tasks.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(28),
                      child: Column(
                        children: [
                          Icon(Icons.event_note, size: 48),
                          SizedBox(height: 12),
                          Text(
                            'No tasks yet. Add your first task!',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...tasks.take(20).map((task) {
                    final isCompleted = task['status'] == 'completed';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        onTap: () => _toggleTask(task),
                        leading: Icon(
                          isCompleted
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: isCompleted
                              ? AppColors.success
                              : AppColors.primary,
                          size: 28,
                        ),
                        title: Text(
                          task['title'] as String? ?? 'Untitled task',
                          style: TextStyle(
                            decoration: isCompleted
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                          ),
                        ),
                        subtitle: Text(
                          'Priority: ${task['priority'] ?? 'medium'}'
                          '  •  Due: ${_formatDate(task['due_date'])}',
                        ),
                        trailing: IconButton(
                          tooltip: 'Delete task',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _deleteTask(task),
                        ),
                      ),
                    );
                  }),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color, size: 25),
            Text(
              value,
              style: const TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
