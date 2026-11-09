/// Freie Notiz (z. B. Geschenkideen).
class Note {
  Note({
    required this.id,
    this.title = '',
    this.body = '',
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  final String id;
  String title;
  String body;
  DateTime updatedAt;

  bool get isEmpty => title.trim().isEmpty && body.trim().isEmpty;

  /// Überschrift für die Liste: Titel oder erste Textzeile.
  String get heading {
    if (title.trim().isNotEmpty) return title.trim();
    final first = body.trim().split('\n').first;
    return first.isEmpty ? 'Ohne Titel' : first;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  factory Note.fromJson(Map<String, dynamic> j) => Note(
        id: j['id'] as String,
        title: (j['title'] ?? '') as String,
        body: (j['body'] ?? '') as String,
        updatedAt: j['updatedAt'] == null
            ? null
            : DateTime.parse(j['updatedAt'] as String).toLocal(),
      );
}
