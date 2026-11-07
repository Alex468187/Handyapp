import '../models/task.dart';

/// Ergebnis der Spracheingabe: Titel plus erkannter Zeitpunkt / Wiederholung.
class VoiceResult {
  VoiceResult(this.title);

  String title;
  DateTime? date;
  int? minutes;
  RepeatType repeat = RepeatType.none;
  int interval = 1;
  Set<int> weekdays = {};
  int? dayOfMonth;
  int remindBefore = 0;

  bool get hasSchedule =>
      date != null || minutes != null || repeat != RepeatType.none;

  Task toTask() {
    final start = date ?? todayDate();
    return Task(
      id: newId(),
      title: title,
      startDate: start,
      minutes: minutes,
      repeat: repeat,
      interval: interval,
      weekdays: repeat == RepeatType.weekly
          ? (weekdays.isEmpty ? {start.weekday} : weekdays)
          : {},
      dayOfMonth: dayOfMonth ?? start.day,
      remindBefore: remindBefore,
    );
  }
}

// ---------------------------------------------------------------------------
// Bausteine für die Muster. ⟨ und ⟩ stehen für Wortgrenzen (auch mit Umlauten).

const _wordChars = r'\wäöüÄÖÜß';

RegExp _rx(String pattern) => RegExp(
      pattern
          .replaceAll('⟨', '(?<![$_wordChars])')
          .replaceAll('⟩', '(?![$_wordChars])'),
      caseSensitive: false,
      unicode: true,
    );

const _numWords = {
  'null': 0,
  'ein': 1,
  'eins': 1,
  'eine': 1,
  'einer': 1,
  'einem': 1,
  'einen': 1,
  'zwei': 2,
  'drei': 3,
  'vier': 4,
  'fünf': 5,
  'sechs': 6,
  'sieben': 7,
  'acht': 8,
  'neun': 9,
  'zehn': 10,
  'elf': 11,
  'zwölf': 12,
  'dreizehn': 13,
  'vierzehn': 14,
  'fünfzehn': 15,
  'sechzehn': 16,
  'siebzehn': 17,
  'achtzehn': 18,
  'neunzehn': 19,
  'zwanzig': 20,
  'einundzwanzig': 21,
  'zweiundzwanzig': 22,
  'dreiundzwanzig': 23,
  'dreißig': 30,
};

const _ordWords = {
  'erste': 1,
  'zweite': 2,
  'dritte': 3,
  'vierte': 4,
  'fünfte': 5,
  'sechste': 6,
  'siebte': 7,
  'achte': 8,
  'neunte': 9,
  'zehnte': 10,
  'elfte': 11,
  'zwölfte': 12,
  'letzte': 31,
};

const _months = {
  'januar': 1,
  'jänner': 1,
  'februar': 2,
  'märz': 3,
  'april': 4,
  'mai': 5,
  'juni': 6,
  'juli': 7,
  'august': 8,
  'september': 9,
  'oktober': 10,
  'november': 11,
  'dezember': 12,
};

const _weekdays = {
  'montag': 1,
  'dienstag': 2,
  'mittwoch': 3,
  'donnerstag': 4,
  'freitag': 5,
  'samstag': 6,
  'sonnabend': 6,
  'sonntag': 7,
};

String _alt(Iterable<String> words) =>
    (words.toList()..sort((a, b) => b.length.compareTo(a.length))).join('|');

final _num = '(\\d{1,2}|${_alt(_numWords.keys)})';
// Ohne „ein/eine…“, damit „um ein Geschenk“ keine Uhrzeit wird.
final _numStrict =
    '(\\d{1,2}|${_alt(_numWords.keys.where((w) => !w.startsWith('ein') || w == 'eins' || w == 'einundzwanzig'))})';
final _ord = '(\\d{1,2}\\.|(?:${_alt(_ordWords.keys)})[nmrs]?)';
final _anyNum =
    '(\\d{1,2}\\.?|(?:${_alt(_ordWords.keys)})[nmrs]?|${_alt(_numWords.keys)})';
final _wd = '(?:${_alt(_weekdays.keys)})';
final _wds = '(?:${_alt(_weekdays.keys.map((w) => '${w}s'))})';
final _month = '(${_alt(_months.keys)})';

int? _toInt(String? s) {
  if (s == null) return null;
  final t = s.toLowerCase().replaceAll('.', '');
  final n = int.tryParse(t);
  if (n != null) return n;
  if (_numWords.containsKey(t)) return _numWords[t];
  if (_ordWords.containsKey(t)) return _ordWords[t];
  if (t.isNotEmpty && _ordWords.containsKey(t.substring(0, t.length - 1))) {
    return _ordWords[t.substring(0, t.length - 1)];
  }
  return null;
}

Set<int> _findWeekdays(String s) {
  final result = <int>{};
  for (final m in RegExp('(${_alt(_weekdays.keys)})', caseSensitive: false)
      .allMatches(s)) {
    result.add(_weekdays[m.group(1)!.toLowerCase()]!);
  }
  return result;
}

// ---------------------------------------------------------------------------

/// Versteht Sätze wie „morgen um 15 Uhr Zahnarzt“ oder
/// „jeden Montag Steuern und Rechnungen“.
VoiceResult parseVoice(String input, {DateTime? now}) {
  final clock = now ?? DateTime.now();
  final today = dateOnly(clock);
  var rest = ' ${input.trim()} ';
  final r = VoiceResult('');
  var absolute = false;
  String? daypart;

  /// Sucht das erste gültige Vorkommen, entfernt es aus [rest].
  bool take(RegExp re, bool Function(RegExpMatch m) apply) {
    for (final m in re.allMatches(rest)) {
      if (apply(m)) {
        rest = '${rest.substring(0, m.start)} ${rest.substring(m.end)}';
        return true;
      }
    }
    return false;
  }

  DateTime nextWeekday(int wd, {bool allowToday = false}) {
    var delta = (wd - today.weekday) % 7;
    if (delta == 0 && !allowToday) delta = 7;
    return today.add(Duration(days: delta));
  }

  // --- „30 Minuten vorher“ ---------------------------------------------------
  take(_rx('⟨(?:eine )?halbe stunde (?:vorher|davor|früher)⟩'), (m) {
    r.remindBefore = 30;
    return true;
  });
  take(_rx('⟨$_num (minuten?|stunden?|tage?) (?:vorher|davor|früher)⟩'), (m) {
    final n = _toInt(m.group(1))!;
    final unit = m.group(2)!.toLowerCase();
    r.remindBefore = unit.startsWith('min')
        ? n
        : unit.startsWith('stu')
            ? n * 60
            : n * 1440;
    return true;
  });

  // --- Wiederholungen --------------------------------------------------------
  take(_rx('⟨(?:jeden tag|täglich|jeden morgen|jeden abend)⟩'), (m) {
    r.repeat = RepeatType.everyNDays;
    r.interval = 1;
    final t = m.group(0)!.toLowerCase();
    if (t.endsWith('morgen')) daypart = 'morgen';
    if (t.endsWith('abend')) daypart = 'abend';
    return true;
  });
  take(_rx('⟨(?:jeden|jede|alle) $_anyNum (tage?|wochen?)⟩'), (m) {
    final n = _toInt(m.group(1));
    if (n == null || n < 1) return false;
    r.repeat = RepeatType.everyNDays;
    r.interval = m.group(2)!.toLowerCase().startsWith('woche') ? n * 7 : n;
    return true;
  });
  take(
      _rx('⟨(?:jeden|immer|wöchentlich)(?: am)? ($_wd(?:(?:,? und |,? oder |, ?)$_wd)*)⟩'),
      (m) {
    r.repeat = RepeatType.weekly;
    r.weekdays = _findWeekdays(m.group(1)!);
    return true;
  });
  take(_rx('⟨(?:immer )?($_wds(?:(?:,? und |, ?)$_wds)*)⟩'), (m) {
    r.repeat = RepeatType.weekly;
    r.weekdays = _findWeekdays(m.group(1)!);
    return true;
  });
  take(
      _rx('⟨(?:jeden|immer am|am) $_ord(?: tag)? (?:jeden|des|eines|im) monats?⟩'),
      (m) {
    r.repeat = RepeatType.monthly;
    r.dayOfMonth = _toInt(m.group(1));
    return true;
  });
  take(_rx('⟨(?:jeden monat|monatlich|einmal im monat)(?: am $_ord)?(?![$_wordChars])'),
      (m) {
    r.repeat = RepeatType.monthly;
    r.dayOfMonth = _toInt(m.group(1));
    return true;
  });
  take(_rx('⟨jeden (\\d{1,2})\\.(?!\\d)'), (m) {
    r.repeat = RepeatType.monthly;
    r.dayOfMonth = _toInt(m.group(1));
    return true;
  });
  take(_rx('⟨(?:jede woche|wöchentlich)⟩'), (m) {
    r.repeat = RepeatType.weekly;
    return true;
  });

  // --- „in 2 Stunden“, „in 3 Tagen“ ------------------------------------------
  take(_rx('⟨in einer halben stunde⟩'), (m) {
    final at = clock.add(const Duration(minutes: 30));
    r.date = dateOnly(at);
    r.minutes = at.hour * 60 + at.minute;
    absolute = true;
    return true;
  });
  take(_rx('⟨in $_num (minuten?|stunden?)⟩'), (m) {
    final n = _toInt(m.group(1))!;
    final at = clock.add(m.group(2)!.toLowerCase().startsWith('min')
        ? Duration(minutes: n)
        : Duration(hours: n));
    r.date = dateOnly(at);
    r.minutes = at.hour * 60 + at.minute;
    absolute = true;
    return true;
  });
  take(_rx('⟨in $_num (tagen?|wochen?)⟩'), (m) {
    final n = _toInt(m.group(1))!;
    final days = m.group(2)!.toLowerCase().startsWith('woche') ? n * 7 : n;
    r.date = today.add(Duration(days: days));
    return true;
  });
  take(_rx('⟨(?:nächste|kommende) woche⟩'), (m) {
    r.date = nextWeekday(1);
    return true;
  });
  take(_rx('⟨(?:am |dieses |nächstes )?wochenende⟩'), (m) {
    r.date = nextWeekday(6, allowToday: true);
    return true;
  });

  // --- Datum: „am 3.12.“, „15. Oktober“, „am 15.“ ----------------------------
  if (r.date == null) {
    take(_rx('⟨(?:am )?(\\d{1,2})\\.(\\d{1,2})\\.(\\d{4}|\\d{2})?'), (m) {
      final d = int.parse(m.group(1)!);
      final mo = int.parse(m.group(2)!);
      if (d < 1 || d > 31 || mo < 1 || mo > 12) return false;
      var y = m.group(3) == null ? today.year : int.parse(m.group(3)!);
      if (y < 100) y += 2000;
      var date = DateTime.utc(y, mo, d);
      if (m.group(3) == null && date.isBefore(today)) {
        date = DateTime.utc(y + 1, mo, d);
      }
      r.date = date;
      return true;
    });
  }
  if (r.date == null) {
    take(_rx('⟨(?:am |den )?$_ord ?$_month(?: (\\d{4}))?⟩'), (m) {
      final d = _toInt(m.group(1));
      final mo = _months[m.group(2)!.toLowerCase()]!;
      if (d == null || d < 1 || d > 31) return false;
      var y = m.group(3) == null ? today.year : int.parse(m.group(3)!);
      var date = DateTime.utc(y, mo, d);
      if (m.group(3) == null && date.isBefore(today)) {
        date = DateTime.utc(y + 1, mo, d);
      }
      r.date = date;
      return true;
    });
  }
  if (r.date == null && r.repeat == RepeatType.none) {
    take(_rx('⟨am $_ord(?![$_wordChars]|\\d)'), (m) {
      final d = _toInt(m.group(1));
      if (d == null || d < 1 || d > 31) return false;
      var y = today.year;
      var mo = today.month;
      if (d < today.day) {
        mo++;
        if (mo > 12) {
          mo = 1;
          y++;
        }
      }
      final dim = daysInMonth(y, mo);
      r.date = DateTime.utc(y, mo, d > dim ? dim : d);
      return true;
    });
  }

  // --- Wochentag: „am Freitag“, „nächsten Montag“ ----------------------------
  if (r.date == null) {
    take(_rx('⟨(?:(?:am|nächsten|kommenden|diesen|den) )*($_wd)⟩'), (m) {
      final wd = _weekdays[m.group(1)!.toLowerCase()]!;
      final allowToday = m.group(0)!.toLowerCase().contains('diesen');
      r.date = nextWeekday(wd, allowToday: allowToday);
      return true;
    });
  }

  // --- heute / morgen / übermorgen -------------------------------------------
  if (r.date == null) {
    take(_rx('⟨übermorgen⟩'), (m) {
      r.date = today.add(const Duration(days: 2));
      return true;
    });
  }
  if (r.date == null) {
    take(_rx('⟨morgen⟩'), (m) {
      r.date = today.add(const Duration(days: 1));
      return true;
    });
  }
  if (r.date == null) {
    take(_rx('⟨heute⟩'), (m) {
      r.date = today;
      return true;
    });
  }

  // --- Uhrzeit ---------------------------------------------------------------
  bool setTime(int? h, int m) {
    if (h == null || h < 0 || h > 24 || m < 0 || m > 59) return false;
    r.minutes = (h % 24) * 60 + m;
    return true;
  }

  if (r.minutes == null) {
    take(_rx('⟨(?:um |gegen |ab )?$_num[:.](\\d{2})(?: uhr)?⟩'),
        (m) => setTime(_toInt(m.group(1)), int.parse(m.group(2)!)));
  }
  if (r.minutes == null) {
    take(_rx('⟨(?:um |gegen |ab )?$_num uhr(?: (\\d{1,2}))?⟩'),
        (m) => setTime(_toInt(m.group(1)), int.tryParse(m.group(2) ?? '') ?? 0));
  }
  if (r.minutes == null) {
    take(_rx('⟨(?:um |gegen )?halb $_numStrict⟩'),
        (m) => setTime((_toInt(m.group(1))! + 23) % 24, 30));
  }
  if (r.minutes == null) {
    take(_rx('⟨(?:um |gegen )?viertel nach $_numStrict⟩'),
        (m) => setTime(_toInt(m.group(1)), 15));
  }
  if (r.minutes == null) {
    take(_rx('⟨(?:um |gegen )?(?:viertel vor|dreiviertel) $_numStrict⟩'),
        (m) => setTime((_toInt(m.group(1))! + 23) % 24, 45));
  }
  if (r.minutes == null) {
    take(_rx('⟨(?:um|gegen) $_numStrict⟩'), (m) => setTime(_toInt(m.group(1)), 0));
  }

  // --- Tageszeit: morgens, abends … ------------------------------------------
  take(
      _rx('⟨(?:morgens|früh|in der früh|am morgen|vormittags|am vormittag|mittags|am mittag|nachmittags|am nachmittag|abends|am abend|abend|nachts|in der nacht)⟩'),
      (m) {
    final t = m.group(0)!.toLowerCase();
    if (t.contains('nachmittag')) {
      daypart = 'nachmittag';
    } else if (t.contains('vormittag')) {
      daypart = 'vormittag';
    } else if (t.contains('mittag')) {
      daypart = 'mittag';
    } else if (t.contains('abend')) {
      daypart = 'abend';
    } else if (t.contains('nacht')) {
      daypart = 'nacht';
    } else {
      daypart = 'morgen';
    }
    return true;
  });

  if (r.minutes != null && !absolute) {
    final h = r.minutes! ~/ 60;
    final pm = daypart == 'nachmittag' ||
        daypart == 'abend' ||
        (daypart == 'nacht' && h >= 7) ||
        (daypart == 'mittag' && h <= 6) ||
        (daypart == null && h >= 1 && h <= 6);
    if (pm && h < 12) r.minutes = r.minutes! + 12 * 60;
  } else if (r.minutes == null && daypart != null) {
    r.minutes = const {
      'morgen': 8 * 60,
      'vormittag': 10 * 60,
      'mittag': 12 * 60,
      'nachmittag': 15 * 60,
      'abend': 19 * 60,
      'nacht': 22 * 60,
    }[daypart];
  }

  // Nur Uhrzeit genannt und die ist heute schon vorbei → morgen.
  if (r.date == null && r.minutes != null && r.repeat == RepeatType.none) {
    final at = DateTime(clock.year, clock.month, clock.day)
        .add(Duration(minutes: r.minutes!));
    r.date = at.isAfter(clock) ? today : today.add(const Duration(days: 1));
  }
  if (r.date == null && r.repeat != RepeatType.none) r.date = today;

  r.title = _cleanTitle(rest);
  return r;
}

final _leadFillers = _rx(
    '^\\s*(?:hey|hallo|ok|okay|summer|bitte|mal|noch|speichere|speichern|speicher|notiere|notieren|notier|merke? dir|schreibe?(?: mir)? auf|trage?(?: mir)? ein|erinnere? mich|erinnerung|neue[rn]? termin|neue aufgabe|termin|aufgabe|daran|dass|daß|an|und|für)(?:[\\s,:.!]+|\$)');
final _anyFillers = _rx(
    '⟨(?:ich muss|muss ich|ich soll|soll ich|ich sollte|ich will|ich möchte|dass ich|daß ich)⟩');
final _trailFillers = _rx(
    '(?:\\s+(?:muss|soll|sollte|bitte|speichern|notieren|eintragen|ein|auf))+[\\s.,!?]*\$');

String _cleanTitle(String s) {
  var t = s.replaceAll(_anyFillers, ' ');
  String before;
  do {
    before = t;
    t = t.replaceFirst(_leadFillers, '');
  } while (t != before);
  t = t.replaceFirst(_trailFillers, '');
  t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
  t = t.replaceAll(RegExp(r'^[\s,.;:!?-]+|[\s,.;:!?-]+$'), '');
  if (t.isEmpty) return '';
  return t[0].toUpperCase() + t.substring(1);
}
