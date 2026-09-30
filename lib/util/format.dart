String _two(int n) => n.toString().padLeft(2, '0');

String formatDate(DateTime d) => '${_two(d.day)}.${_two(d.month)}.${d.year}';

String formatMinutes(int minutes) => '${_two(minutes ~/ 60)}:${_two(minutes % 60)}';
