import '../models/chore.dart';
import 'synced_store.dart';

class ChoreStore extends SyncedStore<Chore> {
  ChoreStore() : super('chore', 'chores_v1');

  @override
  String idOf(Chore item) => item.id;
  @override
  Map<String, dynamic> encode(Chore item) => item.toJson();
  @override
  Chore decode(Map<String, dynamic> json) => Chore.fromJson(json);

  /// Offene Aufgaben, die älteste zuerst.
  List<Chore> get open =>
      items.values.where((c) => !c.isDone).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  /// Erledigte Aufgaben, die neueste zuerst.
  List<Chore> get done =>
      items.values.where((c) => c.isDone).toList()
        ..sort((a, b) => b.doneAt!.compareTo(a.doneAt!));

  void upsert(Chore chore) => put(chore);

  void delete(String id) => remove(id);

  void toggleDone(Chore chore) {
    chore.doneAt = chore.isDone ? null : DateTime.now();
    touched(chore.id);
  }

  /// Keine Erinnerungen mehr bis morgen früh.
  void snoozeToday(Chore chore) {
    final now = DateTime.now();
    chore.snoozedUntil = DateTime(now.year, now.month, now.day + 1);
    touched(chore.id);
  }
}

final choreStore = ChoreStore();
