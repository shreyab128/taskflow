
import 'package:supabase_flutter/supabase_flutter.dart';

class ProjectService {
  final SupabaseClient _client = Supabase.instance.client;

  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Please sign in again.');
    return user.id;
  }

  Future<List<Map<String, dynamic>>> getProjects() async {
    final response = await _client
        .from('projects')
        .select()
        .eq('user_id', _userId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> getTaskLinks() async {
    final response = await _client
        .from('tasks')
        .select('id, project_id, category_id, status')
        .eq('user_id', _userId)
        .isFilter('deleted_at', null);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> createProject({
    required String name,
    String? description,
    DateTime? deadline,
    String status = 'not_started',
  }) async {
    await _client.from('projects').insert({
      'user_id': _userId,
      'name': name.trim(),
      'description': description?.trim(),
      'deadline': deadline?.toIso8601String().split('T').first,
      'status': status,
    });
  }

  Future<void> updateProject({
    required String id,
    required String name,
    String? description,
    DateTime? deadline,
    required String status,
  }) async {
    await _client
        .from('projects')
        .update({
          'name': name.trim(),
          'description': description?.trim(),
          'deadline': deadline?.toIso8601String().split('T').first,
          'status': status,
        })
        .eq('id', id)
        .eq('user_id', _userId);
  }

  Future<void> deleteProject(String id) async {
    await _client.from('tasks').update({'project_id': null})
        .eq('project_id', id).eq('user_id', _userId);
    await _client
        .from('projects')
        .delete()
        .eq('id', id)
        .eq('user_id', _userId);
  }

  Future<void> setProjectArchived(String id, bool archived) async {
    await _client.from('projects').update({
      'archived_at': archived ? DateTime.now().toUtc().toIso8601String() : null,
    }).eq('id', id).eq('user_id', _userId);
  }

  Future<List<Map<String, dynamic>>> getCategories() async {
    final response = await _client
        .from('categories')
        .select()
        .eq('user_id', _userId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> createCategory(String name, {String color = '#6750A4'}) async {
    await _client.from('categories').insert({
      'user_id': _userId,
      'name': name.trim(),
      'color': color,
    });
  }

  Future<void> updateCategory({
    required String id,
    required String name,
    required String color,
  }) async {
    await _client
        .from('categories')
        .update({'name': name.trim(), 'color': color})
        .eq('id', id)
        .eq('user_id', _userId);
  }

  Future<void> deleteCategory(String id) async {
    await _client.from('tasks').update({'category_id': null})
        .eq('category_id', id).eq('user_id', _userId);
    await _client
        .from('categories')
        .delete()
        .eq('id', id)
        .eq('user_id', _userId);
  }
}
