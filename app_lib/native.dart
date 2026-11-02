import 'dart:async';
import 'package:flutter/services.dart';
import 'db.dart';
import 'finance.dart';
import 'models.dart';

/// Talks to the Android side: reminders (notifications) and the home screen widget.
class Native {
  static const _ch = MethodChannel('arcx/native');
  static Timer? _debounce;

  static Future<void> _call(String m, [Object? args]) async {
    try {
      await _ch.invokeMethod(m, args);
    } catch (_) {
      // ignore: the app still works without native features
    }
  }

  static Future<void> requestNotifPermission() => _call('requestNotifPermission');
  static Future<void> testReminder() => _call('testReminder');

  /// Wait 2 seconds after the last change, then refresh reminders + widget.
  static void requestSync() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), () {
      sync();
    });
  }

  static Future<void> sync() async {
    try {
      final now = DateTime.now();
      final fin = await Finance.load();
      final list = <Map<String, Object?>>[];

      void add(int id, DateTime t, String title, String body) {
        if (t.isAfter(now)) {
          list.add({'id': id, 'time': t.millisecondsSinceEpoch, 'title': title, 'body': body});
        }
      }

      // ---- task reminders: evening before (6 PM) and the day (8 AM) ----
      final tasks = (await AppDb.all('tasks')).map(Task.fromMap).where((t) => !t.done && t.due != null);
      for (final t in tasks) {
        final d = t.due!;
        add(1000000 + t.id! * 10 + 1, DateTime(d.year, d.month, d.day - 1, 18), 'Task due tomorrow', t.title);
        add(1000000 + t.id! * 10 + 2, DateTime(d.year, d.month, d.day, 8), 'Task due today', t.title);
      }

      // ---- loan return reminders: 3 days, 1 day, and on the day (9 AM) ----
      final loans = (await AppDb.all('loans')).map(Loan.fromMap).where((l) => !l.paid);
      for (final l in loans) {
        final d = l.due;
        const days = [3, 1, 0];
        for (var k = 0; k < days.length; k++) {
          final n = days[k];
          final body = n == 0
              ? 'Return ${taka(l.amount)} to ${l.name} TODAY'
              : 'Return ${taka(l.amount)} to ${l.name} in $n day${n == 1 ? '' : 's'}';
          add(2000000 + l.id! * 10 + k, DateTime(d.year, d.month, d.day - n, 9), 'Loan reminder', body);
        }
      }

      // ---- budget warning: once per level per month ----
      final lim = fin.limit;
      final ratio = fin.ratio;
      final level = ratio >= 1 ? 100 : (ratio >= 0.8 ? 80 : 0);
      final key = 'warned_${now.year}_${now.month}';
      final prev = int.tryParse(await AppDb.getSetting(key) ?? '') ?? 0;
      if (lim != null && level > prev) {
        await AppDb.setSetting(key, '$level');
        final spent = fin.spentIn(now);
        add(
          4000000 + level,
          now.add(const Duration(seconds: 3)),
          level == 100 ? 'Budget limit crossed!' : 'Budget warning',
          'You spent ${taka(spent)} of your ${taka(lim)} monthly limit.',
        );
      }

      await _call('scheduleReminders', list);

      // ---- home screen widget ----
      final income = fin.incomeIn(now);
      final spent = fin.spentIn(now);
      final left = income - spent - fin.savedIn(now);
      await _call('updateWidget', {
        'title': 'StudyBuddy • ${monthShort(now)}',
        'big': income > 0 ? 'Left ${taka(left)}' : 'Spent ${taka(spent)}',
        'line': income > 0 ? 'Spent ${taka(spent)} of ${taka(income)}' : 'Add your income in the app',
      });
    } catch (_) {
      // never crash the app because of reminders
    }
  }
}
