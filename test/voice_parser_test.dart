import 'package:flutter_test/flutter_test.dart';
import 'package:handyapp/models/task.dart';
import 'package:handyapp/services/voice_parser.dart';

void main() {
  // Samstag, 07.11.2026, 10:00 Uhr
  final now = DateTime(2026, 11, 7, 10, 0);
  DateTime d(int m, int day) => DateTime.utc(2026, m, day);

  test('morgen um 15 Uhr', () {
    final r = parseVoice('Morgen um 15 Uhr Zahnarzt', now: now);
    expect(r.title, 'Zahnarzt');
    expect(r.date, d(11, 8));
    expect(r.minutes, 15 * 60);
  });

  test('übermorgen um halb 3 (= nachmittags)', () {
    final r = parseVoice('erinnere mich übermorgen um halb 3 an die Steuer',
        now: now);
    expect(r.title, 'Die Steuer');
    expect(r.date, d(11, 9));
    expect(r.minutes, 14 * 60 + 30);
  });

  test('jeden zweiten Tag um 20 Uhr', () {
    final r = parseVoice('jeden zweiten Tag um 20 Uhr Sport', now: now);
    expect(r.title, 'Sport');
    expect(r.repeat, RepeatType.everyNDays);
    expect(r.interval, 2);
    expect(r.minutes, 20 * 60);
    expect(r.date, d(11, 7));
  });

  test('jeden Montag', () {
    final r = parseVoice('jeden Montag Steuern und Rechnungen', now: now);
    expect(r.title, 'Steuern und Rechnungen');
    expect(r.repeat, RepeatType.weekly);
    expect(r.weekdays, {1});
  });

  test('am 15. jeden Monats', () {
    final r = parseVoice('am 15. jeden Monats EAR Meldung machen', now: now);
    expect(r.title, 'EAR Meldung machen');
    expect(r.repeat, RepeatType.monthly);
    expect(r.dayOfMonth, 15);
  });

  test('ohne Termin', () {
    final r = parseVoice('speichere dass ich Wäsche waschen muss', now: now);
    expect(r.title, 'Wäsche waschen');
    expect(r.hasSchedule, isFalse);
  });

  test('heute Abend', () {
    final r = parseVoice('heute Abend Mama anrufen', now: now);
    expect(r.title, 'Mama anrufen');
    expect(r.date, d(11, 7));
    expect(r.minutes, 19 * 60);
  });

  test('in 2 Stunden', () {
    final r = parseVoice('in 2 Stunden Pizza aus dem Ofen', now: now);
    expect(r.title, 'Pizza aus dem Ofen');
    expect(r.date, d(11, 7));
    expect(r.minutes, 12 * 60);
  });

  test('Wochentag mit Uhrzeit', () {
    final r = parseVoice('Freitag um 18:30 Kino', now: now);
    expect(r.title, 'Kino');
    expect(r.date, d(11, 13));
    expect(r.minutes, 18 * 60 + 30);
  });

  test('Datum mit Punkten', () {
    final r = parseVoice('am 3.12. Geburtstag Lisa', now: now);
    expect(r.title, 'Geburtstag Lisa');
    expect(r.date, d(12, 3));
  });

  test('Uhrzeit schon vorbei → morgen', () {
    final r = parseVoice('um 9 Uhr Meeting', now: now);
    expect(r.title, 'Meeting');
    expect(r.date, d(11, 8));
    expect(r.minutes, 9 * 60);
  });

  test('Erinnerung vorher', () {
    final r =
        parseVoice('morgen um 10 Uhr Friseur, 30 Minuten vorher', now: now);
    expect(r.title, 'Friseur');
    expect(r.remindBefore, 30);
    expect(r.minutes, 10 * 60);
  });
}
