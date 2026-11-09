import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/settings.dart';
import 'voice_input.dart';

/// Hört bei offener App ständig mit und reagiert, sobald „Summer“ fällt.
///
/// Die Spracherkennung von Android endet nach jeder Pause; deshalb wird sie
/// immer wieder neu gestartet.
class WakeListener {
  /// Wird mit dem Rest des Satzes aufgerufen („Summer, morgen Zahnarzt“ →
  /// „morgen Zahnarzt“, nur „Summer“ → leerer Text).
  void Function(String rest)? onWake;

  bool _foreground = true;
  bool _blocked = false; // Sprach-Fenster offen
  bool _listening = false;
  Timer? _restart;
  Timer? _watchdog;

  // Google schreibt den Namen oft als deutsches „Sommer“.
  static final _name = RegExp(r'\b(summer|sommer|summa|samma)\b[\s,.!:]*',
      caseSensitive: false);

  bool get _wanted =>
      VoiceInput.supported &&
      settings.wakeMode != WakeMode.off &&
      _foreground &&
      !_blocked;

  void init() => settings.addListener(_update);

  void setForeground(bool value) {
    _foreground = value;
    _update();
  }

  /// Während das Sprach-Fenster offen ist, nicht mithören.
  void block() {
    _blocked = true;
    _stop();
  }

  void unblock() {
    _blocked = false;
    _scheduleRestart(const Duration(milliseconds: 800));
  }

  void _update() {
    if (_wanted) {
      if (!_listening) _scheduleRestart(Duration.zero);
    } else {
      _stop();
    }
  }

  void _stop() {
    _restart?.cancel();
    _watchdog?.cancel();
    if (_listening) {
      _listening = false;
      voiceInput.cancel();
    }
  }

  void _scheduleRestart(Duration delay) {
    _restart?.cancel();
    _restart = Timer(delay, _listen);
  }

  Future<void> _listen() async {
    if (!_wanted || _listening) return;
    if (!await voiceInput.init()) return;
    if (!_wanted) return;
    _listening = true;
    // Falls die Erkennung hängen bleibt (z. B. von außen abgebrochen): neu starten.
    _watchdog?.cancel();
    _watchdog = Timer(const Duration(seconds: 40), () {
      if (!_listening) return;
      _listening = false;
      voiceInput.cancel();
      _scheduleRestart(const Duration(milliseconds: 500));
    });
    try {
      await voiceInput.listen(
        onResult: (text, isFinal) {
          if (!_listening) return;
          final m = _name.firstMatch(text);
          if (m == null || !isFinal) return;
          _listening = false;
          voiceInput.cancel();
          onWake?.call(text.substring(m.end).trim());
        },
        onStopped: () {
          if (!_listening) return;
          _listening = false;
          _scheduleRestart(const Duration(milliseconds: 300));
        },
        onError: (msg) {
          debugPrint('Summer wake: $msg');
          _listening = false;
          _scheduleRestart(msg.contains('busy')
              ? const Duration(seconds: 2)
              : const Duration(milliseconds: 500));
        },
      );
    } catch (e) {
      _listening = false;
      _scheduleRestart(const Duration(seconds: 3));
    }
  }
}

final wakeListener = WakeListener();
