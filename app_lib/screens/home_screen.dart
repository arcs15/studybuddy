import 'package:flutter/material.dart';
import '../db.dart';
import '../finance.dart';
import '../models.dart';
import '../widgets.dart';
import 'income_screen.dart';
import 'loans_screen.dart';
import 'report_screen.dart';
import 'sms_import_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<(Finance, List<Task>, int, Loan?)> _f;

  @override
  void initState() {
    super.initState();
    _f = _load();
  }

  void _reload() {
    setState(() {
      _f = _load();
    });
  }

  void _go(Widget w) => Navigator.push(context, MaterialPageRoute(builder: (_) => w)).then((_) => _reload());

  Future<(Finance, List<Task>, int, Loan?)> _load() async {
    final fin = await Finance.load();
    final pending = (await AppDb.all('tasks')).map(Task.fromMap).where((t) => !t.done).toList()
      ..sort((a, b) => (a.due ?? DateTime(2100)).compareTo(b.due ?? DateTime(2100)));
    final pinned = (await AppDb.all('notes')).map(Note.fromMap).where((n) => n.pinned).length;
    final loans = (await AppDb.all('loans')).map(Loan.fromMap).where((l) => !l.paid).toList()
      ..sort((a, b) => a.due.compareTo(b.due));
    return (fin, pending, pinned, loans.isEmpty ? null : loans.first);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('StudyBuddy', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: 'Import from SMS',
            icon: const Icon(Icons.sms_outlined),
            onPressed: () => _go(const SmsImportScreen()),
          ),
        ],
      ),
      body: FutureBuilder(
        future: _f,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final (fin, pending, pinned, loan) = snap.data!;
          final now = fin.now;
          final income = fin.incomeIn(now);
          final spent = fin.spentIn(now);
          final saved = fin.savedIn(now);
          final left = income - spent - saved;
          final lim = fin.limit;
          final ratio = fin.ratio;

          return ListView(padding: const EdgeInsets.all(16), children: [
            // ---- Income / spent / left chart ----
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: income <= 0
                    ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Spent this month', style: Theme.of(context).textTheme.labelLarge),
                        const SizedBox(height: 4),
                        Text(taka(spent), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        const Text('Add your income (salary, tuition, extra) to see how much is left.'),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Add income'),
                          onPressed: () => _go(const IncomeScreen()),
                        ),
                      ])
                    : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Text('This month', style: Theme.of(context).textTheme.titleMedium),
                          const Spacer(),
                          TextButton.icon(
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Income'),
                            onPressed: () => _go(const IncomeScreen()),
                          ),
                        ]),
                        Row(children: [
                          DonutChart(
                            values: [spent, saved > 0 ? saved : 0, left > 0 ? left : 0],
                            colors: const [Colors.deepOrange, Colors.teal, Colors.green],
                            center: SizedBox(
                              width: 90,
                              child: FittedBox(
                                child: Column(mainAxisSize: MainAxisSize.min, children: [
                                  Text(left >= 0 ? 'Left' : 'Over', style: const TextStyle(fontSize: 12)),
                                  Text(taka(left.abs()),
                                      style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: left >= 0 ? null : Colors.red)),
                                ]),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(children: [
                              _legend(Colors.blueGrey, 'Income', income),
                              _legend(Colors.deepOrange, 'Spent', spent),
                              _legend(Colors.teal, 'Saved', saved),
                              _legend(Colors.green, 'Left', left),
                            ]),
                          ),
                        ]),
                      ]),
              ),
            ),
            // ---- Limit warning ----
            if (lim != null && ratio >= 0.8) ...[
              const SizedBox(height: 12),
              Builder(builder: (_) {
                final st = limitStatus(ratio);
                return InkWell(
                  onTap: () => _go(const ReportScreen()),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: st.color.withAlpha(40),
                      border: Border.all(color: st.color),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(children: [
                      Icon(Icons.warning_amber_rounded, color: st.color),
                      const SizedBox(width: 10),
                      Expanded(child: Text('${st.text}\nLimit: ${taka(lim)}')),
                    ]),
                  ),
                );
              }),
            ],
            // ---- Loan due ----
            if (loan != null) ...[
              const SizedBox(height: 12),
              InkWell(
                onTap: () => _go(const LoansScreen()),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: cs.tertiaryContainer, borderRadius: BorderRadius.circular(16)),
                  child: Row(children: [
                    Icon(Icons.account_balance_wallet, color: cs.onTertiaryContainer),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Return ${taka(loan.amount)} to ${loan.name} by ${dateText(loan.due)}',
                        style: TextStyle(color: cs.onTertiaryContainer),
                      ),
                    ),
                  ]),
                ),
              ),
            ],
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
            const CopyrightFooter(),
          ]);
        },
      ),
    );
  }

  Widget _legend(Color c, String label, double v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(label),
          const Spacer(),
          Text(taka(v), style: const TextStyle(fontWeight: FontWeight.bold)),
        ]),
      );

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
