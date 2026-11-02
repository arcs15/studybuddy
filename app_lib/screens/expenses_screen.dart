import 'package:flutter/material.dart';
import '../db.dart';
import '../models.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  List<Expense> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = (await AppDb.all('expenses')).map(Expense.fromMap).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    if (mounted) setState(() => _items = list);
  }

  double get _monthTotal {
    final n = DateTime.now();
    return _items
        .where((e) => e.date.year == n.year && e.date.month == n.month)
        .fold<double>(0, (s, e) => s + e.amount);
  }

  Future<void> _edit([Expense? e]) async {
    final title = TextEditingController(text: e?.title);
    final amount = TextEditingController(text: e == null ? '' : e.amount.toString());
    var cat = e?.category ?? categories.first;
    var date = e?.date ?? DateTime.now();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(e == null ? 'New expense' : 'Edit expense', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: title,
              decoration: const InputDecoration(labelText: 'What did you spend on?', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount', prefixText: '৳ ', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: categories
                  .map((c) => ChoiceChip(label: Text(c), selected: cat == c, onSelected: (_) => setS(() => cat = c)))
                  .toList(),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              icon: const Icon(Icons.calendar_today),
              label: Text(dateText(date)),
              onPressed: () async {
                final d = await showDatePicker(
                    context: ctx, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime(2100));
                if (d != null) setS(() => date = d);
              },
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  final amt = double.tryParse(amount.text.trim());
                  if (title.text.trim().isEmpty || amt == null) return;
                  final x = Expense(id: e?.id, title: title.text.trim(), amount: amt, category: cat, date: date);
                  e == null ? await AppDb.insert('expenses', x.toMap()) : await AppDb.update('expenses', x.toMap(), e.id!);
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

  IconData _icon(String c) => switch (c) {
        'Food' => Icons.restaurant,
        'Transport' => Icons.directions_bus,
        'Books' => Icons.menu_book,
        'Fees' => Icons.school,
        'Rent' => Icons.home,
        'Bills' => Icons.receipt_long,
        'Health' => Icons.local_hospital,
        'Lend' => Icons.handshake,
        'Fun' => Icons.sports_esports,
        _ => Icons.category,
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Expenses')),
      floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _edit(), icon: const Icon(Icons.add), label: const Text('Add')),
      body: Column(children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(20)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('This month', style: TextStyle(color: cs.onPrimaryContainer)),
            Text(taka(_monthTotal),
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: cs.onPrimaryContainer)),
          ]),
        ),
        Expanded(
          child: _items.isEmpty
              ? const Center(child: Text('No expenses yet. Tap Add!'))
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 90),
                  itemCount: _items.length,
                  itemBuilder: (_, i) {
                    final e = _items[i];
                    return Dismissible(
                      key: ValueKey('exp${e.id}'),
                      background: Container(color: cs.errorContainer, child: const Icon(Icons.delete)),
                      onDismissed: (_) async {
                        await AppDb.delete('expenses', e.id!);
                        _load();
                      },
                      child: ListTile(
                        leading: CircleAvatar(child: Icon(_icon(e.category))),
                        title: Text(e.title),
                        subtitle: Text('${e.category} • ${dateText(e.date)}'),
                        trailing: Text(taka(e.amount), style: const TextStyle(fontWeight: FontWeight.bold)),
                        onTap: () => _edit(e),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}
