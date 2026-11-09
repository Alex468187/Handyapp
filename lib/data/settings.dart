import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wann Summer auf ihren Namen hört.
enum WakeMode {
  off('Aus'),
  open('Wenn die App offen ist'),
  always('Jederzeit, auch bei Bildschirm aus');

  const WakeMode(this.label);
  final String label;
}

class Settings extends ChangeNotifier {
  static const _autoListenKey = 'auto_listen';
  static const _wakeModeKey = 'wake_mode';

  /// Beim Öffnen der App sofort zuhören („Hey Google, öffne Summer“).
  bool autoListen = true;

  WakeMode wakeMode = WakeMode.off;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    autoListen = prefs.getBool(_autoListenKey) ?? true;
    wakeMode = WakeMode.values.asNameMap()[prefs.getString(_wakeModeKey)] ??
        WakeMode.off;
    notifyListeners();
  }

  Future<void> setAutoListen(bool value) async {
    autoListen = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoListenKey, value);
  }

  Future<void> setWakeMode(WakeMode value) async {
    wakeMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_wakeModeKey, value.name);
  }
}

final settings = Settings();
