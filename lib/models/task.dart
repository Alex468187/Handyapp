import 'dart:math';

import '../util/format.dart';

enum RepeatType { none, everyNDays, weekly, monthly }

/// Datum ohne Uhrzeit, in UTC – so gibt es keine Probleme mit der Zeitumstellung.
DateTime dateOnly(DateTime d) => DateTime.utc(d.year, d.month, d.day);

DateTime todayDate() => dateOnly(DateTime.now());

String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

int daysInMonth(int year, int month) => DateTime.utc(year, month + 1, 0).day;

const weekdayShort = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

String newId() =>
    '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 32)}';

class Task {
  Task({
    required this.id,
    required this.title,
    this.note = '',
    required DateTime startDate,
    this.minutes,
    this.repeat = RepeatType.none,
    this.interval = 1,
    Set<int>? weekdays,
    int? dayOfMonth,
    bool? carryOver,
    Set<String>? doneDates,
  })  : startDate = dateOnly(startDate),
        weekdays = weekdays ?? {},
        dayOfMonth = dayOfMonth ?? startDate.day,
        carryOver = carryOver ?? defaultCarryOver(repeat),
        doneDates = doneDates ?? {};

  final String id;
  String title;
  String note;

  /// Erster Tag (bei einmaligen Aufgaben: der Tag selbst).
  DateTime startDate;

  /// Uhrzeit in Minuten ab Mitternacht, null = ganztägig.
  int? minutes;
  RepeatType repeat;

  /// Bei [RepeatType.everyNDays]: alle wie viele Tage.
  int interval;

  /// Bei [RepeatType.weekly]: 1 = Montag … 7 = Sonntag.
  Set<int> weekdays;

  /// Bei [RepeatType.monthly]: Tag im Monat (31 = immer der letzte Tag).
  int dayOfMonth;

  /// Verpasste Termine bleiben als „überfällig“ offen, bis sie abgehakt sind.
  bool carryOver;

  /// Erledigte Termine als „yyyy-MM-dd“.
  Set<String> doneDates;

  static bool defaultCarryOver(RepeatType r) =>
      r == RepeatType.none || r == RepeatType.monthly || r == RepeatType.weekly;

  bool occursOn(DateTime day) {
    final d = dateOnly(day);
    if (d.isBefore(startDate)) return false;
    switch (repeat) {
      case RepeatType.none:
        return d == startDate;
      case RepeatType.everyNDays:
        return d.difference(startDate).inDays % max(1, interval) == 0;
      case RepeatType.weekly:
        return weekdays.contains(d.weekday);
      case RepeatType.monthly:
        return d.day == min(dayOfMonth, daysInMonth(d.year, d.month));
    }
  }

  bool isDoneOn(DateTime day) => doneDates.contains(dateKey(dateOnly(day)));

  DateTime? lastOccurrenceBefore(DateTime day) {
    final limit = dateOnly(day);
    if (repeat == RepeatType.none) {
      return startDate.isBefore(limit) ? startDate : null;
    }
    var d = limit.subtract(const Duration(days: 1));
    for (var i = 0; i < 400 && !d.isBefore(startDate); i++) {
      if (occursOn(d)) return d;
      d = d.subtract(const Duration(days: 1));
    }
    return null;
  }

  /// Der zuletzt verpasste Termin vor [today], falls noch offen.
  DateTime? overdueDate(DateTime today) {
    if (!carryOver) return null;
    final last = lastOccurrenceBefore(today);
    if (last == null || isDoneOn(last)) return null;
    return last;
  }

  String describe() {
    final time = minutes == null ? '' : ' um ${formatMinutes(minutes!)}';
    switch (repeat) {
      case RepeatType.none:
        return 'Einmalig am ${formatDate(startDate)}$time';
      case RepeatType.everyNDays:
        return (interval <= 1 ? 'Jeden Tag' : 'Alle $interval Tage') + time;
      case RepeatType.weekly:
        final days = (weekdays.toList()..sort())
            .map((w) => weekdayShort[w - 1])
            .join(', ');
        return 'Jeden $days$time';
      case RepeatType.monthly:
        return dayOfMonth >= 31
            ? 'Jeden Monat am letzten Tag$time'
            : 'Jeden Monat am $dayOfMonth.$time';
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'note': note,
        'startDate': dateKey(startDate),
        'minutes': minutes,
        'repeat': repeat.name,
        'interval': interval,
        'weekdays': weekdays.toList(),
        'dayOfMonth': dayOfMonth,
        'carryOver': carryOver,
        'doneDates': doneDates.toList(),
      };

  factory Task.fromJson(Map<String, dynamic> j) => Task(
        id: j['id'] as String,
        title: j['title'] as String,
        note: (j['note'] ?? '') as String,
        startDate: DateTime.parse(j['startDate'] as String),
        minutes: j['minutes'] as int?,
        repeat: RepeatType.values.byName(j['repeat'] as String),
        interval: (j['interval'] ?? 1) as int,
        weekdays: ((j['weekdays'] ?? const []) as List).cast<int>().toSet(),
        dayOfMonth: j['dayOfMonth'] as int?,
        carryOver: j['carryOver'] as bool?,
        doneDates: ((j['doneDates'] ?? const []) as List).cast<String>().toSet(),
      );
}
