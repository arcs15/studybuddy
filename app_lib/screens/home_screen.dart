import 'package:flutter/material.dart';
import '../db.dart';
import '../models.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<(double, List<Task>, int)> _f;

  @override
  void initState() {
    super.initState();
    _f = _load();
  }

  Future<(double, List<Task>, int)> _load() async {
    final now = DateTime.now();
    final expenses = (await AppDb.all('expenses')).map(Expense.fromMap);
    final month = expenses
        .where((e) => e.date.year == now.year && e.date.month == now.month)
        .fold<double>(0, (s, e) => s + e.amount);
    final pending = (await AppDb.all('tasks')).map(Task.fromMap).where((t) => !t.done).toList()
      ..sort((a, b) => (a.due ?? DateTime(2100)).compareTo(b.due ?? DateTime(2100)));
    final pinned = (await AppDb.all('notes')).map(Note.fromMap).where((n) => n.pinned).length;
    return (month, pending, pinned);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('StudyBuddy', style: TextStyle(fontWeight: FontWeight.bold))),
      body: FutureBuilder(
        future: _f,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final (month, pending, pinned) = snap.data!;
          return ListView(padding: const EdgeInsets.all(16), children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(colors: [cs.primary, cs.tertiary]),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Spent this month', style: TextStyle(color: cs.onPrimary)),
                const SizedBox(height: 6),
                Text(taka(month),
                    style: TextStyle(color: cs.onPrimary, fontSize: 34, fontWeight: FontWeight.bold)),
              ]),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _stat(context, Icons.checklist, '${pending.length}', 'Pending tasks')),
              const SizedBox(width: 12),
              Expanded(child: _stat(context, Icons.push_pin, '$pinned', 'Pinned notes')),
            ]),
            const SizedBox(height: 20),
            Text('Upcoming tasks', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (pending.isEmpty)
              const Padding(padding: EdgeInsets.all(16), child: Text('Nothing pending. Enjoy your day! 🎉'))
            else
              ...pending.take(5).map((t) => Card(
                    child: ListTile(
                      leading: Icon(Icons.circle_outlined, color: t.overdue ? cs.error : cs.primary),
                      title: Text(t.title),
                      subtitle: Text(t.due == null ? 'No due date' : dateText(t.due!),
                          style: TextStyle(color: t.overdue ? cs.error : null)),
                    ),
                  )),
          ]);
        },
      ),
    );
  }

  Widget _stat(BuildContext context, IconData icon, String value, String label) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(20)),
      child: Row(children: [
        Icon(icon, color: cs.onPrimaryContainer),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: cs.onPrimaryContainer)),
          Text(label, style: TextStyle(fontSize: 12, color: cs.onPrimaryContainer)),
        ]),
      ]),
    );
  }
}
