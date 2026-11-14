import 'package:flutter/material.dart';

import '../../data/project_service.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final ProjectService _service = ProjectService();
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _taskLinks = [];
  bool _loading = true;
  static const _colors = <String, Color>{
    'Purple': Color(0xFF6750A4), 'Blue': Color(0xFF1565C0),
    'Teal': Color(0xFF00897B), 'Green': Color(0xFF558B2F),
    'Orange': Color(0xFFEF6C00), 'Red': Color(0xFFC62828),
    'Pink': Color(0xFFAD1457), 'Grey': Color(0xFF616161),
  };

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final values = await Future.wait([_service.getCategories(), _service.getTaskLinks()]);
      if (!mounted) return;
      setState(() { _categories = values[0]; _taskLinks = values[1]; _loading = false; });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _message('Could not load categories: $error');
    }
  }

  void _message(String value) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));

  Future<void> _edit({Map<String, dynamic>? category}) async {
    final name = TextEditingController(text: category?['name']?.toString() ?? '');
    var color = category?['color']?.toString() ?? '#6750A4';
    final result = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialog) => AlertDialog(
        title: Text(category == null ? 'New category' : 'Edit category'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, autofocus: true, textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Category name')),
          const SizedBox(height: 18),
          Wrap(spacing: 10, runSpacing: 10, children: _colors.entries.map((entry) => InkWell(
            onTap: () => setDialog(() => color = '#${entry.value.value.toRadixString(16).substring(2).toUpperCase()}'),
            child: CircleAvatar(backgroundColor: entry.value, radius: 17,
              child: color.toUpperCase() == '#${entry.value.value.toRadixString(16).substring(2).toUpperCase()}'
                  ? const Icon(Icons.check, color: Colors.white, size: 18) : null),
          )).toList()),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save'))],
      ),
    ));
    if (result == true && name.text.trim().isNotEmpty) {
      try {
        if (category == null) {
          await _service.createCategory(name.text.trim(), color: color);
        } else {
          await _service.updateCategory(id: category['id'].toString(), name: name.text.trim(), color: color);
        }
        await _load();
      } catch (error) { _message('Could not save category: $error'); }
    }
    name.dispose();
  }

  Future<void> _delete(Map<String, dynamic> category) async {
    final count = _taskLinks.where((t) => t['category_id']?.toString() == category['id'].toString()).length;
    final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete category?'),
      content: Text(count == 0 ? 'Delete “${category['name']}”?' : 'Delete “${category['name']}”? Its $count linked task(s) will be kept and set to Uncategorized.'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete'))],
    ));
    if (yes != true) return;
    try { await _service.deleteCategory(category['id'].toString()); await _load(); }
    catch (error) { _message('Could not delete category: $error'); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Categories', style: TextStyle(fontWeight: FontWeight.bold)),
      actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))]),
    floatingActionButton: FloatingActionButton.extended(onPressed: () => _edit(), icon: const Icon(Icons.add), label: const Text('New category')),
    body: _loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(onRefresh: _load,
      child: _categories.isEmpty ? ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(32), children: const [
        SizedBox(height: 100), Icon(Icons.label_outline, size: 56), SizedBox(height: 16),
        Text('No categories yet', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        SizedBox(height: 8), Text('Create categories, then assign them to tasks.', textAlign: TextAlign.center),
      ]) : ListView.builder(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: _categories.length, itemBuilder: (ctx, i) {
          final c = _categories[i];
          final id = c['id'].toString();
          final count = _taskLinks.where((t) => t['category_id']?.toString() == id).length;
          final raw = c['color']?.toString() ?? '#6750A4';
          final parsed = int.tryParse(raw.replaceFirst('#', ''), radix: 16) ?? 0xFF6750A4;
          final swatch = Color(parsed <= 0xFFFFFF ? parsed | 0xFF000000 : parsed);
          return Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(
            leading: CircleAvatar(backgroundColor: swatch, child: const Icon(Icons.label, color: Colors.white)),
            title: Text(c['name']?.toString() ?? 'Untitled', style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('$count ${count == 1 ? 'task' : 'tasks'}'),
            trailing: PopupMenuButton<String>(onSelected: (v) => v == 'edit' ? _edit(category: c) : _delete(c), itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ]),
          ));
        }),
    ),
  );
}
