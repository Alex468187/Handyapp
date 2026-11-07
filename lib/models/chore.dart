import 'task.dart';

/// Aufgabe ohne festen Termin – Summer erinnert zwischendurch, bis sie erledigt ist.
class Chore {
  Chore({
    required this.id,
    required this.title,
    this.note = '',
    DateTime? createdAt,
    this.perDay = 2,
    this.doneAt,
    this.snoozedUntil,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  String title;
  String note;
  final DateTime createdAt;

  /// Erinnerungen pro Tag (0 = keine).
  int perDay;
  DateTime? doneAt;

  /// Bis dahin keine Erinnerungen („Heute Ruhe“).
  DateTime? snoozedUntil;

  bool get isDone => doneAt != null;

  int daysOpen(DateTime now) =>
      dateOnly(now).difference(dateOnly(createdAt)).inDays;

  String ageText(DateTime now) {
    final d = daysOpen(now);
    if (d <= 0) return 'seit heute';
    if (d == 1) return 'seit gestern';
    return 'seit $d Tagen';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'note': note,
        'createdAt': createdAt.toIso8601String(),
        'perDay': perDay,
        'doneAt': doneAt?.toIso8601String(),
        'snoozedUntil': snoozedUntil?.toIso8601String(),
      };

  factory Chore.fromJson(Map<String, dynamic> j) => Chore(
        id: j['id'] as String,
        title: j['title'] as String,
        note: (j['note'] ?? '') as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        perDay: (j['perDay'] ?? 2) as int,
        doneAt: j['doneAt'] == null ? null : DateTime.parse(j['doneAt'] as String),
        snoozedUntil: j['snoozedUntil'] == null
            ? null
            : DateTime.parse(j['snoozedUntil'] as String),
      );
}
