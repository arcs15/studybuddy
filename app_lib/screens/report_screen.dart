import 'package:flutter/material.dart';
import '../db.dart';
import '../finance.dart';
import '../models.dart';
import '../widgets.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  late Future<Finance> _f;

  @override
  void initState() {
    super.initState();
    _f = Finance.load();
  }

  Future<void> _editLimit(Finance f) async {
    final c = TextEditingController(text: f.customLimit?.toStringAsFixed(0) ?? '');
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Monthly spending limit'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: c,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(prefixText: '৳ ', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          Text(f.suggestedLimit == null
              ? 'No suggestion yet. Add income or some expenses first.'
              : 'Suggested: ${taka(f.suggestedLimit!)}'),
        ]),
        actions: [
          TextButton(
            onPressed: () async {
              await AppDb.setSetting('monthly_limit', '');
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Use suggested'),
          ),
          FilledButton(
            onPressed: () async {
              final v = double.tryParse(c.text.trim());
              if (v == null || v <= 0) return;
              await AppDb.setSetting('monthly_limit', v.toString());
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    setState(() {
      _f = Finance.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Monthly report')),
      body: FutureBuilder<Finance>(
        future: _f,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final f = snap.data!;
          final now = f.now;
          final lim = f.limit;
          final spent = f.spentIn(now);
          final last = f.spentIn(DateTime(now.year, now.month - 1));
          final months = List.generate(6, (i) => DateTime(now.year, now.month - 5 + i));

          // category totals this month
          final cat = <String, double>{};
          for (final e in f.expenses.where((e) => sameMonth(e.date, now))) {
            cat[e.category] = (cat[e.category] ?? 0) + e.amount;
          }
          final cats = cat.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

          final st = limitStatus(f.ratio);

          return ListView(padding: const EdgeInsets.all(16), children: [
            // ---- limit & warning ----
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: lim == null ? cs.surfaceContainerHighest : st.color.withAlpha(35),
                border: Border.all(color: lim == null ? cs.outlineVariant : st.color),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text('Spent this month', style: Theme.of(context).textTheme.labelLarge)),
                  TextButton.icon(
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Limit'),
                    onPressed: () => _editLimit(f),
                  ),
                ]),
                Text(taka(spent), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (lim == null)
                  const Text('Add income or some expenses to get a suggested limit.')
                else ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: f.ratio > 1 ? 1 : f.ratio,
                      minHeight: 12,
                      color: st.color,
                      backgroundColor: cs.surfaceContainerHighest,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(st.text, style: TextStyle(color: st.color, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                      '${f.usingSuggested ? 'Suggested limit' : 'Your limit'}: ${taka(lim)}\n'
                      'Warning starts at: ${taka(lim * 0.8)} (80%)\n'
                      'Left before limit: ${lim - spent >= 0 ? taka(lim - spent) : '৳0'}'),
                  if (f.usingSuggested)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        f.incomeIn(now) > 0
                            ? 'Suggestion = 70% of this month\'s income. The other 30% is for savings and emergencies.'
                            : 'Suggestion = your average spending of the last 3 months.',
                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                      ),
                    ),
                ],
              ]),
            ),
            const SizedBox(height: 20),
            // ---- 6 month comparison ----
            Text('Last 6 months', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            MonthBars(
              labels: months.map(monthShort).toList(),
              values: months.map(f.spentIn).toList(),
              limit: lim,
            ),
            const SizedBox(height: 4),
            Text(
              lim == null ? '' : 'Red line = monthly limit. Green = safe, orange = warning, red = over limit.',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            if (last > 0)
              Text(
                spent > last
                    ? 'You spent ${taka(spent - last)} MORE than last month (${((spent - last) / last * 100).round()}% up).'
                    : 'You spent ${taka(last - spent)} less than last month (${((last - spent) / last * 100).round()}% down).',
              )
            else
              const Text('No spending recorded last month to compare.'),
            const SizedBox(height: 24),
            // ---- categories ----
            Text('Where your money went (this month)', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (cats.isEmpty)
              const Text('No expenses this month.')
            else
              ...cats.map((c) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text(c.key),
                        const Spacer(),
                        Text(taka(c.value), style: const TextStyle(fontWeight: FontWeight.bold)),
                      ]),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(value: spent <= 0 ? 0 : c.value / spent, minHeight: 8),
                      ),
                    ]),
                  )),
            const CopyrightFooter(),
          ]);
        },
      ),
    );
  }
}
