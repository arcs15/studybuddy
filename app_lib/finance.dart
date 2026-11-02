import 'package:flutter/material.dart';
import 'db.dart';
import 'models.dart';

/// Loads money data once and answers monthly questions.
class Finance {
  final List<Expense> expenses;
  final List<Income> incomes;
  final List<SavingTx> savings;
  final double? customLimit;
  final DateTime now = DateTime.now();

  Finance(this.expenses, this.incomes, this.savings, this.customLimit);

  static Future<Finance> load() async {
    final e = (await AppDb.all('expenses')).map(Expense.fromMap).toList();
    final i = (await AppDb.all('income')).map(Income.fromMap).toList();
    final s = (await AppDb.all('savings')).map(SavingTx.fromMap).toList();
    final lim = double.tryParse(await AppDb.getSetting('monthly_limit') ?? '');
    return Finance(e, i, s, lim != null && lim > 0 ? lim : null);
  }

  double spentIn(DateTime m) =>
      expenses.where((x) => sameMonth(x.date, m)).fold<double>(0, (s, x) => s + x.amount);

  double incomeIn(DateTime m) =>
      incomes.where((x) => sameMonth(x.date, m)).fold<double>(0, (s, x) => s + x.amount);

  /// Money set aside this month (added minus withdrawn).
  double savedIn(DateTime m) => savings
      .where((x) => sameMonth(x.date, m))
      .fold<double>(0, (s, x) => s + (x.isAdd ? x.amount : -x.amount));

  double get totalSavings => savings.fold<double>(0, (s, x) => s + (x.isAdd ? x.amount : -x.amount));

  /// Suggested limit: 70% of this month's income (30% for savings and emergencies).
  /// If there is no income yet, use the average of the last 3 months' spending.
  double? get suggestedLimit {
    final inc = incomeIn(now);
    if (inc > 0) return inc * 0.7;
    final prev = [1, 2, 3]
        .map((i) => spentIn(DateTime(now.year, now.month - i)))
        .where((v) => v > 0)
        .toList();
    if (prev.isEmpty) return null;
    return prev.reduce((a, b) => a + b) / prev.length;
  }

  bool get usingSuggested => customLimit == null;
  double? get limit => customLimit ?? suggestedLimit;

  double get ratio {
    final l = limit;
    if (l == null || l <= 0) return 0;
    return spentIn(now) / l;
  }
}

({String text, Color color}) limitStatus(double ratio) {
  final pct = (ratio * 100).round();
  if (ratio >= 1) return (text: 'Over limit! You used $pct% of your monthly limit.', color: Colors.red);
  if (ratio >= 0.8) return (text: 'Warning: you used $pct% of your monthly limit.', color: Colors.orange);
  return (text: 'On track: $pct% of your monthly limit used.', color: Colors.green);
}
