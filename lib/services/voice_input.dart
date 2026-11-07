import 'dart:io';

import 'package:speech_to_text/speech_to_text.dart';

/// Spracherkennung über Android (Google). Auf Windows nicht verfügbar.
class VoiceInput {
  final _stt = SpeechToText();
  bool _available = false;

  void Function()? _onStopped;
  void Function(String message)? _onError;

  static bool get supported => Platform.isAndroid;

  Future<bool> init() async {
    if (!supported) return false;
    if (_available) return true;
    try {
      _available = await _stt.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') _onStopped?.call();
        },
        onError: (error) {
          _onError?.call(error.errorMsg);
          _onStopped?.call();
        },
      );
    } catch (_) {
      _available = false;
    }
    return _available;
  }

  Future<void> listen({
    required void Function(String text, bool isFinal) onResult,
    required void Function() onStopped,
    required void Function(String message) onError,
  }) async {
    _onStopped = onStopped;
    _onError = onError;
    await _stt.listen(
      onResult: (r) => onResult(r.recognizedWords, r.finalResult),
      localeId: 'de_DE',
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      listenOptions: SpeechListenOptions(
        partialResults: true,
        listenMode: ListenMode.dictation,
        cancelOnError: true,
      ),
    );
  }

  Future<void> stop() => _stt.stop();

  Future<void> cancel() async {
    _onStopped = null;
    _onError = null;
    await _stt.cancel();
  }
}

final voiceInput = VoiceInput();
