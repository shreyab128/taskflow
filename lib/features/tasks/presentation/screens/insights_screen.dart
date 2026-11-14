
import 'package:flutter/material.dart';

import '../../data/task_service.dart';
import '../../data/task_analytics_service.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  final TaskService _taskService = TaskService();

  late Future<TaskAnalytics> _analyticsFuture;

  @override
  void initState() {
    super.initState();
    _analyticsFuture = _loadAnalytics();
  }

  Future<TaskAnalytics> _loadAnalytics() async {
    final tasks = await _taskService.getTasks();
    return TaskAnalytics.calculate(tasks);
  }

  Future<void> _refresh() async {
    setState(() {
      _analyticsFuture = _loadAnalytics();
    });
    await _analyticsFuture;
  }

  Widget _statCard(
    String label,
    int value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 12),
            Text(
              value.toString(),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(label),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Insights'),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh insights',
          ),
        ],
      ),
      body: FutureBuilder<TaskAnalytics>(
        future: _analyticsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not load insights: ${snapshot.error}'),
              ),
            );
          }

          final data = snapshot.data!;

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Your productivity',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),

                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.35,
                  children: [
                    _statCard(
                      'Total tasks',
                      data.total,
                      Icons.checklist,
                      Colors.indigo,
                    ),
                    _statCard(
                      'Completed',
                      data.completed,
                      Icons.task_alt,
                      Colors.green,
                    ),
                    _statCard(
                      'Pending',
                      data.pending,
                      Icons.pending_actions,
                      Colors.orange,
                    ),
                    _statCard(
                      'Overdue',
                      data.overdue,
                      Icons.warning_amber,
                      Colors.red,
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Completion rate',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                          value: data.completionRate,
                          minHeight: 10,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${(data.completionRate * 100).toStringAsFixed(1)}% completed',
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.local_fire_department,
                      color: Colors.deepOrange,
                      size: 36,
                    ),
                    title: Text(
                      '${data.streak} day${data.streak == 1 ? '' : 's'}',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    subtitle: const Text(
                      'Current task completion streak',
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                const Text(
                  'Your streak counts consecutive calendar days '
                  'on which at least one task was completed.',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
