import 'package:flutter/material.dart';

import '../data/task_store.dart';
import '../models/task.dart';
import '../util/format.dart';

Future<void> openTaskEditor(BuildContext context, {Task? task, DateTime? date}) {
  return Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => TaskEditScreen(task: task, initialDate: date),
  ));
}

class TaskEditScreen extends StatefulWidget {
  const TaskEditScreen({super.key, this.task, this.initialDate});

  final Task? task;
  final DateTime? initialDate;

  @override
  State<TaskEditScreen> createState() => _TaskEditScreenState();
}

class _TaskEditScreenState extends State<TaskEditScreen> {
  late final TextEditingController _title;
  late final TextEditingController _note;
  late DateTime _start;
  int? _minutes;
  late RepeatType _repeat;
  late int _interval;
  late Set<int> _weekdays;
  late int _dayOfMonth;
  late bool _carryOver;
  bool _carryOverTouched = false;

  bool get _isNew => widget.task == null;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _title = TextEditingController(text: t?.title ?? '');
    _note = TextEditingController(text: t?.note ?? '');
    _start = t?.startDate ?? dateOnly(widget.initialDate ?? DateTime.now());
    _minutes = t?.minutes;
    _repeat = t?.repeat ?? RepeatType.none;
    _interval = t?.interval ?? 1;
    _weekdays = {...?t?.weekdays};
    if (_weekdays.isEmpty) _weekdays.add(_start.weekday);
    _dayOfMonth = t?.dayOfMonth ?? _start.day;
    _carryOver = t?.carryOver ?? Task.defaultCarryOver(_repeat);
    _carryOverTouched = t != null;
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _start = dateOnly(picked));
  }

  Future<void> _pickTime() async {
    final m = _minutes ?? 20 * 60;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: m ~/ 60, minute: m % 60),
    );
    if (picked != null) {
      setState(() => _minutes = picked.hour * 60 + picked.minute);
    }
  }

  void _setRepeat(RepeatType r) {
    setState(() {
      _repeat = r;
      if (!_carryOverTouched) _carryOver = Task.defaultCarryOver(r);
    });
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      _snack('Bitte gib einen Namen ein.');
      return;
    }
    if (_repeat == RepeatType.weekly && _weekdays.isEmpty) {
      _snack('Bitte mindestens einen Wochentag wählen.');
      return;
    }
    taskStore.upsert(Task(
      id: widget.task?.id ?? newId(),
      title: title,
      note: _note.text.trim(),
      startDate: _start,
      minutes: _minutes,
      repeat: _repeat,
      interval: _interval,
      weekdays: _weekdays,
      dayOfMonth: _dayOfMonth,
      carryOver: _carryOver,
      doneDates: widget.task?.doneDates,
    ));
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aufgabe löschen?'),
        content: Text('„${widget.task!.title}“ wird gelöscht.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      taskStore.delete(widget.task!.id);
      Navigator.of(context).pop();
    }
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Neue Aufgabe' : 'Aufgabe bearbeiten'),
        actions: [
          if (!_isNew)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Löschen',
              onPressed: _delete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _title,
            autofocus: _isNew,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Was?',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            minLines: 1,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Notiz (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.repeat),
            title: const Text('Wiederholen'),
            trailing: DropdownButton<RepeatType>(
              value: _repeat,
              onChanged: (r) => _setRepeat(r!),
              items: const [
                DropdownMenuItem(value: RepeatType.none, child: Text('Einmalig')),
                DropdownMenuItem(
                    value: RepeatType.everyNDays, child: Text('Alle X Tage')),
                DropdownMenuItem(
                    value: RepeatType.weekly, child: Text('Wöchentlich')),
                DropdownMenuItem(
                    value: RepeatType.monthly, child: Text('Monatlich')),
              ],
            ),
          ),
          if (_repeat == RepeatType.everyNDays)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const SizedBox(),
              title: const Text('Wie oft?'),
              trailing: DropdownButton<int>(
                value: _interval,
                onChanged: (v) => setState(() => _interval = v!),
                items: [
                  for (var i = 1; i <= 30; i++)
                    DropdownMenuItem(
                      value: i,
                      child: Text(i == 1 ? 'Jeden Tag' : 'Alle $i Tage'),
                    ),
                ],
              ),
            ),
          if (_repeat == RepeatType.weekly)
            Padding(
              padding: const EdgeInsets.only(left: 40, bottom: 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var w = 1; w <= 7; w++)
                    FilterChip(
                      label: Text(weekdayShort[w - 1]),
                      selected: _weekdays.contains(w),
                      onSelected: (on) => setState(() {
                        if (on) {
                          _weekdays.add(w);
                        } else {
                          _weekdays.remove(w);
                        }
                      }),
                    ),
                ],
              ),
            ),
          if (_repeat == RepeatType.monthly)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const SizedBox(),
              title: const Text('Am Tag'),
              trailing: DropdownButton<int>(
                value: _dayOfMonth,
                onChanged: (v) => setState(() => _dayOfMonth = v!),
                items: [
                  for (var d = 1; d <= 31; d++)
                    DropdownMenuItem(
                      value: d,
                      child: Text(d == 31 ? 'Letzter Tag' : '$d.'),
                    ),
                ],
              ),
            ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event),
            title: Text(_repeat == RepeatType.none ? 'Datum' : 'Ab wann'),
            trailing: Text(formatDate(_start)),
            onTap: _pickDate,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule),
            title: const Text('Uhrzeit'),
            subtitle: Text(_minutes == null ? 'Ganztägig' : formatMinutes(_minutes!)),
            trailing: _minutes == null
                ? null
                : IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Ganztägig',
                    onPressed: () => setState(() => _minutes = null),
                  ),
            onTap: _pickTime,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.warning_amber),
            title: const Text('Bleibt offen, bis erledigt'),
            subtitle: const Text('Verpasst? Dann steht es unter „Überfällig“.'),
            value: _carryOver,
            onChanged: (v) => setState(() {
              _carryOver = v;
              _carryOverTouched = true;
            }),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check),
            label: const Text('Speichern'),
          ),
        ],
      ),
    );
  }
}
