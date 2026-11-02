import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../db.dart';
import '../models.dart';
import '../sms_parser.dart';
import '../widgets.dart';

class SmsImportScreen extends StatefulWidget {
  const SmsImportScreen({super.key});

  @override
  State<SmsImportScreen> createState() => _SmsImportScreenState();
}

class _SmsImportScreenState extends State<SmsImportScreen> {
  static const _ch = MethodChannel('arcx/sms');
  List<ParsedSms> _items = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await _ch.invokeMethod<List<dynamic>>('readSms');
      final done = await AppDb.doneSmsIds();
      final list = <ParsedSms>[];
      for (final m in raw ?? <dynamic>[]) {
        final map = Map<String, dynamic>.from(m as Map);
        final id = (map['id'] as num).toInt();
        if (done.contains(id)) continue;
        final p = parseSms(
          id,
          (map['address'] as String?) ?? '',
          (map['body'] as String?) ?? '',
          DateTime.fromMillisecondsSinceEpoch((map['date'] as num).toInt()),
        );
        if (p != null) list.add(p);
      }
      if (mounted) setState(() => _items = list);
    } on PlatformException catch (e) {
      if (mounted) {
        setState(() => _error = e.code == 'DENIED'
            ? 'SMS permission was not given. Allow it in phone Settings > Apps > StudyBuddy > Permissions. '
                'If you cannot, tap the 3 dots in App info and choose "Allow restricted settings". '
                'You can also paste an SMS below.'
            : 'Could not read SMS: ${e.message}');
      }
    } on MissingPluginException {
      if (mounted) setState(() => _error = 'SMS reading is not available in this build. You can paste an SMS below.');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _paste() async {
    final c = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Paste SMS text'),
        content: TextField(
          controller: c,
          maxLines: 6,
          decoration: const InputDecoration(hintText: 'Paste the bKash / Nagad / bank message', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.content_paste_go),
            label: const Text('Paste from clipboard'),
            onPressed: () async {
              final d = await Clipboard.getData(Clipboard.kTextPlain);
              if (d?.text != null) c.text = d!.text!;
            },
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Read')),
        ],
      ),
    );
    if (text == null || text.trim().isEmpty) return;
    final p = parseSms(text.hashCode & 0x7fffffff, '', text, DateTime.now(), force: true);
    if (p == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not find an amount or transaction type in that text.')));
      }
      return;
    }
    await _ask(p);
  }

  Future<void> _ask(ParsedSms p) async {
    var cat = 'Other';
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${p.kindLabel} • ${taka(p.amount)}', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(p.body, maxLines: 4, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 14),
              Text('Where do you want to add this?', style: Theme.of(ctx).textTheme.titleSmall),
              const SizedBox(height: 8),
              const Text('If expense, pick a category:'),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                children: categories
                    .map((c) => ChoiceChip(label: Text(c), selected: cat == c, onSelected: (_) => setS(() => cat = c)))
                    .toList(),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.north_east),
                  label: const Text('Add to Expenses'),
                  onPressed: () => _apply(ctx, p, 'expense', cat),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  icon: const Icon(Icons.south_west),
                  label: const Text('Add to Income'),
                  onPressed: () => _apply(ctx, p, 'income', cat),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  icon: const Icon(Icons.savings),
                  label: const Text('Add to Savings'),
                  onPressed: () => _apply(ctx, p, 'saving', cat),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _apply(ctx, p, 'ignore', cat),
                  child: const Text('Ignore this SMS'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _apply(BuildContext ctx, ParsedSms p, String where, String cat) async {
    switch (where) {
      case 'expense':
        await AppDb.insert(
            'expenses', Expense(title: p.label, amount: p.amount, category: cat, date: p.date).toMap());
        break;
      case 'income':
        await AppDb.insert(
            'income', Income(title: p.label, amount: p.amount, source: 'Other', date: p.date).toMap());
        break;
      case 'saving':
        await AppDb.insert(
            'savings', SavingTx(isAdd: true, amount: p.amount, note: p.label, date: p.date).toMap());
        break;
    }
    await AppDb.markSms(p.id);
    if (ctx.mounted) Navigator.pop(ctx);
    if (mounted) {
      setState(() {
        _items.removeWhere((x) => x.id == p.id);
      });
    }
  }

  IconData _icon(SmsKind k) => switch (k) {
        SmsKind.cashIn => Icons.south_west,
        SmsKind.cashOut => Icons.north_east,
        SmsKind.payment => Icons.shopping_bag_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import from SMS'),
        actions: [IconButton(tooltip: 'Scan again', icon: const Icon(Icons.refresh), onPressed: _scan)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _paste,
        icon: const Icon(Icons.content_paste),
        label: const Text('Paste SMS'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.only(bottom: 90), children: [
              if (_error != null)
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: cs.errorContainer, borderRadius: BorderRadius.circular(14)),
                  child: Text(_error!, style: TextStyle(color: cs.onErrorContainer)),
                ),
              if (_error == null && _items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No new bKash / Nagad / bank messages found.\nTap a message to choose where to add it.'),
                ),
              ..._items.map((p) => ListTile(
                    leading: CircleAvatar(child: Icon(_icon(p.kind))),
                    title: Text('${p.kindLabel} • ${taka(p.amount)}'),
                    subtitle: Text('${p.sender} • ${dateText(p.date)}\n${p.body}', maxLines: 3, overflow: TextOverflow.ellipsis),
                    isThreeLine: true,
                    onTap: () => _ask(p),
                  )),
              const CopyrightFooter(),
            ]),
    );
  }
}
