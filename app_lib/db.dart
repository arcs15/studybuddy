import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Tiny local SQLite helper. All data stays on the phone.
class AppDb {
  static Database? _db;

  static Future<Database> get _d async => _db ??= await openDatabase(
        p.join(await getDatabasesPath(), 'studybuddy.db'),
        version: 1,
        onCreate: (db, v) async {
          await db.execute(
              'CREATE TABLE expenses(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, amount REAL, category TEXT, date INTEGER)');
          await db.execute(
              'CREATE TABLE notes(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, body TEXT, color INTEGER, pinned INTEGER)');
          await db.execute(
              'CREATE TABLE tasks(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, due INTEGER, done INTEGER)');
        },
      );

  static Future<List<Map<String, Object?>>> all(String table) async => (await _d).query(table);

  static Future<int> insert(String table, Map<String, Object?> m) async => (await _d).insert(table, m);

  static Future<int> update(String table, Map<String, Object?> m, int id) async =>
      (await _d).update(table, m, where: 'id = ?', whereArgs: [id]);

  static Future<int> delete(String table, int id) async =>
      (await _d).delete(table, where: 'id = ?', whereArgs: [id]);
}
