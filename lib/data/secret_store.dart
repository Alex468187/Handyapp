import 'synced_store.dart';

/// Verschlüsselte Passwort-Einträge (nur Chiffretext) plus Tresor-Daten.
///
/// Der Eintrag mit der ID [metaId] enthält Salt und Prüfwert des Tresors,
/// damit jedes Gerät mit demselben Master-Passwort entsperren kann.
class SecretStore extends SyncedStore<Map<String, dynamic>> {
  SecretStore() : super('secret', 'secrets_v1');

  static const metaId = '_vault';

  @override
  String idOf(Map<String, dynamic> item) => item['id'] as String;
  @override
  Map<String, dynamic> encode(Map<String, dynamic> item) => item;
  @override
  Map<String, dynamic> decode(Map<String, dynamic> json) => Map.of(json);

  Map<String, dynamic>? get meta => items[metaId];

  Iterable<Map<String, dynamic>> get blobs =>
      items.values.where((m) => m['id'] != metaId);

  void putRaw(Map<String, dynamic> item) => put(item);

  void removeRaw(String id) => remove(id);
}

final secretStore = SecretStore();
