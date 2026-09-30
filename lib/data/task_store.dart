import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/task.dart';

class TaskStore extends ChangeNotifier {
  static const _key = 'tasks_v1';

  final List<Task> _tasks = [];

  List<Task> get tasks => List.unmodifiable(_tasks);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      final list = jsonDecode(raw) as List;
      _tasks
        ..clear()
        ..addAll(list.map((e) => Task.fromJson(e as Map<String, dynamic>)));
    }
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(_tasks.map((t) => t.toJson()).toList()));
  }

  void upsert(Task task) {
    final i = _tasks.indexWhere((t) => t.id == task.id);
    if (i >= 0) {
      _tasks[i] = task;
    } else {
      _tasks.add(task);
    }
    notifyListeners();
    _save();
  }

  void delete(String id) {
    _tasks.removeWhere((t) => t.id == id);
    notifyListeners();
    _save();
  }

  void toggleDone(Task task, DateTime day) {
    final key = dateKey(dateOnly(day));
    if (!task.doneDates.remove(key)) task.doneDates.add(key);
    notifyListeners();
    _save();
  }

  List<Task> tasksOn(DateTime day) =>
      _tasks.where((t) => t.occursOn(day)).toList()..sort(_byTime);

  /// Verpasste, noch offene Termine vor [today].
  List<(Task, DateTime)> overdue(DateTime today) {
    final result = <(Task, DateTime)>[];
    for (final t in _tasks) {
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
