import 'package:flutter/material.dart';

import '../../data/task_service.dart';
import '../../../projects/data/project_service.dart';

class TaskFormScreen extends StatefulWidget {
  final Map<String, dynamic>? task;

  const TaskFormScreen({super.key, this.task});

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = TaskService();
  final _projectService = ProjectService();
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _projects = [];
  String? _categoryId;
  String? _projectId;

  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;

  String _priority = 'medium';
  String _status = 'todo';
  bool _isRecurring = false;
  String _frequency = 'daily';
  DateTime? _dueDate;
  DateTime? _reminderAt;
  bool _saving = false;
  bool _stoppingSeries = false;

  bool get _isEditing => widget.task != null;
  String? get _seriesId =>
      widget.task?['recurrence_series_id']?.toString();

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    _categoryId = task?['category_id']?.toString();
    _projectId = task?['project_id']?.toString();
    _loadOrganizers();

    _titleController =
        TextEditingController(text: task?['title']?.toString() ?? '');
    _descriptionController =
        TextEditingController(text: task?['description']?.toString() ?? '');

    if (task != null) {
      _priority = task['priority']?.toString() ?? 'medium';
      _status = task['status']?.toString() ?? 'todo';
      _dueDate = DateTime.tryParse(task['due_date']?.toString() ?? '');
      final reminder = task['reminder_at']?.toString();
      _reminderAt = reminder == null
          ? null
          : DateTime.tryParse(reminder)?.toLocal();
      _isRecurring = task['is_recurring'] == true &&
          task['recurrence_active'] != false;

      final rule = task['recurrence_rule'];
      if (rule is Map) {
        _frequency = rule['frequency']?.toString() ?? 'daily';
      }
    }
  }

  Future<void> _loadOrganizers() async {
    try {
      final values = await Future.wait([
        _projectService.getCategories(),
        _projectService.getProjects(),
      ]);
      if (!mounted) return;
      setState(() {
        _categories = values[0];
        _projects = values[1].where((p) => p['archived_at'] == null).toList();
        if (_categoryId != null && !_categories.any((c) => c['id'].toString() == _categoryId)) _categoryId = null;
        if (_projectId != null && !_projects.any((p) => p['id'].toString() == _projectId)) _projectId = null;
      });
    } catch (_) {
      // Task entry remains usable when the optional organizer lists are unavailable.
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _chooseDueDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (selected != null) setState(() => _dueDate = selected);
  }

  Future<void> _chooseReminder() async {
    final now = DateTime.now();
    final initial = _reminderAt ?? now.add(const Duration(hours: 1));

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(2100),
    );
    if (selectedDate == null || !mounted) return;

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (selectedTime == null) return;

    final reminder = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );

    if (!reminder.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please choose a reminder time in the future.'),
        ),
      );
      return;
    }

    setState(() => _reminderAt = reminder);
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _formatDateTime(DateTime date) {
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '${_formatDate(date)} at $hour:$minute $period';
  }

  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final title = _titleController.text.trim();
      final description = _descriptionController.text.trim();

      if (_isEditing) {
        await _service.updateTask(
          id: widget.task!['id'].toString(),
          title: title,
          description: description.isEmpty ? null : description,
          priority: _priority,
          status: _status,
          dueDate: _dueDate,
          reminderAt: _reminderAt,
          isRecurring: _isRecurring,
          recurrenceFrequency: _frequency,
          categoryId: _categoryId,
          projectId: _projectId,
        );
      } else {
        await _service.createTask(
          title: title,
          description: description.isEmpty ? null : description,
          priority: _priority,
          status: _status,
          dueDate: _dueDate,
          reminderAt: _reminderAt,
          isRecurring: _isRecurring,
          recurrenceFrequency: _frequency,
          categoryId: _categoryId,
          projectId: _projectId,
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save task: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _stopSeries() async {
    final seriesId = _seriesId;
    if (seriesId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This older recurring task has no series link. '
            'Please run the database migration and save it again.',
          ),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Stop recurring series?'),
        content: const Text(
          'This stops future occurrences for the entire series. '
          'Existing tasks and completed history will remain.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep active'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Stop series'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _stoppingSeries = true);
    try {
      await _service.stopRecurringSeries(seriesId);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not stop series: $error')),
      );
    } finally {
      if (mounted) setState(() => _stoppingSeries = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasActiveSeries = _isEditing &&
        widget.task?['is_recurring'] == true &&
        widget.task?['recurrence_active'] != false;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Task' : 'Add Task'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Task title',
                  hintText: 'What do you need to do?',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a task title.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String?>(
                initialValue: _categoryId,
                decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('Uncategorized')),
                  ..._categories.map((c) => DropdownMenuItem<String?>(value: c['id'].toString(), child: Text(c['name']?.toString() ?? 'Category'))),
                ],
                onChanged: (value) => setState(() => _categoryId = value),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String?>(
                initialValue: _projectId,
                decoration: const InputDecoration(labelText: 'Project (optional)', border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('No project')),
                  ..._projects.map((p) => DropdownMenuItem<String?>(value: p['id'].toString(), child: Text(p['name']?.toString() ?? 'Project'))),
                ],
                onChanged: (value) => setState(() => _projectId = value),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                initialValue: _priority,
                decoration: const InputDecoration(
                  labelText: 'Priority',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'low', child: Text('Low')),
                  DropdownMenuItem(value: 'medium', child: Text('Medium')),
                  DropdownMenuItem(value: 'high', child: Text('High')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _priority = value);
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'todo', child: Text('To Do')),
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
                  if (value != null) setState(() => _status = value);
                },
              ),
              const SizedBox(height: 20),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_month),
                title: const Text('Due date'),
                subtitle: Text(
                  _dueDate == null
                      ? 'No due date selected'
                      : _formatDate(_dueDate!),
                ),
                trailing: TextButton(
                  onPressed: _chooseDueDate,
                  child: const Text('Choose'),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.notifications_active_outlined),
                title: const Text('Reminder'),
                subtitle: Text(
                  _reminderAt == null
                      ? 'No reminder set'
                      : _formatDateTime(_reminderAt!),
                ),
                trailing: TextButton(
                  onPressed: _chooseReminder,
                  child: const Text('Choose'),
                ),
              ),
              if (_reminderAt != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _reminderAt = null),
                    icon: const Icon(Icons.clear),
                    label: const Text('Remove reminder'),
                  ),
                ),
              const Divider(height: 32),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Recurring task'),
                subtitle: const Text(
                  'Automatically create the next task when completed',
                ),
                value: _isRecurring,
                onChanged: (value) => setState(() => _isRecurring = value),
              ),
              if (_isRecurring) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _frequency,
                  decoration: const InputDecoration(
                    labelText: 'Repeat frequency',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'daily', child: Text('Daily')),
                    DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                    DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _frequency = value);
                  },
                ),
              ],
              if (hasActiveSeries) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _stoppingSeries ? null : _stopSeries,
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: Text(
                    _stoppingSeries
                        ? 'Stopping series...'
                        : 'Stop entire series',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 28),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _saving ? null : _saveTask,
                  child: _saving
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_isEditing ? 'Save Changes' : 'Create Task'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
