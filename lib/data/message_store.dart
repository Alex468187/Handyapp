import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Eine mitgelesene Nachricht (WhatsApp) oder Mail (Gmail).
class Message {
  Message({
    required this.id,
    required this.source,
    required this.chat,
    required this.sender,
    required this.text,
    required this.time,
    this.account,
    this.outgoing = false,
  });

  final String id;
  final String source; // whatsapp | gmail
  final String chat; // Chat-Name bzw. Absender
  final String sender;
  final String text;
  final DateTime time;
  final String? account; // Gmail-Konto
  final bool outgoing;

  String get chatKey => '$source|$chat';
  bool get isMail => source == 'gmail';

  factory Message.fromJson(Map<String, dynamic> j) => Message(
        id: j['id'] as String,
        source: j['source'] as String,
        chat: j['chat'] as String,
        sender: (j['sender'] ?? j['chat']) as String,
        text: j['text'] as String,
        time: DateTime.fromMillisecondsSinceEpoch((j['time'] as num).toInt()),
        account: j['account'] as String?,
        outgoing: j['out'] == true,
      );
}

/// Ein Chat bzw. Mail-Absender mit seinen Nachrichten (älteste zuerst).
class Conversation {
  Conversation(this.key, this.source, this.name);
  final String key;
  final String source;
  final String name;
  final List<Message> messages = [];

  Message get last => messages.last;
  bool get isMail => source == 'gmail';
  String get package => isMail ? 'com.google.android.gm' : 'com.whatsapp';
}

/// Nachrichten von WhatsApp/Gmail, die der Android-Dienst mitschreibt.
class MessageStore extends ChangeNotifier {
  static const _channel = MethodChannel('summer/messages');
  static const _importantKey = 'msg_important';
  static const _hiddenAccountsKey = 'msg_hidden_accounts';
  static const _readKey = 'msg_read';

  static bool get supported => Platform.isAndroid;

  bool enabled = false;
  List<Conversation> conversations = []; // neueste zuerst
  Set<String> important = {};
  Set<String> hiddenAccounts = {};
  Map<String, int> _readUntil = {};
  Set<String> accounts = {};

  String? _path;
  int _lastLength = -1;
  Timer? _poll;

  Future<void> init() async {
    if (!supported) return;
    final prefs = await SharedPreferences.getInstance();
    important = (prefs.getStringList(_importantKey) ?? const []).toSet();
    hiddenAccounts = (prefs.getStringList(_hiddenAccountsKey) ?? const []).toSet();
    final read = prefs.getString(_readKey);
    if (read != null) {
      _readUntil = (jsonDecode(read) as Map).map(
          (k, v) => MapEntry(k as String, (v as num).toInt()));
    }
    try {
      _path = await _channel.invokeMethod<String>('filePath');
    } catch (_) {}
    await refresh();
  }

  /// Solange die App offen ist, alle 3 Sekunden nach Neuem sehen.
  void startPolling() {
    if (!supported) return;
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 3), (_) => refresh());
    refresh();
  }

  void stopPolling() {
    _poll?.cancel();
    _poll = null;
  }

  Future<void> refresh() async {
    if (!supported) return;
    try {
      final on = await _channel.invokeMethod<bool>('isEnabled') ?? false;
      if (on != enabled) {
        enabled = on;
        notifyListeners();
      }
    } catch (_) {}
    final path = _path;
    if (path == null) return;
    final file = File(path);
    if (!await file.exists()) return;
    final length = await file.length();
    if (length == _lastLength) return;
    _lastLength = length;

    final byId = <String, Message>{};
    for (final line in await file.readAsLines()) {
      if (line.trim().isEmpty) continue;
      try {
        final m = Message.fromJson(jsonDecode(line) as Map<String, dynamic>);
        byId[m.id] = m;
      } catch (_) {}
    }
    final convs = <String, Conversation>{};
    final accs = <String>{};
    final all = byId.values.toList()..sort((a, b) => a.time.compareTo(b.time));
    for (final m in all) {
      if (m.account != null) accs.add(m.account!);
      convs.putIfAbsent(m.chatKey, () => Conversation(m.chatKey, m.source, m.chat))
          .messages
          .add(m);
    }
    conversations = convs.values.toList()
      ..sort((a, b) => b.last.time.compareTo(a.last.time));
    accounts = accs;
    notifyListeners();
  }

  /// Gefiltert nach ausgeblendeten Gmail-Konten und optional nur Wichtige.
  List<Conversation> visible({required bool onlyImportant}) => conversations
      .where((c) => !onlyImportant || important.contains(c.key))
      .where((c) => !(c.isMail &&
          c.messages.every((m) => hiddenAccounts.contains(m.account))))
      .toList();

  int unread(Conversation c) {
    final until = _readUntil[c.key] ?? 0;
    return c.messages
        .where((m) => !m.outgoing && m.time.millisecondsSinceEpoch > until)
        .length;
  }

  Future<void> markRead(Conversation c) async {
    _readUntil[c.key] = c.last.time.millisecondsSinceEpoch;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_readKey, jsonEncode(_readUntil));
  }

  Future<void> toggleImportant(String key) async {
    if (!important.remove(key)) important.add(key);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_importantKey, important.toList());
  }

  Future<void> setAccountHidden(String account, bool hidden) async {
    if (hidden) {
      hiddenAccounts.add(account);
    } else {
      hiddenAccounts.remove(account);
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_hiddenAccountsKey, hiddenAccounts.toList());
  }

  Future<void> openSettings() => _channel.invokeMethod('openSettings');
  Future<void> openAppInfo() => _channel.invokeMethod('openAppInfo');

  Future<bool> canReply(Conversation c) async =>
      await _channel.invokeMethod<bool>('canReply', {'chat': c.key}) ?? false;

  Future<bool> reply(Conversation c, String text) async {
    final ok = await _channel
            .invokeMethod<bool>('reply', {'chat': c.key, 'text': text}) ??
        false;
    if (ok) {
      _lastLength = -1;
      await refresh();
    }
    return ok;
  }

  Future<bool> openInApp(Conversation c) async =>
      await _channel.invokeMethod<bool>(
          'open', {'chat': c.key, 'package': c.package}) ??
      false;
}

final messageStore = MessageStore();
