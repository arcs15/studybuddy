import 'package:flutter/material.dart';
import '../db.dart';
import '../native.dart';
import '../theme_state.dart';
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
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Appearance', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: themeNotifier,
                  builder: (context, mode, _) => SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(value: ThemeMode.system, label: Text('Auto'), icon: Icon(Icons.phone_android)),
                      ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode)),
                      ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode)),
                    ],
                    selected: {mode},
                    onSelectionChanged: (s) {
                      themeNotifier.value = s.first;
                      AppDb.setSetting('theme_mode', s.first.name);
                    },
                  ),
                ),
              ]),
            ),
          ),
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.notifications_active)),
              title: const Text('Test reminder'),
              subtitle: const Text('Get a test notification in 10 seconds'),
              onTap: () async {
                await Native.requestNotifPermission();
                await Native.testReminder();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Test notification coming in 10 seconds. You can close the app.')));
                }
              },
            ),
          ),
          const CopyrightFooter(),
        ]),
      );
}
