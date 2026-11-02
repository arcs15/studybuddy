import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Local SQLite helper. All data stays on the phone.
/// Version 2 adds income, loans, savings, settings and sms_done tables
/// (existing data from version 1 is kept).
class AppDb {
  static Database? _db;

  static Future<void> _createNew(Database db) async {
    await db.execute(
        'CREATE TABLE IF NOT EXISTS income(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, amount REAL, source TEXT, date INTEGER)');
    await db.execute(
        'CREATE TABLE IF NOT EXISTS loans(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, amount REAL, due INTEGER, note TEXT, paid INTEGER)');
    await db.execute(
        'CREATE TABLE IF NOT EXISTS savings(id INTEGER PRIMARY KEY AUTOINCREMENT, is_add INTEGER, amount REAL, note TEXT, date INTEGER)');
    await db.execute('CREATE TABLE IF NOT EXISTS settings(k TEXT PRIMARY KEY, v TEXT)');
    await db.execute('CREATE TABLE IF NOT EXISTS sms_done(id INTEGER PRIMARY KEY)');
  }

  static Future<Database> get _d async => _db ??= await openDatabase(
        p.join(await getDatabasesPath(), 'studybuddy.db'),
        version: 2,
        onCreate: (db, v) async {
          await db.execute(
              'CREATE TABLE expenses(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, amount REAL, category TEXT, date INTEGER)');
          await db.execute(
              'CREATE TABLE notes(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, body TEXT, color INTEGER, pinned INTEGER)');
          await db.execute(
              'CREATE TABLE tasks(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, due INTEGER, done INTEGER)');
          await _createNew(db);
        },
        onUpgrade: (db, oldV, newV) async {
          if (oldV < 2) await _createNew(db);
        },
      );

  static Future<List<Map<String, Object?>>> all(String table) async => (await _d).query(table);

  /// Called after every insert/update/delete (used to refresh reminders and the widget).
  static void Function()? onChange;

  static Future<int> insert(String table, Map<String, Object?> m) async {
    final r = await (await _d).insert(table, m);
    onChange?.call();
    return r;
  }

  static Future<int> update(String table, Map<String, Object?> m, int id) async {
    final r = await (await _d).update(table, m, where: 'id = ?', whereArgs: [id]);
    onChange?.call();
    return r;
  }

  static Future<int> delete(String table, int id) async {
    final r = await (await _d).delete(table, where: 'id = ?', whereArgs: [id]);
    onChange?.call();
    return r;
  }

  // ---- settings (key/value) ----
  static Future<String?> getSetting(String k) async {
    final r = await (await _d).query('settings', where: 'k = ?', whereArgs: [k]);
    if (r.isEmpty) return null;
    return r.first['v'] as String?;
  }

  static Future<void> setSetting(String k, String v) async {
    await (await _d).insert('settings', {'k': k, 'v': v}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ---- SMS messages already handled ----
  static Future<Set<int>> doneSmsIds() async {
    final r = await (await _d).query('sms_done');
    return r.map((e) => e['id'] as int).toSet();
  }

  static Future<void> markSms(int id) async {
    await (await _d).insert('sms_done', {'id': id}, conflictAlgorithm: ConflictAlgorithm.ignore);
  }
}
