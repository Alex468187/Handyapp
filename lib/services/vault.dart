import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import '../data/secret_store.dart';
import '../models/secret.dart';

const _iterations = 120000;
const _checkText = 'summer-vault-ok';
const _bioKey = 'vault_key';

/// Passwort-Tresor: Ver- und Entschlüsselung mit dem Master-Passwort.
///
/// Der Schlüssel wird per PBKDF2 aus dem Master-Passwort abgeleitet und
/// verlässt das Gerät nie. Gespeichert und abgeglichen wird nur Chiffretext.
class Vault extends ChangeNotifier {
  final _aes = AesGcm.with256bits();
  final _secure = const FlutterSecureStorage();
  final _auth = LocalAuthentication();

  SecretKey? _key;
  final Map<String, Secret> _entries = {};
  bool bioEnabled = false;
  bool bioAvailable = false;

  bool get exists => secretStore.meta != null;
  bool get unlocked => _key != null;

  List<Secret> get entries => _entries.values.toList()
    ..sort((a, b) => a.service.toLowerCase().compareTo(b.service.toLowerCase()));

  Future<void> init() async {
    secretStore.addListener(_onStoreChanged);
    if (Platform.isAndroid) {
      try {
        bioAvailable = await _auth.isDeviceSupported() &&
            await _auth.canCheckBiometrics;
        bioEnabled = bioAvailable && await _secure.containsKey(key: _bioKey);
      } catch (_) {
        bioAvailable = false;
      }
    }
    notifyListeners();
  }

  void _onStoreChanged() {
    if (unlocked) _decryptAll();
    notifyListeners();
  }

  // ---- Anlegen / Entsperren ----

  Future<void> create(String password) async {
    final salt = _randomBytes(16);
    final keyBytes = await _derive(password, salt, _iterations);
    final key = SecretKey(keyBytes);
    secretStore.putRaw({
      'id': SecretStore.metaId,
      'salt': base64Encode(salt),
      'iterations': _iterations,
      'check': await _encrypt(key, _checkText),
    });
    _key = key;
    await _decryptAll();
  }

  Future<bool> unlock(String password) async {
    final meta = secretStore.meta;
    if (meta == null) return false;
    final keyBytes = await _derive(password, base64Decode(meta['salt'] as String),
        (meta['iterations'] as num).toInt());
    return _tryKey(keyBytes);
  }

  Future<bool> _tryKey(List<int> keyBytes) async {
    final meta = secretStore.meta;
    if (meta == null) return false;
    final key = SecretKey(keyBytes);
    try {
      final check = await _decrypt(
          key, Map<String, dynamic>.from(meta['check'] as Map));
      if (check != _checkText) return false;
    } catch (_) {
      return false;
    }
    _key = key;
    await _decryptAll();
    return true;
  }

  void lock() {
    if (_key == null) return;
    _key = null;
    _entries.clear();
    notifyListeners();
  }

  // ---- Fingerabdruck ----

  Future<bool> enableBio() async {
    if (!bioAvailable || _key == null) return false;
    final ok = await _authenticate('Fingerabdruck für Summer einrichten');
    if (!ok) return false;
    final bytes = await _key!.extractBytes();
    await _secure.write(key: _bioKey, value: base64Encode(bytes));
    bioEnabled = true;
    notifyListeners();
    return true;
  }

  Future<void> disableBio() async {
    await _secure.delete(key: _bioKey);
    bioEnabled = false;
    notifyListeners();
  }

  Future<bool> unlockWithBio() async {
    if (!bioEnabled) return false;
    if (!await _authenticate('Passwörter entsperren')) return false;
    final stored = await _secure.read(key: _bioKey);
    if (stored == null) return false;
    final ok = await _tryKey(base64Decode(stored));
    if (!ok) await disableBio(); // Master-Passwort wurde woanders geändert
    return ok;
  }

  Future<bool> _authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(stickyAuth: true),
      );
    } catch (_) {
      return false;
    }
  }

  // ---- Einträge ----

  Future<void> save(Secret s) async {
    final key = _key;
    if (key == null) return;
    s.updatedAt = DateTime.now();
    final box = await _encrypt(key, jsonEncode(s.toJson()));
    _entries[s.id] = s;
    secretStore.putRaw({'id': s.id, ...box});
  }

  void delete(String id) {
    _entries.remove(id);
    secretStore.removeRaw(id);
  }

  Future<void> _decryptAll() async {
    final key = _key;
    if (key == null) return;
    final fresh = <String, Secret>{};
    for (final blob in secretStore.blobs.toList()) {
      final id = blob['id'] as String;
      try {
        final json = await _decrypt(key, blob);
        fresh[id] = Secret.fromJson(id, jsonDecode(json) as Map<String, dynamic>);
      } catch (e) {
        debugPrint('Summer vault: Eintrag $id nicht lesbar');
      }
    }
    if (_key != key) return;
    _entries
      ..clear()
      ..addAll(fresh);
    notifyListeners();
  }

  // ---- Krypto ----

  Future<Map<String, dynamic>> _encrypt(SecretKey key, String text) async {
    final box = await _aes.encrypt(utf8.encode(text), secretKey: key);
    return {
      'n': base64Encode(box.nonce),
      'c': base64Encode(box.cipherText),
      'm': base64Encode(box.mac.bytes),
    };
  }

  Future<String> _decrypt(SecretKey key, Map<String, dynamic> box) async {
    final clear = await _aes.decrypt(
      SecretBox(
        base64Decode(box['c'] as String),
        nonce: base64Decode(box['n'] as String),
        mac: Mac(base64Decode(box['m'] as String)),
      ),
      secretKey: key,
    );
    return utf8.decode(clear);
  }

  /// PBKDF2 ist absichtlich langsam – deshalb in einem eigenen Isolate.
  static Future<List<int>> _derive(
          String password, List<int> salt, int iterations) =>
      Isolate.run(() async {
        final pbkdf2 = Pbkdf2(
            macAlgorithm: Hmac.sha256(), iterations: iterations, bits: 256);
        final key = await pbkdf2.deriveKeyFromPassword(
            password: password, nonce: salt);
        return key.extractBytes();
      });

  static List<int> _randomBytes(int n) {
    final r = Random.secure();
    return List<int>.generate(n, (_) => r.nextInt(256));
  }
}

/// Zufälliges, starkes Passwort.
String generatePassword([int length = 18]) {
  const chars = 'abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789!?#%+-_';
  final r = Random.secure();
  return List.generate(length, (_) => chars[r.nextInt(chars.length)]).join();
}

final vault = Vault();
