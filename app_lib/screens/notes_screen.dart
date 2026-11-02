import 'package:flutter/material.dart';
import '../db.dart';
import '../models.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  List<Note> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = (await AppDb.all('notes')).map(Note.fromMap).toList()
      ..sort((a, b) => a.pinned == b.pinned ? (b.id ?? 0).compareTo(a.id ?? 0) : (a.pinned ? -1 : 1));
    if (mounted) setState(() => _items = list);
  }

  Future<void> _open([Note? n]) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => NoteEditor(note: n)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Important Notes')),
      floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _open(), icon: const Icon(Icons.add), label: const Text('Note')),
      body: _items.isEmpty
          ? const Center(child: Text('No notes yet. Tap Note!'))
          : GridView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.9),
              itemCount: _items.length,
              itemBuilder: (_, i) {
                final n = _items[i];
                final colored = n.color != 0;
                final fg = colored ? Colors.black87 : cs.onSurface;
                return InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => _open(n),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colored ? Color(n.color) : cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(
                            child: Text(n.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: fg))),
                        if (n.pinned) Icon(Icons.push_pin, size: 18, color: fg),
                      ]),
                      const SizedBox(height: 6),
                      Expanded(
                          child: Text(n.body,
                              overflow: TextOverflow.fade, style: TextStyle(color: fg))),
                    ]),
                  ),
                );
              },
            ),
    );
  }
}

class NoteEditor extends StatefulWidget {
  final Note? note;
  const NoteEditor({super.key, this.note});

  @override
  State<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<NoteEditor> {
  late final _title = TextEditingController(text: widget.note?.title);
  late final _body = TextEditingController(text: widget.note?.body);
  late int _color = widget.note?.color ?? 0;
  late bool _pinned = widget.note?.pinned ?? false;

  Future<void> _save() async {
    if (_title.text.trim().isEmpty && _body.text.trim().isEmpty) return;
    final n = Note(
      id: widget.note?.id,
      title: _title.text.trim().isEmpty ? 'Untitled' : _title.text.trim(),
      body: _body.text,
      color: _color,
      pinned: _pinned,
    );
    n.id == null ? await AppDb.insert('notes', n.toMap()) : await AppDb.update('notes', n.toMap(), n.id!);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _save(); // auto-save on back
        if (context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.note == null ? 'New note' : 'Edit note'),
          actions: [
            IconButton(
              icon: Icon(_pinned ? Icons.push_pin : Icons.push_pin_outlined),
              onPressed: () => setState(() => _pinned = !_pinned),
            ),
            if (widget.note != null)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  await AppDb.delete('notes', widget.note!.id!);
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            TextField(
              controller: _title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(hintText: 'Title', border: InputBorder.none),
            ),
            Expanded(
              child: TextField(
                controller: _body,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(hintText: 'Write your note...', border: InputBorder.none),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: noteColors
                  .map((c) => GestureDetector(
                        onTap: () => setState(() => _color = c),
                        child: Container(
                          width: 36,
                          height: 36,
                          margin: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: c == 0 ? Theme.of(context).colorScheme.surfaceContainerHighest : Color(c),
                            border: Border.all(
                                width: _color == c ? 3 : 1,
                                color: _color == c ? Theme.of(context).colorScheme.primary : Colors.grey),
                          ),
                          child: c == 0 ? const Icon(Icons.block, size: 16) : null,
                        ),
                      ))
                  .toList(),
            ),
          ]),
        ),
      ),
    );
  }
}
