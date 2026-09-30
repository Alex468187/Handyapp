import 'package:flutter_test/flutter_test.dart';
import 'package:handyapp/models/task.dart';

void main() {
  test('monatlich am 31. fällt im Februar auf den letzten Tag', () {
    final t = Task(
      id: '1',
      title: 'Test',
      startDate: DateTime(2026, 1, 31),
      repeat: RepeatType.monthly,
      dayOfMonth: 31,
    );
    expect(t.occursOn(DateTime(2026, 2, 28)), isTrue);
    expect(t.occursOn(DateTime(2026, 2, 27)), isFalse);
  });

  test('alle 2 Tage auch über die Zeitumstellung', () {
    final t = Task(
      id: '1',
      title: 'Sport',
      startDate: DateTime(2026, 3, 28),
      repeat: RepeatType.everyNDays,
      interval: 2,
    );
    expect(t.occursOn(DateTime(2026, 3, 29)), isFalse);
    expect(t.occursOn(DateTime(2026, 3, 30)), isTrue);
  });

  test('wöchentlich montags', () {
    final t = Task(
      id: '1',
      title: 'Steuern',
      startDate: DateTime(2026, 9, 1),
      repeat: RepeatType.weekly,
      weekdays: {1},
    );
    expect(t.occursOn(DateTime(2026, 10, 5)), isTrue);
    expect(t.occursOn(DateTime(2026, 10, 6)), isFalse);
  });

  test('verpasster Termin ist überfällig, bis er abgehakt ist', () {
    final t = Task(
      id: '1',
      title: 'EAR',
      startDate: DateTime(2026, 9, 1),
      repeat: RepeatType.monthly,
      dayOfMonth: 15,
    );
    final today = DateTime(2026, 9, 30);
    expect(t.overdueDate(today), dateOnly(DateTime(2026, 9, 15)));
    t.doneDates.add('2026-09-15');
    expect(t.overdueDate(today), isNull);
  });

  test('Speichern und Laden ergibt dieselbe Aufgabe', () {
    final t = Task(
      id: 'abc',
      title: 'Sport',
      startDate: DateTime(2026, 9, 30),
      minutes: 20 * 60,
      repeat: RepeatType.everyNDays,
      interval: 2,
      doneDates: {'2026-09-30'},
    );
    final copy = Task.fromJson(t.toJson());
    expect(copy.toJson(), t.toJson());
    expect(copy.describe(), 'Alle 2 Tage um 20:00');
  });
}
