enum SmsKind { cashIn, cashOut, payment }

class ParsedSms {
  final int id;
  final String sender;
  final String body;
  final DateTime date;
  final double amount;
  final SmsKind kind;
  ParsedSms(this.id, this.sender, this.body, this.date, this.amount, this.kind);

  String get kindLabel => switch (kind) {
        SmsKind.cashIn => 'Cash In',
        SmsKind.cashOut => 'Cash Out',
        SmsKind.payment => 'Payment',
      };

  String get label => sender.isEmpty ? kindLabel : '$kindLabel • $sender';
}

const _senders = ['bkash', 'nagad', 'rocket', 'upay', 'mcash', 'tap', 'bank', '16216', '16167', '16269'];
final _amountRe = RegExp(r'(?:tk|bdt|৳)\.?\s*:?\s*([\d,]+(?:\.\d+)?)', caseSensitive: false);

/// Returns null if the message does not look like a mobile banking transaction.
/// [force] is used for pasted text (skips the sender check).
ParsedSms? parseSms(int id, String sender, String body, DateTime date, {bool force = false}) {
  final s = sender.toLowerCase();
  final b = body.toLowerCase();

  final known = _senders.any((x) => s.contains(x)) ||
      b.contains('trxid') ||
      b.contains('txnid') ||
      b.contains('balance');
  if (!force && !known) return null;

  final m = _amountRe.firstMatch(body);
  if (m == null) return null;
  final amount = double.tryParse(m.group(1)!.replaceAll(',', ''));
  if (amount == null || amount <= 0) return null;

  SmsKind? kind;
  if (b.contains('cash out') || b.contains('cashout') || b.contains('withdraw')) {
    kind = SmsKind.cashOut;
  } else if (b.contains('cash in') ||
      b.contains('cash-in') ||
      b.contains('received') ||
      b.contains('credited') ||
      b.contains('deposit') ||
      b.contains('add money')) {
    kind = SmsKind.cashIn;
  } else if (b.contains('payment') ||
      b.contains('paid') ||
      b.contains('purchase') ||
      b.contains('send money') ||
      b.contains('sent') ||
      b.contains('debited') ||
      b.contains('bill') ||
      b.contains('recharge') ||
      b.contains('transfer')) {
    kind = SmsKind.payment;
  }
  if (kind == null) return null;
  return ParsedSms(id, sender, body, date, amount, kind);
}
