import 'package:flutter/material.dart';

import '../data/note_store.dart';
import '../models/note.dart';
import '../models/task.dart' show newId;
import '../util/format.dart';

class NotesScreen extends StatelessWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: noteStore,
      builder: (context, _) {
        final notes = noteStore.notes;
        return Scaffold(
          appBar: AppBar(title: const Text('Notizen')),
          floatingActionButton: FloatingActionButton(
            heroTag: null,
            onPressed: () => openNote(context, null),
            child: const Icon(Icons.add),
          ),
          body: notes.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Noch keine Notizen.\nTippe auf +, um eine anzulegen.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 88),
                  itemCount: notes.length,
                  itemBuilder: (context, i) {
                    final n = notes[i];
                    final preview = n.title.trim().isEmpty
                        ? n.body.trim().split('\n').skip(1).join(' ')
                        : n.body.trim().replaceAll('\n', ' ');
                    return Card(
                      child: ListTile(
                        title: Text(n.heading,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          preview.isEmpty
                              ? formatWhen(n.updatedAt)
                              : '${formatWhen(n.updatedAt)} · $preview',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => openNote(context, n),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}

void openNote(BuildContext context, Note? note) {
  Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => NoteEditScreen(note: note)));
}

class NoteEditScreen extends StatefulWidget {
  const NoteEditScreen({super.key, this.note});

  final Note? note;

  @override
  State<NoteEditScreen> createState() => _NoteEditScreenState();
}

class _NoteEditScreenState extends State<NoteEditScreen> {
  late final String _id = widget.note?.id ?? newId();
  late final _title = TextEditingController(text: widget.note?.title ?? '');
  late final _body = TextEditingController(text: widget.note?.body ?? '');
  bool _deleted = false;

  @override
  void dispose() {
    final title = _title.text;
    final body = _body.text;
    // Nicht während des Abbaus speichern (Baum ist gesperrt) – kurz danach.
    if (!_deleted) Future.microtask(() => _save(title, body));
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  /// Speichert automatisch beim Verlassen – nur wenn sich etwas geändert hat.
  void _save(String title, String body) {
    final existing = noteStore.byId(_id);
    if (existing == null) {
      if (title.trim().isEmpty && body.trim().isEmpty) return;
      noteStore.upsert(Note(id: _id, title: title, body: body));
    } else if (existing.title != title || existing.body != body) {
      noteStore.upsert(existing
        ..title = title
        ..body = body);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Notiz löschen?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Löschen')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    _deleted = true;
    if (noteStore.byId(_id) != null) noteStore.delete(_id);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.note == null ? 'Neue Notiz' : 'Notiz'),
        actions: [
          IconButton(
            tooltip: 'Löschen',
            icon: const Icon(Icons.delete_outline),
            onPressed: _delete,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          children: [
            TextField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              style: Theme.of(context).textTheme.titleLarge,
              decoration: const InputDecoration(
                  hintText: 'Titel', border: InputBorder.none),
            ),
            Expanded(
              child: TextField(
                controller: _body,
                autofocus: widget.note == null,
                textCapitalization: TextCapitalization.sentences,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                    hintText: 'Notiz …', border: InputBorder.none),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
