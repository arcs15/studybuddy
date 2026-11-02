import 'package:flutter/material.dart';
import '../db.dart';
import '../models.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  List<Task> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = (await AppDb.all('tasks')).map(Task.fromMap).toList()
      ..sort((a, b) {
        if (a.done != b.done) return a.done ? 1 : -1;
        return (a.due ?? DateTime(2100)).compareTo(b.due ?? DateTime(2100));
      });
    if (mounted) setState(() => _items = list);
  }

  Future<void> _edit([Task? t]) async {
    final title = TextEditingController(text: t?.title);
    DateTime? due = t?.due;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(t == null ? 'New task' : 'Edit task', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: title,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Task', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            Row(children: [
              TextButton.icon(
                icon: const Icon(Icons.event),
                label: Text(due == null ? 'Set due date' : dateText(due!)),
                onPressed: () async {
                  final d = await showDatePicker(
                      context: ctx,
                      initialDate: due ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100));
                  if (d != null) setS(() => due = d);
                },
              ),
              if (due != null) IconButton(icon: const Icon(Icons.clear), onPressed: () => setS(() => due = null)),
            ]),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  if (title.text.trim().isEmpty) return;
                  final x = Task(id: t?.id, title: title.text.trim(), due: due, done: t?.done ?? false);
                  t == null ? await AppDb.insert('tasks', x.toMap()) : await AppDb.update('tasks', x.toMap(), t.id!);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Save'),
              ),
            ),
          ]),
        ),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Upcoming Tasks')),
      floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _edit(), icon: const Icon(Icons.add), label: const Text('Task')),
      body: _items.isEmpty
          ? const Center(child: Text('No tasks yet. Tap Task!'))
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 90),
              itemCount: _items.length,
              itemBuilder: (_, i) {
                final t = _items[i];
                return Dismissible(
                  key: ValueKey('task${t.id}'),
                  background: Container(color: cs.errorContainer, child: const Icon(Icons.delete)),
                  onDismissed: (_) async {
                    await AppDb.delete('tasks', t.id!);
                    _load();
                  },
                  child: ListTile(
                    leading: Checkbox(
                      value: t.done,
                      onChanged: (v) async {
                        t.done = v ?? false;
                        await AppDb.update('tasks', t.toMap(), t.id!);
                        _load();
                      },
                    ),
                    title: Text(t.title,
                        style: TextStyle(decoration: t.done ? TextDecoration.lineThrough : null)),
                    subtitle: t.due == null
                        ? null
                        : Text(t.overdue ? 'Overdue • ${dateText(t.due!)}' : dateText(t.due!),
                            style: TextStyle(color: t.overdue ? cs.error : null)),
                    onTap: () => _edit(t),
                  ),
                );
              },
            ),
    );
  }
}
