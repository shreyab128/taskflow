import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/notification_service.dart';

class TaskService {
  final SupabaseClient _client = Supabase.instance.client;
  static const _uuid = Uuid();

  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('You are not signed in.');
    return user.id;
  }

  String get _cacheKey => 'taskflow_tasks_$_userId';
  String get _queueKey => 'taskflow_sync_queue_$_userId';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<List<Map<String, dynamic>>> _readCache() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_cacheKey);
    if (raw == null) return [];
    final decoded = jsonDecode(raw) as List;
    return decoded
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<void> _writeCache(List<Map<String, dynamic>> tasks) async {
    final prefs = await _prefs;
    await prefs.setString(_cacheKey, jsonEncode(tasks));
  }

  Future<List<Map<String, dynamic>>> getTasks() async {
    try {
      await syncPendingChanges();
      final response = await _client
          .from('tasks')
          .select()
          .eq('user_id', _userId)
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false);

      final tasks = List<Map<String, dynamic>>.from(response);
      await _writeCache(tasks);
      return tasks;
    } catch (_) {
      return _readCache();
    }
  }

  Future<void> _saveLocallyAndQueue(Map<String, dynamic> task) async {
    final tasks = await _readCache();
    final index = tasks.indexWhere((item) => item['id'] == task['id']);

    if (task['deleted_at'] != null) {
      if (index != -1) tasks.removeAt(index);
    } else if (index == -1) {
      tasks.insert(0, task);
    } else {
      tasks[index] = task;
    }

    await _writeCache(tasks);

    final prefs = await _prefs;
    final queue = _readQueueFrom(prefs);
    queue.add({'operation': 'upsert_task', 'payload': task});
    await prefs.setString(_queueKey, jsonEncode(queue));

    try {
      await syncPendingChanges();
    } catch (_) {
      // Keep the queued operation for the next sync attempt.
    }
  }

  List<Map<String, dynamic>> _readQueueFrom(SharedPreferences prefs) {
    final raw = prefs.getString(_queueKey);
    if (raw == null) return [];
    final decoded = jsonDecode(raw) as List;
    return decoded
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<void> syncPendingChanges() async {
    final prefs = await _prefs;
    final queue = _readQueueFrom(prefs);
    if (queue.isEmpty) return;

    final remaining = <Map<String, dynamic>>[];

    for (var i = 0; i < queue.length; i++) {
      final operation = queue[i];
      try {
        final type = operation['operation']?.toString();

        if (type == 'stop_series') {
          final seriesId = operation['series_id'].toString();
          await _client
              .from('tasks')
              .update({
                'recurrence_active': false,
                'updated_at': DateTime.now().toUtc().toIso8601String(),
              })
              .eq('user_id', _userId)
              .eq('recurrence_series_id', seriesId);
        } else {
          final payload =
              Map<String, dynamic>.from(operation['payload'] as Map);
          await _client.from('tasks').upsert(payload);
        }
      } catch (_) {
        remaining.addAll(queue.skip(i));
        break;
      }
    }

    await prefs.setString(_queueKey, jsonEncode(remaining));
  }

  Future<void> createTask({
    required String title,
    String? description,
    required String priority,
    String status = 'todo',
    DateTime? dueDate,
    DateTime? reminderAt,
    bool isRecurring = false,
    String? recurrenceFrequency,
    String? recurrenceSeriesId,
    String? categoryId,
    String? projectId,
  }) async {
    final now = DateTime.now().toUtc();
    final seriesId =
        isRecurring ? (recurrenceSeriesId ?? _uuid.v4()) : null;

    final task = <String, dynamic>{
      'id': _uuid.v4(),
      'user_id': _userId,
      'title': title.trim(),
      'description': description?.trim(),
      'priority': priority,
      'status': status,
      'due_date': _dateOnly(dueDate),
      'reminder_at': reminderAt?.toUtc().toIso8601String(),
      'is_recurring': isRecurring,
      'recurrence_rule': isRecurring
          ? {'frequency': recurrenceFrequency ?? 'daily', 'interval': 1}
          : null,
      'recurrence_series_id': seriesId,
      'recurrence_active': isRecurring,
      'completed_at':
          status == 'completed' ? now.toIso8601String() : null,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
      'deleted_at': null,
      'category_id': categoryId,
      'project_id': projectId,
    };

    await _saveLocallyAndQueue(task);

    if (reminderAt != null) {
      await NotificationService.schedule(
        taskId: task['id'] as String,
        title: title.trim(),
        body: description,
        reminderAt: reminderAt,
      );
    }
  }

  Future<void> updateTask({
    required String id,
    required String title,
    String? description,
    required String priority,
    required String status,
    DateTime? dueDate,
    DateTime? reminderAt,
    bool isRecurring = false,
    String? recurrenceFrequency,
    String? categoryId,
    String? projectId,
  }) async {
    final tasks = await _readCache();
    final index = tasks.indexWhere((task) => task['id'] == id);

    Map<String, dynamic> task;
    if (index != -1) {
      task = Map<String, dynamic>.from(tasks[index]);
    } else {
      task = Map<String, dynamic>.from(
        await _client
            .from('tasks')
            .select()
            .eq('id', id)
            .eq('user_id', _userId)
            .single(),
      );
    }

    final existingSeriesId = task['recurrence_series_id']?.toString();
    final seriesId = isRecurring
        ? (existingSeriesId ?? _uuid.v4())
        : existingSeriesId;

    task.addAll({
      'title': title.trim(),
      'description': description?.trim(),
      'priority': priority,
      'status': status,
      'due_date': _dateOnly(dueDate),
      'reminder_at': reminderAt?.toUtc().toIso8601String(),
      'is_recurring': isRecurring,
      'recurrence_rule': isRecurring
          ? {'frequency': recurrenceFrequency ?? 'daily', 'interval': 1}
          : null,
      'recurrence_series_id': seriesId,
      'recurrence_active': isRecurring
          ? (task['recurrence_active'] as bool? ?? true)
          : false,
      'completed_at': status == 'completed'
          ? DateTime.now().toUtc().toIso8601String()
          : null,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'category_id': categoryId,
      'project_id': projectId,
    });

    await _saveLocallyAndQueue(task);
    await NotificationService.cancel(id);

    if (reminderAt != null && status != 'completed') {
      await NotificationService.schedule(
        taskId: id,
        title: title.trim(),
        body: description,
        reminderAt: reminderAt,
      );
    }
  }

  Future<void> toggleCompletion(Map<String, dynamic> original) async {
    final task = Map<String, dynamic>.from(original);
    final id = task['id'].toString();

    if (task['status'] == 'completed') {
      task['status'] = 'todo';
      task['completed_at'] = null;
      task['updated_at'] = DateTime.now().toUtc().toIso8601String();
      await _saveLocallyAndQueue(task);
      return;
    }

    task['status'] = 'completed';
    task['completed_at'] = DateTime.now().toUtc().toIso8601String();
    task['updated_at'] = task['completed_at'];

    await _saveLocallyAndQueue(task);
    await NotificationService.cancel(id);

    if (task['is_recurring'] == true &&
        task['recurrence_active'] != false &&
        task['recurrence_series_id'] != null) {
      await _createNextOccurrence(task);
    }
  }

  Future<void> _createNextOccurrence(Map<String, dynamic> task) async {
    final rule = task['recurrence_rule'];
    if (rule is! Map) return;

    final seriesId = task['recurrence_series_id']?.toString();
    if (seriesId == null || task['recurrence_active'] == false) return;

    // Recheck the latest cached copy so a stopped series cannot spawn again
    // from a stale task object.
    final cached = await _readCache();
    final latest = cached.where((item) => item['id'] == task['id']);
    if (latest.isNotEmpty && latest.first['recurrence_active'] == false) {
      return;
    }

    final frequency = rule['frequency']?.toString() ?? 'daily';
    final interval = (rule['interval'] as num?)?.toInt() ?? 1;
    final currentDate =
        DateTime.tryParse(task['due_date']?.toString() ?? '') ??
            DateTime.now();
    final nextDate = _nextDate(currentDate, frequency, interval);

    await createTask(
      title: task['title'].toString(),
      description: task['description']?.toString(),
      priority: task['priority']?.toString() ?? 'medium',
      dueDate: nextDate,
      reminderAt: null,
      isRecurring: true,
      recurrenceFrequency: frequency,
      recurrenceSeriesId: seriesId,
      categoryId: task['category_id']?.toString(),
      projectId: task['project_id']?.toString(),
    );
  }

  Future<void> stopRecurringSeries(String seriesId) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final tasks = await _readCache();

    final updatedTasks = tasks.map((task) {
      if (task['recurrence_series_id']?.toString() == seriesId) {
        return {
          ...task,
          'recurrence_active': false,
          'updated_at': now,
        };
      }
      return task;
    }).toList();

    await _writeCache(updatedTasks);

    final prefs = await _prefs;
    final queue = _readQueueFrom(prefs);
    queue.add({'operation': 'stop_series', 'series_id': seriesId});
    await prefs.setString(_queueKey, jsonEncode(queue));

    try {
      await syncPendingChanges();
    } catch (_) {
      // The local stop is retained and synced later.
    }

    // Cancel reminders for cached future occurrences in this series.
    for (final task in updatedTasks) {
      if (task['recurrence_series_id']?.toString() == seriesId &&
          task['status'] != 'completed' &&
          task['id'] != null) {
        await NotificationService.cancel(task['id'].toString());
      }
    }
  }

  DateTime _nextDate(DateTime date, String frequency, int interval) {
    switch (frequency) {
      case 'weekly':
        return date.add(Duration(days: 7 * interval));
      case 'monthly':
        final month = date.month - 1 + interval;
        final year = date.year + month ~/ 12;
        final newMonth = month % 12 + 1;
        final lastDay = DateTime(year, newMonth + 1, 0).day;
        return DateTime(
          year,
          newMonth,
          date.day > lastDay ? lastDay : date.day,
        );
      default:
        return date.add(Duration(days: interval));
    }
  }

  String? _dateOnly(DateTime? date) {
    if (date == null) return null;
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> deleteTask(String id) async {
    final tasks = await _readCache();
    final index = tasks.indexWhere((task) => task['id'] == id);

    Map<String, dynamic> task;
    if (index != -1) {
      task = Map<String, dynamic>.from(tasks[index]);
    } else {
      task = Map<String, dynamic>.from(
        await _client
            .from('tasks')
            .select()
            .eq('id', id)
            .eq('user_id', _userId)
            .single(),
      );
    }

    task['deleted_at'] = DateTime.now().toUtc().toIso8601String();
    task['updated_at'] = task['deleted_at'];
    await _saveLocallyAndQueue(task);
    await NotificationService.cancel(id);
  }

  @visibleForTesting
  Future<int> pendingSyncCount() async {
    final prefs = await _prefs;
    return _readQueueFrom(prefs).length;
  }
}
