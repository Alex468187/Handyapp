/// Ein Konto im Passwort-Manager (wird nur verschlüsselt gespeichert).
class Secret {
  Secret({
    required this.id,
    this.service = '',
    this.email = '',
    this.username = '',
    this.password = '',
    this.phone = '',
    this.note = '',
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  final String id;
  String service;
  String email;
  String username;
  String password;
  String phone;
  String note;
  DateTime updatedAt;

  /// Zweite Zeile in der Liste: E-Mail oder Benutzername.
  String get login => email.isNotEmpty ? email : username;

  Map<String, dynamic> toJson() => {
        'service': service,
        'email': email,
        'username': username,
        'password': password,
        'phone': phone,
        'note': note,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  factory Secret.fromJson(String id, Map<String, dynamic> j) => Secret(
        id: id,
        service: (j['service'] ?? '') as String,
        email: (j['email'] ?? '') as String,
        username: (j['username'] ?? '') as String,
        password: (j['password'] ?? '') as String,
        phone: (j['phone'] ?? '') as String,
        note: (j['note'] ?? '') as String,
        updatedAt: j['updatedAt'] == null
            ? null
            : DateTime.parse(j['updatedAt'] as String).toLocal(),
      );
}
