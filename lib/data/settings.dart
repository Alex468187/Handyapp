import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Settings extends ChangeNotifier {
  static const _autoListenKey = 'auto_listen';

  /// Beim Öffnen der App sofort zuhören („Hey Google, öffne Summer“).
  bool autoListen = true;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    autoListen = prefs.getBool(_autoListenKey) ?? true;
    notifyListeners();
  }

  Future<void> setAutoListen(bool value) async {
    autoListen = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoListenKey, value);
  }
}

final settings = Settings();
