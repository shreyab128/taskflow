import 'package:flutter/material.dart';

import '../../data/project_service.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});
  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  final _service = ProjectService();
  List<Map<String, dynamic>> _projects = [];
  List<Map<String, dynamic>> _tasks = [];
  bool _loading = true;
  bool _showArchived = false;
  static const _statuses = {'not_started': 'Not Started', 'active': 'Active', 'on_hold': 'On Hold', 'completed': 'Completed'};

  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final values = await Future.wait([_service.getProjects(), _service.getTaskLinks()]);
      if (!mounted) return;
      setState(() { _projects = values[0]; _tasks = values[1]; _loading = false; });
    } catch (e) { if (!mounted) return; setState(() => _loading = false); _message('Could not load projects: $e'); }
  }
  void _message(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  Future<DateTime?> _pickDate(DateTime? initial) => showDatePicker(context: context, initialDate: initial ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100));

  Future<void> _edit({Map<String, dynamic>? project}) async {
    final name = TextEditingController(text: project?['name']?.toString() ?? '');
    final description = TextEditingController(text: project?['description']?.toString() ?? '');
    var status = project?['status']?.toString() ?? 'not_started';
    var deadline = DateTime.tryParse(project?['deadline']?.toString() ?? '');
    final result = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, refresh) => AlertDialog(
      title: Text(project == null ? 'New project' : 'Edit project'),
      content: SizedBox(width: 420, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'Project name')),
        const SizedBox(height: 12), TextField(controller: description, maxLines: 3, decoration: const InputDecoration(labelText: 'Description (optional)')),
        const SizedBox(height: 12), DropdownButtonFormField<String>(initialValue: status, decoration: const InputDecoration(labelText: 'Status'),
          items: _statuses.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(), onChanged: (v) { if (v != null) refresh(() => status = v); }),
        ListTile(contentPadding: EdgeInsets.zero, title: const Text('Deadline'), subtitle: Text(deadline == null ? 'No deadline' : '${deadline!.day}/${deadline!.month}/${deadline!.year}'),
          trailing: Wrap(children: [if (deadline != null) IconButton(onPressed: () => refresh(() => deadline = null), icon: const Icon(Icons.clear)),
            IconButton(onPressed: () async { final d = await _pickDate(deadline); if (d != null) refresh(() => deadline = d); }, icon: const Icon(Icons.calendar_month))])),
      ]))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save'))],
    )));
    if (result == true && name.text.trim().isNotEmpty) {
      try {
        if (project == null) { await _service.createProject(name: name.text, description: description.text, deadline: deadline, status: status); }
        else { await _service.updateProject(id: project['id'].toString(), name: name.text, description: description.text, deadline: deadline, status: status); }
        await _load();
      } catch (e) { _message('Could not save project: $e'); }
    }
    name.dispose(); description.dispose();
  }

  Future<void> _archive(Map<String, dynamic> project, bool archived) async {
    try { await _service.setProjectArchived(project['id'].toString(), archived); await _load(); }
    catch (e) { _message('Could not update project: $e'); }
  }

  Future<void> _delete(Map<String, dynamic> project) async {
    final count = _tasks.where((t) => t['project_id']?.toString() == project['id'].toString()).length;
    final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Delete project?'),
      content: Text(count == 0 ? 'Delete “${project['name']}”?' : 'Delete “${project['name']}”? Its $count linked task(s) will be kept without a project.'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete'))]));
    if (yes != true) return;
    try { await _service.deleteProject(project['id'].toString()); await _load(); } catch (e) { _message('Could not delete project: $e'); }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _projects.where((p) => (p['archived_at'] != null) == _showArchived).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Projects', style: TextStyle(fontWeight: FontWeight.bold)), actions: [
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        IconButton(onPressed: () => setState(() => _showArchived = !_showArchived), icon: Icon(_showArchived ? Icons.inventory_2 : Icons.archive_outlined), tooltip: _showArchived ? 'Show active projects' : 'Show archived projects'),
      ]),
      floatingActionButton: _showArchived ? null : FloatingActionButton.extended(onPressed: () => _edit(), icon: const Icon(Icons.add), label: const Text('New project')),
      body: _loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(onRefresh: _load,
        child: visible.isEmpty ? ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(32), children: [const SizedBox(height: 100), const Icon(Icons.folder_open, size: 56), const SizedBox(height: 16),
          Text(_showArchived ? 'No archived projects' : 'No projects yet', textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 8),
          Text(_showArchived ? 'Archived projects will appear here.' : 'Create projects to organize related tasks.', textAlign: TextAlign.center)])
        : ListView.builder(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(16, 12, 16, 100), itemCount: visible.length, itemBuilder: (ctx, i) {
          final p = visible[i]; final related = _tasks.where((t) => t['project_id']?.toString() == p['id'].toString()).toList();
          final done = related.where((t) => t['status'] == 'completed').length;
          final progress = related.isEmpty ? 0.0 : done / related.length;
          final status = _statuses[p['status']] ?? 'Not Started';
          final deadline = DateTime.tryParse(p['deadline']?.toString() ?? '');
          return Card(margin: const EdgeInsets.only(bottom: 12), child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: ListTile(
            leading: CircleAvatar(child: Icon(p['archived_at'] == null ? Icons.folder_outlined : Icons.archive_outlined)),
            title: Text(p['name']?.toString() ?? 'Untitled', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if ((p['description']?.toString() ?? '').isNotEmpty) Text(p['description'].toString(), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6), Wrap(spacing: 12, children: [Text(status), Text('${related.length} tasks'), if (deadline != null) Text('Due ${deadline.day}/${deadline.month}/${deadline.year}')]),
              const SizedBox(height: 7), LinearProgressIndicator(value: progress), const SizedBox(height: 3), Text('$done of ${related.length} tasks complete'),
            ]), isThreeLine: true,
            trailing: PopupMenuButton<String>(onSelected: (v) { if (v == 'edit') _edit(project: p); else if (v == 'delete') _delete(p); else _archive(p, p['archived_at'] == null); }, itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'archive', child: Text(p['archived_at'] == null ? 'Archive' : 'Restore')),
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ]),
          )));
        }),
      ),
    );
  }
}
