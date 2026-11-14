
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../tasks/data/task_service.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final TaskService _service = TaskService();

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  List<Map<String, dynamic>> _tasks = [];
  bool _loading = true;

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load calendar tasks: $error')),
      );
    }
  }

  List<Map<String, dynamic>> _tasksForDay(DateTime day) {
    return _tasks.where((task) {
      final dueDate = task['due_date'];
      if (dueDate == null) return false;

      final date = DateTime.tryParse(dueDate.toString());
      if (date == null) return false;

      return date.year == day.year &&
          date.month == day.month &&
          date.day == day.day;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final selectedTasks = _tasksForDay(_selectedDay);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Calendar',
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
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: TableCalendar<Map<String, dynamic>>(
                        firstDay: DateTime.utc(2020, 1, 1),
                        lastDay: DateTime.utc(2100, 12, 31),
                        focusedDay: _focusedDay,
                        selectedDayPredicate: (day) =>
                            isSameDay(_selectedDay, day),
                        eventLoader: _tasksForDay,
                        calendarFormat: CalendarFormat.month,
                        startingDayOfWeek: StartingDayOfWeek.monday,
                        headerStyle: const HeaderStyle(
                          formatButtonVisible: true,
                          titleCentered: true,
                        ),
                        calendarStyle: const CalendarStyle(
                          todayDecoration: BoxDecoration(
                            color: Colors.indigo,
                            shape: BoxShape.circle,
                          ),
                          selectedDecoration: BoxDecoration(
                            color: Colors.deepPurple,
                            shape: BoxShape.circle,
                          ),
                          markerDecoration: BoxDecoration(
                            color: Colors.orange,
                            shape: BoxShape.circle,
                          ),
                        ),
                        onDaySelected: (selectedDay, focusedDay) {
                          setState(() {
                            _selectedDay = selectedDay;
                            _focusedDay = focusedDay;
                          });
                        },
                        onPageChanged: (focusedDay) {
                          _focusedDay = focusedDay;
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Tasks for ${_selectedDay.day}/${_selectedDay.month}/${_selectedDay.year}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  if (selectedTasks.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: Text('No tasks due on this day.'),
                        ),
                      ),
                    )
                  else
                    ...selectedTasks.map((task) {
                      final completed = task['status'] == 'completed';

                      return Card(
                        child: ListTile(
                          leading: Icon(
                            completed
                                ? Icons.check_circle
                                : Icons.task_alt,
                            color: completed ? Colors.green : Colors.indigo,
                          ),
                          title: Text(task['title']?.toString() ?? ''),
                          subtitle: Text(
                            'Priority: ${task['priority'] ?? 'medium'}',
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}
