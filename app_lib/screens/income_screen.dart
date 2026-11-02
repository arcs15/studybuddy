import 'package:flutter/material.dart';
import '../db.dart';
import '../models.dart';
import '../widgets.dart';

class IncomeScreen extends StatefulWidget {
  const IncomeScreen({super.key});

  @override
  State<IncomeScreen> createState() => _IncomeScreenState();
}

class _IncomeScreenState extends State<IncomeScreen> {
  List<Income> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = (await AppDb.all('income')).map(Income.fromMap).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    if (mounted) setState(() => _items = list);
  }

  double get _monthTotal {
    final n = DateTime.now();
    return _items.where((e) => sameMonth(e.date, n)).fold<double>(0, (s, e) => s + e.amount);
  }

  Future<void> _edit([Income? e]) async {
    final title = TextEditingController(text: e?.title);
    final amount = TextEditingController(text: e == null ? '' : e.amount.toString());
    var src = e?.source ?? incomeSources.first;
    var date = e?.date ?? DateTime.now();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(e == null ? 'New income' : 'Edit income', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextField(
                controller: title,
                decoration: const InputDecoration(labelText: 'Title (e.g. Monthly salary)', border: OutlineInputBorder()),
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
                children: incomeSources
                    .map((c) => ChoiceChip(label: Text(c), selected: src == c, onSelected: (_) => setS(() => src = c)))
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
                    final x = Income(id: e?.id, title: title.text.trim(), amount: amt, source: src, date: date);
                    e == null ? await AppDb.insert('income', x.toMap()) : await AppDb.update('income', x.toMap(), e.id!);
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Income')),
      floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _edit(), icon: const Icon(Icons.add), label: const Text('Income')),
      body: Column(children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(20)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Income this month', style: TextStyle(color: cs.onPrimaryContainer)),
            Text(taka(_monthTotal),
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: cs.onPrimaryContainer)),
          ]),
        ),
        Expanded(
          child: _items.isEmpty
              ? const Center(child: Text('No income yet. Tap Income to add!'))
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 90),
                  itemCount: _items.length + 1,
                  itemBuilder: (_, i) {
                    if (i == _items.length) return const CopyrightFooter();
                    final e = _items[i];
                    return Dismissible(
                      key: ValueKey('inc${e.id}'),
                      background: Container(color: cs.errorContainer, child: const Icon(Icons.delete)),
                      onDismissed: (_) async {
                        await AppDb.delete('income', e.id!);
                        _load();
                      },
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.south_west)),
                        title: Text(e.title),
                        subtitle: Text('${e.source} • ${dateText(e.date)}'),
                        trailing: Text('+${taka(e.amount)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
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
