import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/chore_store.dart';
import '../data/note_store.dart';
import '../data/secret_store.dart';
import '../data/synced_store.dart';
import '../data/task_store.dart';

const _url = 'https://fhilcpvkwppttywkjgep.supabase.co';
const _publishableKey = 'sb_publishable_1Z4D45spOcUVAtnHiblVOw_qoG_o-dT';
const _cursorKey = 'sync_cursor';

/// Abgleich aller Daten mit Supabase (Handy ↔ PC ↔ Claude).
class Sync extends ChangeNotifier {
  final List<SyncedStore> _stores = [taskStore, choreStore, noteStore, secretStore];

  bool _ready = false;
  bool _running = false;
  bool _again = false;
  Timer? _debounce;
  Timer? _poll;

  DateTime? lastSync;
  String? lastError;

  SupabaseClient get _db => Supabase.instance.client;

  User? get user => _ready ? _db.auth.currentUser : null;
  bool get signedIn => user != null;
  bool get busy => _running;

  Future<void> init() async {
    try {
      await Supabase.initialize(url: _url, anonKey: _publishableKey);
      _ready = true;
    } catch (e) {
      lastError = 'Start fehlgeschlagen: $e';
      notifyListeners();
      return;
    }
    SyncedStore.onLocalChange = _scheduleSoon;
    _db.auth.onAuthStateChange.listen((_) => notifyListeners());
    if (signedIn) {
      startPolling();
      syncNow();
    }
  }

  // ---- Konto ----

  /// Gibt `true` zurück, wenn direkt angemeldet; `false`, wenn erst die
  /// Bestätigungsmail angeklickt werden muss.
  Future<bool> signUp(String email, String password) async {
    final res = await _db.auth.signUp(email: email, password: password);
    if (res.session == null) return false;
    await _afterSignIn();
    return true;
  }

  Future<void> signIn(String email, String password) async {
    await _db.auth.signInWithPassword(email: email, password: password);
    await _afterSignIn();
  }

  Future<void> _afterSignIn() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cursorKey); // alles vom Server holen
    for (final s in _stores) {
      s.markAllDirty(); // und alles Lokale hochladen
    }
    startPolling();
    await syncNow();
  }

  Future<void> signOut() async {
    stopPolling();
    await _db.auth.signOut();
    lastSync = null;
    notifyListeners();
  }

  // ---- Abgleich ----

  /// Alle 60 Sekunden nachsehen, ob es Neues gibt (solange die App offen ist).
  void startPolling() {
    _poll?.cancel();
    if (!signedIn) return;
    _poll = Timer.periodic(const Duration(seconds: 60), (_) => syncNow());
  }

  void stopPolling() {
    _poll?.cancel();
    _poll = null;
  }

  void _scheduleSoon() {
    if (!signedIn) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), syncNow);
  }

  Future<void> syncNow() async {
    if (!signedIn) return;
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    notifyListeners();
    try {
      do {
        _again = false;
        await _push();
        await _pull();
      } while (_again);
      lastSync = DateTime.now();
      lastError = null;
    } catch (e) {
      lastError = _describe(e);
      debugPrint('Summer sync: $e');
    } finally {
      _running = false;
      notifyListeners();
    }
  }

  Future<void> _push() async {
    final uid = user!.id;
    for (final store in _stores) {
      if (!store.hasDirty) continue;
      final ids = store.takeDirty();
      try {
        final rows = [
          for (final id in ids)
            {
              'user_id': uid,
              'id': id,
              'kind': store.kind,
              'data': store.rowData(id),
              'deleted': store.rowData(id) == null,
            }
        ];
        for (var i = 0; i < rows.length; i += 200) {
          final end = i + 200 < rows.length ? i + 200 : rows.length;
          await _db.from('items').upsert(rows.sublist(i, end));
        }
      } catch (_) {
        store.restoreDirty(ids);
        rethrow;
      }
    }
  }

  Future<void> _pull() async {
    final prefs = await SharedPreferences.getInstance();
    final cursor = prefs.getString(_cursorKey);
    var query = _db.from('items').select('id, kind, data, deleted, updated_at');
    if (cursor != null) {
      // Kleine Überlappung, damit gleichzeitige Änderungen nicht verloren gehen.
      final since = DateTime.parse(cursor).subtract(const Duration(seconds: 10));
      query = query.gt('updated_at', since.toUtc().toIso8601String());
    }
    final rows = await query.order('updated_at');
    if (rows.isEmpty) return;

    final changed = <SyncedStore>{};
    for (final r in rows) {
      final store = _stores.where((s) => s.kind == r['kind']).firstOrNull;
      if (store == null) continue;
      final deleted = r['deleted'] == true || r['data'] == null;
      final data = deleted ? null : Map<String, dynamic>.from(r['data'] as Map);
      if (store.applyRemote(r['id'] as String, data)) changed.add(store);
    }
    for (final s in changed) {
      s.finishRemote();
    }
    await prefs.setString(_cursorKey, rows.last['updated_at'] as String);
  }

  static String _describe(Object e) {
    if (e is AuthException) return e.message;
    if (e is PostgrestException) return e.message;
    final s = e.toString();
    if (s.contains('SocketException') || s.contains('ClientException')) {
      return 'Keine Internetverbindung';
    }
    return s;
  }
}

final sync = Sync();
