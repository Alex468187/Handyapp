import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/chore_store.dart';
import '../data/task_store.dart';
import '../models/task.dart';
import '../util/format.dart';

/// Plant alle Erinnerungen neu, sobald sich Aufgaben ändern.
class Notifications {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static Timer? _debounce;
  static Future<void> _running = Future.value();

  static bool get supported => Platform.isAndroid;

  static const _taskDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'termine',
      'Termine',
      channelDescription: 'Erinnerungen zu geplanten Terminen und To-dos',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  static const _nagDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'aufgaben',
      'Aufgaben',
      channelDescription: 'Summer erinnert an Aufgaben, die du vor dir herschiebst',
    ),
  );

  static const _nagTexts = [
    'Das steht {age} auf deiner Liste. 10 Minuten reichen zum Anfangen.',
    'Nur der erste Schritt – danach wird es leichter.',
    'Jetzt erledigen = heute Abend Ruhe im Kopf.',
    'Timer auf 5 Minuten stellen und einfach anfangen. Los!',
    'Das wird nicht von allein weniger. 😉',
    'Kurz durchziehen und abhaken – du schaffst das.',
  ];

  static const _nagSlots = {
    1: [18 * 60],
    2: [11 * 60, 18 * 60],
    3: [10 * 60, 14 * 60 + 30, 19 * 60 + 30],
  };

  static Future<void> init() async {
    if (!supported) return;
    try {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Europe/Berlin'));
      await _plugin.initialize(const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ));
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      _ready = true;
      taskStore.addListener(requestReschedule);
      choreStore.addListener(requestReschedule);
      requestReschedule();
    } catch (e) {
      debugPrint('Benachrichtigungen nicht verfügbar: $e');
    }
  }

  static void requestReschedule() {
    if (!_ready) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () {
      _running = _running.then((_) => _reschedule()).catchError((Object e) {
        debugPrint('Planen fehlgeschlagen: $e');
      });
    });
  }

  static Future<void> _reschedule() async {
    await _plugin.cancelAll();
    final now = DateTime.now();
    final today = todayDate();
    final items = <({DateTime at, String title, String body, bool nag})>[];

    // Termine der nächsten 3 Wochen
    for (var i = 0; i < 21; i++) {
      final day = today.add(Duration(days: i));
      for (final t in taskStore.tasks) {
        if (!t.occursOn(day) || t.isDoneOn(day)) continue;
        final m = t.minutes ?? 8 * 60;
        final due = DateTime(day.year, day.month, day.day).add(Duration(minutes: m));
        final at = t.minutes == null
            ? due
            : due.subtract(Duration(minutes: t.remindBefore));
        if (!at.isAfter(now)) continue;
        final String body;
        if (t.minutes == null) {
          body = 'Heute fällig';
        } else if (t.remindBefore == 0) {
          body = 'Jetzt – ${formatMinutes(m)} Uhr';
        } else {
          body = '${formatDate(day)} um ${formatMinutes(m)} Uhr';
        }
        items.add((at: at, title: t.title, body: body, nag: false));
      }
    }

    // Aufgaben ohne Termin: Summer erinnert zwischendurch (nächste 7 Tage)
    var n = 0;
    for (final c in choreStore.open) {
      final slots = _nagSlots[c.perDay];
      if (slots == null) continue;
      for (var i = 0; i < 7; i++) {
        final day = DateTime(now.year, now.month, now.day + i);
        for (final m in slots) {
          final at = day.add(Duration(minutes: m));
          if (!at.isAfter(now)) continue;
          if (c.snoozedUntil != null && at.isBefore(c.snoozedUntil!)) continue;
          final text = _nagTexts[n++ % _nagTexts.length]
              .replaceAll('{age}', c.ageText(at));
          items.add((at: at, title: '👀 ${c.title}', body: text, nag: true));
        }
      }
    }

    items.sort((a, b) => a.at.compareTo(b.at));
    var id = 0;
    for (final item in items.take(200)) {
      await _schedule(id++, item.at, item.title, item.body,
          item.nag ? _nagDetails : _taskDetails);
    }
  }

  static Future<void> _schedule(int id, DateTime at, String title, String body,
      NotificationDetails details) async {
    final when = tz.TZDateTime.from(at, tz.local);
    try {
      await _plugin.zonedSchedule(id, title, body, when, details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle);
    } catch (_) {
      // Exakte Wecker nicht erlaubt → etwas ungenauer erinnern.
      await _plugin.zonedSchedule(id, title, body, when, details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle);
    }
  }
}
