import '../models/note.dart';
import 'synced_store.dart';

class NoteStore extends SyncedStore<Note> {
  NoteStore() : super('note', 'notes_v1');

  @override
  String idOf(Note item) => item.id;
  @override
  Map<String, dynamic> encode(Note item) => item.toJson();
  @override
  Note decode(Map<String, dynamic> json) => Note.fromJson(json);

  /// Neueste zuerst.
  List<Note> get notes =>
      items.values.toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  Note? byId(String id) => items[id];

  void upsert(Note note) {
    note.updatedAt = DateTime.now();
    put(note);
  }

  void delete(String id) => remove(id);
}

final noteStore = NoteStore();
