import 'dart:async';
import 'package:flutter/material.dart';
import '../db.dart';
import '../models.dart';
import '../widgets.dart';

/// Live countdown to the return date. Refreshes every 30 seconds.
class Countdown extends StatefulWidget {
  final DateTime due;
  const Countdown({super.key, required this.due});

  @override
  State<Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<Countdown> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d0 = widget.due;
    final end = DateTime(d0.year, d0.month, d0.day, 23, 59, 59);
    final diff = end.difference(DateTime.now());
    final String text;
    final Color color;
    if (diff.isNegative) {
      final o = diff.abs();
      text = 'Overdue by ${o.inDays}d ${o.inHours % 24}h';
      color = Colors.red;
    } else {
      text = '${diff.inDays}d ${diff.inHours % 24}h ${diff.inMinutes % 60}m left';
      color = diff.inDays <= 3 ? Colors.orange : Colors.green;
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.timer_outlined, size: 18, color: color),
      const SizedBox(width: 4),
      Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
    ]);
  }
}

class LoansScreen extends StatefulWidget {
  const LoansScreen({super.key});

  @override
  State<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends State<LoansScreen> {
  List<Loan> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = (await AppDb.all('loans')).map(Loan.fromMap).toList()
      ..sort((a, b) {
        if (a.paid != b.paid) return a.paid ? 1 : -1;
        return a.due.compareTo(b.due);
      });
    if (mounted) setState(() => _items = list);
  }

  double get _owed => _items.where((l) => !l.paid).fold<double>(0, (s, l) => s + l.amount);

  Future<void> _edit([Loan? l]) async {
    final name = TextEditingController(text: l?.name);
    final amount = TextEditingController(text: l == null ? '' : l.amount.toString());
    final note = TextEditingController(text: l?.note);
    var due = l?.due ?? DateTime.now().add(const Duration(days: 30));
    var addIncome = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(l == null ? 'New loan' : 'Edit loan', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Who gave you the loan?', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Loan amount', prefixText: '৳ ', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: note,
                decoration: const InputDecoration(labelText: 'Note (optional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                icon: const Icon(Icons.event),
                label: Text('Return by: ${dateText(due)}'),
                onPressed: () async {
                  final d = await showDatePicker(
                      context: ctx, initialDate: due, firstDate: DateTime(2020), lastDate: DateTime(2100));
                  if (d != null) setS(() => due = d);
                },
              ),
              if (l == null)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Add this amount to my income'),
                  value: addIncome,
                  onChanged: (v) => setS(() => addIncome = v),
                ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final amt = double.tryParse(amount.text.trim());
                    if (name.text.trim().isEmpty || amt == null) return;
                    final x = Loan(
                        id: l?.id, name: name.text.trim(), amount: amt, due: due, note: note.text.trim(), paid: l?.paid ?? false);
                    if (l == null) {
                      await AppDb.insert('loans', x.toMap());
                      if (addIncome) {
                        await AppDb.insert(
                            'income',
                            Income(title: 'Loan from ${x.name}', amount: amt, source: 'Loan', date: DateTime.now())
                                .toMap());
                      }
                    } else {
                      await AppDb.update('loans', x.toMap(), l.id!);
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Save'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
    _load();
  }

  Future<void> _markReturned(Loan l) async {
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Loan returned?'),
        content: Text('Did you return ${taka(l.amount)} to ${l.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'mark'), child: const Text('Just mark returned')),
          FilledButton(onPressed: () => Navigator.pop(ctx, 'expense'), child: const Text('Returned + add as expense')),
        ],
      ),
    );
    if (r == null) return;
    l.paid = true;
    await AppDb.update('loans', l.toMap(), l.id!);
    if (r == 'expense') {
      await AppDb.insert(
          'expenses',
          Expense(title: 'Loan returned to ${l.name}', amount: l.amount, category: 'Other', date: DateTime.now())
              .toMap());
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Loans')),
      floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _edit(), icon: const Icon(Icons.add), label: const Text('Loan')),
      body: Column(children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: cs.tertiaryContainer, borderRadius: BorderRadius.circular(20)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Total to return', style: TextStyle(color: cs.onTertiaryContainer)),
            Text(taka(_owed),
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: cs.onTertiaryContainer)),
          ]),
        ),
        Expanded(
          child: _items.isEmpty
              ? const Center(child: Text('No loans. Tap Loan to add one.'))
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 90),
                  itemCount: _items.length + 1,
                  itemBuilder: (_, i) {
                    if (i == _items.length) return const CopyrightFooter();
                    final l = _items[i];
                    return Dismissible(
                      key: ValueKey('loan${l.id}'),
                      background: Container(color: cs.errorContainer, child: const Icon(Icons.delete)),
                      onDismissed: (_) async {
                        await AppDb.delete('loans', l.id!);
                        _load();
                      },
                      child: Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Opacity(
                            opacity: l.paid ? 0.55 : 1,
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                Expanded(
                                    child: Text(l.name,
                                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
                                Text(taka(l.amount),
                                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                              ]),
                              const SizedBox(height: 4),
                              Text('Return by ${dateText(l.due)}'),
                              if (l.note.isNotEmpty) Text(l.note, style: TextStyle(color: cs.onSurfaceVariant)),
                              const SizedBox(height: 8),
                              Row(children: [
                                if (l.paid)
                                  const Row(children: [
                                    Icon(Icons.check_circle, color: Colors.green, size: 18),
                                    SizedBox(width: 4),
                                    Text('Returned'),
                                  ])
                                else
                                  Countdown(due: l.due),
                                const Spacer(),
                                if (!l.paid) TextButton(onPressed: () => _markReturned(l), child: const Text('Returned')),
                                IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _edit(l)),
                              ]),
                            ]),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}
