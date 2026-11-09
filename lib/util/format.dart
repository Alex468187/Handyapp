String _two(int n) => n.toString().padLeft(2, '0');

String formatDate(DateTime d) => '${_two(d.day)}.${_two(d.month)}.${d.year}';

String formatMinutes(int minutes) => '${_two(minutes ~/ 60)}:${_two(minutes % 60)}';

String formatTime(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

/// „heute 14:30“, „gestern“ oder „03.11.2026“.
String formatWhen(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'heute ${formatTime(d)}';
  if (diff == 1) return 'gestern';
  return formatDate(d);
}
