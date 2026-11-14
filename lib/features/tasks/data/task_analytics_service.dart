
class TaskAnalytics {
  final int total;
  final int completed;
  final int pending;
  final int overdue;
  final int streak;
  final double completionRate;

  const TaskAnalytics({
    required this.total,
    required this.completed,
    required this.pending,
    required this.overdue,
    required this.streak,
    required this.completionRate,
  });

  factory TaskAnalytics.calculate(List<Map<String, dynamic>> tasks) {
    final activeTasks = tasks.where(
      (task) => task['deleted_at'] == null,
    ).toList();

    final completedTasks = activeTasks.where(
      (task) => task['status'] == 'completed',
    ).toList();

    final pendingTasks = activeTasks.where(
      (task) => task['status'] != 'completed',
    ).toList();

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    final overdueTasks = pendingTasks.where((task) {
      final due = DateTime.tryParse(task['due_date']?.toString() ?? '');
      if (due == null) return false;

      final dueDate = DateTime(due.year, due.month, due.day);
      return dueDate.isBefore(todayDate);
    }).length;

    final completedDates = <DateTime>{};

    for (final task in completedTasks) {
      final completedAt = DateTime.tryParse(
        task['completed_at']?.toString() ?? '',
      );

      if (completedAt != null) {
        completedDates.add(
          DateTime(
            completedAt.toLocal().year,
            completedAt.toLocal().month,
            completedAt.toLocal().day,
          ),
        );
      }
    }

    var streak = 0;
    var checkDate = todayDate;

    // A streak can continue if the most recent completion was yesterday.
    if (!completedDates.contains(checkDate)) {
      checkDate = todayDate.subtract(const Duration(days: 1));
    }

    while (completedDates.contains(checkDate)) {
      streak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    final total = activeTasks.length;
    final completed = completedTasks.length;

    return TaskAnalytics(
      total: total,
      completed: completed,
      pending: pendingTasks.length,
      overdue: overdueTasks,
      streak: streak,
      completionRate: total == 0 ? 0 : completed / total,
    );
  }
}
