import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lokale Liste, die sich mit Supabase abgleichen lässt.
///
/// Jede lokale Änderung merkt sich die betroffene ID als „dirty“; der
/// Abgleich schickt diese hoch und holt danach Neues vom Server.
abstract class SyncedStore<T> extends ChangeNotifier {
  SyncedStore(this.kind, this._prefsKey);

  /// Typ in der Datenbank-Spalte `kind` (task, chore, note).
  final String kind;
  final String _prefsKey;

  /// Wird bei jeder lokalen Änderung aufgerufen (vom Abgleich gesetzt).
  static VoidCallback? onLocalChange;

  @protected
  final Map<String, T> items = {};
  final Set<String> _dirty = {};

  String idOf(T item);
  Map<String, dynamic> encode(T item);
  T decode(Map<String, dynamic> json);

  String get _dirtyKey => '$_prefsKey.dirty';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    items.clear();
    if (raw != null) {
      for (final e in jsonDecode(raw) as List) {
        final item = decode(e as Map<String, dynamic>);
        items[idOf(item)] = item;
      }
    }
    _dirty
      ..clear()
      ..addAll(prefs.getStringList(_dirtyKey) ?? const []);
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _prefsKey, jsonEncode(items.values.map(encode).toList()));
    await prefs.setStringList(_dirtyKey, _dirty.toList());
  }

  /// Ansichten neu zeichnen (z. B. wenn ein neuer Tag begonnen hat).
  void refresh() => notifyListeners();

  @protected
  void put(T item) {
    items[idOf(item)] = item;
    touched(idOf(item));
  }

  @protected
  void remove(String id) {
    items.remove(id);
    touched(id);
  }

  /// Ein Eintrag wurde lokal geändert (auch bei Änderungen am Objekt selbst).
  @protected
  void touched(String id) {
    _dirty.add(id);
    notifyListeners();
    _save();
    onLocalChange?.call();
  }

  // ---- Für den Abgleich ----

  bool get hasDirty => _dirty.isNotEmpty;

  /// Holt alle geänderten IDs ab und vergisst sie (bei Fehler: [restoreDirty]).
  Set<String> takeDirty() {
    final ids = _dirty.toSet();
    _dirty.clear();
    _save();
    return ids;
  }

  void restoreDirty(Iterable<String> ids) {
    _dirty.addAll(ids);
    _save();
  }

  /// Daten eines Eintrags für den Server, `null` = gelöscht.
  Map<String, dynamic>? rowData(String id) {
    final item = items[id];
    return item == null ? null : encode(item);
  }

  /// Nach der Anmeldung: alles Lokale einmal hochladen.
  void markAllDirty() {
    _dirty.addAll(items.keys);
    _save();
  }

  /// Änderung vom Server übernehmen. Lokal ungespeicherte Änderungen gewinnen.
  /// Gibt `true` zurück, wenn sich etwas geändert hat.
  bool applyRemote(String id, Map<String, dynamic>? data) {
    if (_dirty.contains(id)) return false;
    if (data == null) return items.remove(id) != null;
    try {
      items[id] = decode({...data, 'id': id});
      return true;
    } catch (e) {
      debugPrint('Summer: Eintrag $id unlesbar: $e');
      return false;
    }
  }

  void finishRemote() {
    notifyListeners();
    _save();
  }
}
