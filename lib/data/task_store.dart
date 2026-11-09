import '../models/task.dart';
import 'synced_store.dart';

class TaskStore extends SyncedStore<Task> {
  TaskStore() : super('task', 'tasks_v1');

  @override
  String idOf(Task item) => item.id;
  @override
  Map<String, dynamic> encode(Task item) => item.toJson();
  @override
  Task decode(Map<String, dynamic> json) => Task.fromJson(json);

  List<Task> get tasks => List.unmodifiable(items.values);

  void upsert(Task task) => put(task);

  void delete(String id) => remove(id);

  void toggleDone(Task task, DateTime day) {
    final key = dateKey(dateOnly(day));
    if (!task.doneDates.remove(key)) task.doneDates.add(key);
    touched(task.id);
  }

  List<Task> tasksOn(DateTime day) =>
      items.values.where((t) => t.occursOn(day)).toList()..sort(_byTime);

  /// Verpasste, noch offene Termine vor [today].
  List<(Task, DateTime)> overdue(DateTime today) {
    final result = <(Task, DateTime)>[];
    for (final t in items.values) {
      final d = t.overdueDate(today);
      if (d != null) result.add((t, d));
    }
    result.sort((a, b) => a.$2.compareTo(b.$2));
    return result;
  }

  static int _byTime(Task a, Task b) {
    final am = a.minutes ?? -1;
    final bm = b.minutes ?? -1;
    if (am != bm) return am.compareTo(bm);
    return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  }
}

final taskStore = TaskStore();
