import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/chore.dart';

class ChoreStore extends ChangeNotifier {
  static const _key = 'chores_v1';

  final List<Chore> _chores = [];

  /// Offene Aufgaben, die älteste zuerst.
  List<Chore> get open =>
      _chores.where((c) => !c.isDone).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  /// Erledigte Aufgaben, die neueste zuerst.
  List<Chore> get done =>
      _chores.where((c) => c.isDone).toList()
        ..sort((a, b) => b.doneAt!.compareTo(a.doneAt!));

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      final list = jsonDecode(raw) as List;
      _chores
        ..clear()
        ..addAll(list.map((e) => Chore.fromJson(e as Map<String, dynamic>)));
    }
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(_chores.map((c) => c.toJson()).toList()));
  }

  void _changed() {
    notifyListeners();
    _save();
  }

  void upsert(Chore chore) {
    final i = _chores.indexWhere((c) => c.id == chore.id);
    if (i >= 0) {
      _chores[i] = chore;
    } else {
      _chores.add(chore);
    }
    _changed();
  }

  void delete(String id) {
    _chores.removeWhere((c) => c.id == id);
    _changed();
  }

  void toggleDone(Chore chore) {
    chore.doneAt = chore.isDone ? null : DateTime.now();
    _changed();
  }

  /// Keine Erinnerungen mehr bis morgen früh.
  void snoozeToday(Chore chore) {
    final now = DateTime.now();
    chore.snoozedUntil = DateTime(now.year, now.month, now.day + 1);
    _changed();
  }
}

final choreStore = ChoreStore();
