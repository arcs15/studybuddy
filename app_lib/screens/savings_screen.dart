import 'package:flutter/material.dart';
import '../db.dart';
import '../models.dart';
import '../widgets.dart';

class SavingsScreen extends StatefulWidget {
  const SavingsScreen({super.key});

  @override
  State<SavingsScreen> createState() => _SavingsScreenState();
}

class _SavingsScreenState extends State<SavingsScreen> {
  List<SavingTx> _items = [];
  String _goal = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = (await AppDb.all('savings')).map(SavingTx.fromMap).toList()
      ..sort((a, b) {
        final c = b.date.compareTo(a.date);
        return c != 0 ? c : (b.id ?? 0).compareTo(a.id ?? 0);
      });
    final goal = await AppDb.getSetting('saving_goal') ?? '';
    if (mounted) {
      setState(() {
        _items = list;
        _goal = goal;
      });
    }
  }

  double get _total => _items.fold<double>(0, (s, t) => s + (t.isAdd ? t.amount : -t.amount));

  Future<void> _editGoal() async {
    final c = TextEditingController(text: _goal);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Why am I saving?'),
        content: TextField(
          controller: c,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'e.g. Buy a laptop, emergency fund...', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              await AppDb.setSetting('saving_goal', c.text.trim());
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    _load();
  }

  Future<void> _tx(bool add) async {
    final amount = TextEditingController();
    final note = TextEditingController();
    var date = DateTime.now();
    String? err;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(add ? 'Add to savings' : 'Withdraw from savings', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextField(
                controller: amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Amount', prefixText: '৳ ', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: note,
                decoration: InputDecoration(
                  labelText: add ? 'Note: why are you saving?' : 'Note: why are you withdrawing?',
                  border: const OutlineInputBorder(),
                ),
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
              if (err != null) Text(err!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final amt = double.tryParse(amount.text.trim());
                    if (amt == null || amt <= 0) {
                      setS(() => err = 'Enter a valid amount');
                      return;
                    }
                    if (!add && amt > _total) {
                      setS(() => err = 'You only have ${taka(_total)} in savings');
                      return;
                    }
                    final x = SavingTx(isAdd: add, amount: amt, note: note.text.trim(), date: date);
                    await AppDb.insert('savings', x.toMap());
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: Text(add ? 'Add fund' : 'Withdraw'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Savings')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(colors: [cs.primary, cs.tertiary]),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Total savings', style: TextStyle(color: cs.onPrimary)),
            const SizedBox(height: 4),
            Text(taka(_total), style: TextStyle(color: cs.onPrimary, fontSize: 34, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            InkWell(
              onTap: _editGoal,
              child: Row(children: [
                Icon(Icons.flag, size: 18, color: cs.onPrimary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(_goal.isEmpty ? 'Tap to write why you are saving' : _goal,
                      style: TextStyle(color: cs.onPrimary)),
                ),
                Icon(Icons.edit, size: 16, color: cs.onPrimary),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add fund'),
              onPressed: () => _tx(true),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.remove),
              label: const Text('Withdraw'),
              onPressed: () => _tx(false),
            ),
          ),
        ]),
        const SizedBox(height: 20),
        Text('History', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (_items.isEmpty)
          const Padding(padding: EdgeInsets.all(16), child: Text('No savings yet. Tap Add fund to start.'))
        else
          ..._items.map((t) => Dismissible(
                key: ValueKey('sv${t.id}'),
                background: Container(color: cs.errorContainer, child: const Icon(Icons.delete)),
                onDismissed: (_) async {
                  await AppDb.delete('savings', t.id!);
                  _load();
                },
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: t.isAdd ? Colors.green.withAlpha(50) : Colors.red.withAlpha(50),
                    child: Icon(t.isAdd ? Icons.arrow_downward : Icons.arrow_upward,
                        color: t.isAdd ? Colors.green : Colors.red),
                  ),
                  title: Text(t.note.isEmpty ? (t.isAdd ? 'Added fund' : 'Withdrawn') : t.note),
                  subtitle: Text('${t.isAdd ? 'Added' : 'Withdrawn'} • ${dateText(t.date)}'),
                  trailing: Text('${t.isAdd ? '+' : '-'}${taka(t.amount)}',
                      style: TextStyle(fontWeight: FontWeight.bold, color: t.isAdd ? Colors.green : Colors.red)),
                ),
              )),
        const CopyrightFooter(),
      ]),
    );
  }
}
