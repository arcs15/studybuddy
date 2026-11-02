import 'package:flutter/material.dart';
import '../widgets.dart';
import 'income_screen.dart';
import 'loans_screen.dart';
import 'report_screen.dart';
import 'savings_screen.dart';
import 'sms_import_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  Widget _tile(BuildContext context, IconData icon, String title, String sub, Widget page) => Card(
        child: ListTile(
          leading: CircleAvatar(child: Icon(icon)),
          title: Text(title),
          subtitle: Text(sub),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('More')),
        body: ListView(padding: const EdgeInsets.all(12), children: [
          _tile(context, Icons.trending_up, 'Income', 'Salary, tuition and extra income', const IncomeScreen()),
          _tile(context, Icons.savings, 'Savings', 'Your savings fund and history', const SavingsScreen()),
          _tile(context, Icons.account_balance_wallet, 'Loans', 'Money you borrowed and return dates', const LoansScreen()),
          _tile(context, Icons.bar_chart, 'Monthly report', 'Compare months, limit and warning', const ReportScreen()),
          _tile(context, Icons.sms, 'Import from SMS', 'Read bKash / Nagad / bank messages', const SmsImportScreen()),
          const CopyrightFooter(),
        ]),
      );
}
