import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/chore_store.dart';
import '../data/task_store.dart';
import '../models/chore.dart';
import '../models/task.dart';
import '../services/voice_input.dart';
import '../services/voice_parser.dart';
import '../util/format.dart';
import 'task_edit_screen.dart';

bool _sheetOpen = false;

/// Öffnet Summer: zuhören, verstehen, speichern.
Future<void> openVoice(BuildContext context) async {
  if (_sheetOpen) return;
  _sheetOpen = true;
  try {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const VoiceSheet(),
    );
  } finally {
    _sheetOpen = false;
  }
}

enum _Phase { starting, listening, result, error }

class VoiceSheet extends StatefulWidget {
  const VoiceSheet({super.key});

  @override
  State<VoiceSheet> createState() => _VoiceSheetState();
}

class _VoiceSheetState extends State<VoiceSheet> {
  _Phase _phase = _Phase.starting;
  String _text = '';
  String _error = '';
  VoiceResult? _result;
  final _titleCtrl = TextEditingController();
  Timer? _finishTimer;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _finishTimer?.cancel();
    voiceInput.cancel();
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _phase = _Phase.starting;
      _text = '';
      _result = null;
    });
    final ok = await voiceInput.init();
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _phase = _Phase.error;
        _error = 'Spracheingabe ist nicht verfügbar. '
            'Bitte erlaube Summer den Zugriff aufs Mikrofon.';
      });
      return;
    }
    setState(() => _phase = _Phase.listening);
    await voiceInput.listen(
      onResult: (text, isFinal) {
        if (!mounted || _phase != _Phase.listening) return;
        setState(() => _text = text);
        if (isFinal) _finish();
      },
      onStopped: () {
        // Das Endergebnis kommt manchmal kurz nach „fertig“.
        _finishTimer?.cancel();
        _finishTimer = Timer(const Duration(milliseconds: 600), _finish);
      },
      onError: (msg) {
        if (!mounted || _phase != _Phase.listening || _text.isNotEmpty) return;
        setState(() {
          _phase = _Phase.error;
          _error = msg.contains('no_match') || msg.contains('speech_timeout')
              ? 'Ich habe nichts verstanden. Versuch es nochmal.'
              : 'Fehler bei der Spracherkennung ($msg).';
        });
      },
    );
  }

  void _finish() {
    _finishTimer?.cancel();
    if (!mounted || _phase != _Phase.listening) return;
    if (_text.trim().isEmpty) {
      setState(() {
        _phase = _Phase.error;
        _error = 'Ich habe nichts verstanden. Versuch es nochmal.';
      });
      return;
    }
    final result = parseVoice(_text);
    if (result.title.isEmpty) result.title = _text.trim();
    _titleCtrl.text = result.title;
    setState(() {
      _result = result;
      _phase = _Phase.result;
    });
  }

  String _title() {
    final t = _titleCtrl.text.trim();
    return t.isEmpty ? _text.trim() : t;
  }

  void _saveTask() {
    final task = _result!.toTask()..title = _title();
    taskStore.upsert(task);
    _close('Gespeichert: ${task.title} – ${_when(task)}');
  }

  void _saveChore() {
    final chore = Chore(id: newId(), title: _title());
    choreStore.upsert(chore);
    _close('Neue Aufgabe: ${chore.title}');
  }

  void _editTask() {
    final task = _result!.toTask()..title = _title();
    final nav = Navigator.of(context);
    nav.pop();
    nav.push(MaterialPageRoute(builder: (_) => TaskEditScreen(draft: task)));
  }

  void _close(String message) {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  String _when(Task t) {
    if (t.repeat != RepeatType.none) return t.describe();
    final today = todayDate();
    final diff = t.startDate.difference(today).inDays;
    final day = switch (diff) {
      0 => 'heute',
      1 => 'morgen',
      2 => 'übermorgen',
      _ => DateFormat('EEEE, d. MMMM').format(t.startDate),
    };
    return t.minutes == null ? day : '$day um ${formatMinutes(t.minutes!)} Uhr';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Summer',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...switch (_phase) {
            _Phase.starting || _Phase.listening => _listening(theme),
            _Phase.result => _resultView(theme),
            _Phase.error => _errorView(theme),
          },
        ],
      ),
    );
  }

  List<Widget> _listening(ThemeData theme) => [
        Center(
          child: SizedBox(
            width: 96,
            height: 96,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (_phase == _Phase.listening)
                  const SizedBox(
                    width: 96,
                    height: 96,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                CircleAvatar(
                  radius: 38,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(Icons.mic,
                      size: 40, color: theme.colorScheme.onPrimaryContainer),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _text.isEmpty
              ? 'Ich höre zu …\nz. B. „Morgen um 15 Uhr Zahnarzt“'
              : _text,
          textAlign: TextAlign.center,
          style: _text.isEmpty
              ? theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.outline)
              : theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: _phase == _Phase.listening ? () => voiceInput.stop() : null,
          child: const Text('Fertig'),
        ),
      ];

  List<Widget> _resultView(ThemeData theme) {
    final r = _result!;
    final preview = r.toTask();
    return [
      Text('„$_text“',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.outline)),
      const SizedBox(height: 12),
      TextField(
        controller: _titleCtrl,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          labelText: 'Was?',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 12),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(r.hasSchedule ? Icons.event : Icons.checklist),
        title: Text(r.hasSchedule ? _when(preview) : 'Ohne festen Termin'),
        subtitle: Text(r.hasSchedule
            ? (r.remindBefore > 0
                ? 'Erinnerung ${r.remindBefore} Min. vorher'
                : 'Erinnerung zur Uhrzeit')
            : 'Kommt in deine Aufgabenliste – ich erinnere dich zwischendurch.'),
      ),
      const SizedBox(height: 12),
      if (r.hasSchedule) ...[
        FilledButton.icon(
          onPressed: _saveTask,
          icon: const Icon(Icons.check),
          label: const Text('Termin speichern'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: _editTask, child: const Text('Anpassen')),
        TextButton(
            onPressed: _saveChore,
            child: const Text('Lieber als Aufgabe ohne Termin')),
      ] else ...[
        FilledButton.icon(
          onPressed: _saveChore,
          icon: const Icon(Icons.check),
          label: const Text('Als Aufgabe speichern'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
            onPressed: _editTask, child: const Text('Mit Termin speichern …')),
      ],
      TextButton.icon(
        onPressed: _start,
        icon: const Icon(Icons.mic),
        label: const Text('Nochmal sprechen'),
      ),
    ];
  }

  List<Widget> _errorView(ThemeData theme) => [
        Icon(Icons.mic_off, size: 48, color: theme.colorScheme.error),
        const SizedBox(height: 12),
        Text(_error, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _start,
          icon: const Icon(Icons.mic),
          label: const Text('Nochmal versuchen'),
        ),
      ];
}
