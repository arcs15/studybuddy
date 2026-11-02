import 'package:intl/intl.dart';

const categories = ['Food', 'Transport', 'Books', 'Fees', 'Rent', 'Bills', 'Health', 'Lend', 'Fun', 'Other'];
const incomeSources = ['Salary', 'Tuition', 'Family', 'Freelance', 'Gift', 'Loan', 'Other'];

/// 0 = default card color, others are pastel note colors.
const noteColors = [0, 0xFFFFF59D, 0xFFA5D6A7, 0xFF90CAF9, 0xFFF48FB1, 0xFFCE93D8];

String taka(double v) => '৳${NumberFormat('#,##0.##').format(v)}';
String dateText(DateTime d) => DateFormat('d MMM yyyy').format(d);
String monthShort(DateTime d) => DateFormat('MMM').format(d);
bool sameMonth(DateTime a, DateTime b) => a.year == b.year && a.month == b.month;

class Expense {
  int? id;
  String title;
  double amount;
  String category;
  DateTime date;
  Expense({this.id, required this.title, required this.amount, required this.category, required this.date});

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'title': title,
        'amount': amount,
        'category': category,
        'date': date.millisecondsSinceEpoch,
      };

  factory Expense.fromMap(Map<String, Object?> m) => Expense(
        id: m['id'] as int,
        title: m['title'] as String,
        amount: (m['amount'] as num).toDouble(),
        category: m['category'] as String,
        date: DateTime.fromMillisecondsSinceEpoch(m['date'] as int),
      );
}

class Income {
  int? id;
  String title;
  double amount;
  String source;
  DateTime date;
  Income({this.id, required this.title, required this.amount, required this.source, required this.date});

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'title': title,
        'amount': amount,
        'source': source,
        'date': date.millisecondsSinceEpoch,
      };

  factory Income.fromMap(Map<String, Object?> m) => Income(
        id: m['id'] as int,
        title: m['title'] as String,
        amount: (m['amount'] as num).toDouble(),
        source: m['source'] as String,
        date: DateTime.fromMillisecondsSinceEpoch(m['date'] as int),
      );
}

class Loan {
  int? id;
  String name;
  double amount;
  DateTime due;
  String note;
  bool paid;
  Loan({this.id, required this.name, required this.amount, required this.due, this.note = '', this.paid = false});

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'amount': amount,
        'due': due.millisecondsSinceEpoch,
        'note': note,
        'paid': paid ? 1 : 0,
      };

  factory Loan.fromMap(Map<String, Object?> m) => Loan(
        id: m['id'] as int,
        name: m['name'] as String,
        amount: (m['amount'] as num).toDouble(),
        due: DateTime.fromMillisecondsSinceEpoch(m['due'] as int),
        note: (m['note'] as String?) ?? '',
        paid: (m['paid'] as int) == 1,
      );
}

class SavingTx {
  int? id;
  bool isAdd;
  double amount;
  String note;
  DateTime date;
  SavingTx({this.id, required this.isAdd, required this.amount, this.note = '', required this.date});

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'is_add': isAdd ? 1 : 0,
        'amount': amount,
        'note': note,
        'date': date.millisecondsSinceEpoch,
      };

  factory SavingTx.fromMap(Map<String, Object?> m) => SavingTx(
        id: m['id'] as int,
        isAdd: (m['is_add'] as int) == 1,
        amount: (m['amount'] as num).toDouble(),
        note: (m['note'] as String?) ?? '',
        date: DateTime.fromMillisecondsSinceEpoch(m['date'] as int),
      );
}

class Note {
  int? id;
  String title;
  String body;
  int color;
  bool pinned;
  Note({this.id, required this.title, required this.body, this.color = 0, this.pinned = false});

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'title': title,
        'body': body,
        'color': color,
        'pinned': pinned ? 1 : 0,
      };

  factory Note.fromMap(Map<String, Object?> m) => Note(
        id: m['id'] as int,
        title: m['title'] as String,
        body: m['body'] as String,
        color: m['color'] as int,
        pinned: (m['pinned'] as int) == 1,
      );
}

class Task {
  int? id;
  String title;
  DateTime? due;
  bool done;
  Task({this.id, required this.title, this.due, this.done = false});

  bool get overdue => !done && due != null && due!.isBefore(DateTime.now().subtract(const Duration(days: 1)));

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'title': title,
        'due': due?.millisecondsSinceEpoch,
        'done': done ? 1 : 0,
      };

  factory Task.fromMap(Map<String, Object?> m) => Task(
        id: m['id'] as int,
        title: m['title'] as String,
        due: m['due'] == null ? null : DateTime.fromMillisecondsSinceEpoch(m['due'] as int),
        done: (m['done'] as int) == 1,
      );
}
