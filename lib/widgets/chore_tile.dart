import 'dart:math';

import 'package:flutter/material.dart';

import '../data/chore_store.dart';
import '../models/chore.dart';
import '../models/task.dart';

const _cheers = [
  'Stark! 💪',
  'Erledigt – endlich! 🎉',
  'Eins weniger im Kopf. ✅',
  'Sauber durchgezogen! 🔥',
];

const _perDayText = {
  0: 'keine Erinnerung',
  1: '1× täglich erinnern',
  2: '2× täglich erinnern',
  3: '3× täglich erinnern',
};

class ChoreTile extends StatelessWidget {
  const ChoreTile({super.key, required this.chore});

  final Chore chore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final snoozed =
        chore.snoozedUntil != null && chore.snoozedUntil!.isAfter(now);
    final subtitle = chore.isDone
        ? 'erledigt'
        : '${chore.ageText(now)} · '
            '${snoozed ? 'heute Ruhe' : _perDayText[chore.perDay]}';
    return Card(
      child: ListTile(
        leading: Checkbox(
          value: chore.isDone,
          onChanged: (_) {
            final wasDone = chore.isDone;
            choreStore.toggleDone(chore);
            if (!wasDone) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(_cheers[Random().nextInt(_cheers.length)]),
                duration: const Duration(seconds: 2),
              ));
            }
          },
        ),
        title: Text(
          chore.title,
          style: chore.isDone
              ? TextStyle(
                  decoration: TextDecoration.lineThrough,
                  color: theme.disabledColor,
                )
              : null,
        ),
        subtitle: Text(subtitle),
        onTap: () => editChore(context, chore: chore),
        trailing: chore.isDone
            ? null
            : PopupMenuButton<String>(
                onSelected: (v) {
                  switch (v) {
                    case 'snooze':
                      choreStore.snoozeToday(chore);
                    case 'edit':
                      editChore(context, chore: chore);
                    case 'delete':
                      choreStore.delete(chore.id);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'snooze', child: Text('Heute Ruhe')),
                  PopupMenuItem(value: 'edit', child: Text('Bearbeiten')),
                  PopupMenuItem(value: 'delete', child: Text('Löschen')),
                ],
              ),
      ),
    );
  }
}

Future<void> editChore(BuildContext context, {Chore? chore}) async {
  final result = await showDialog<Chore>(
    context: context,
    builder: (_) => _ChoreDialog(chore: chore),
  );
  if (result != null) choreStore.upsert(result);
}

class _ChoreDialog extends StatefulWidget {
  const _ChoreDialog({this.chore});

  final Chore? chore;

  @override
  State<_ChoreDialog> createState() => _ChoreDialogState();
}

class _ChoreDialogState extends State<_ChoreDialog> {
  late final _title = TextEditingController(text: widget.chore?.title ?? '');
  late int _perDay = widget.chore?.perDay ?? 2;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    final c = widget.chore;
    Navigator.of(context).pop(Chore(
      id: c?.id ?? newId(),
      title: title,
      note: c?.note ?? '',
      createdAt: c?.createdAt,
      perDay: _perDay,
      doneAt: c?.doneAt,
      snoozedUntil: c?.snoozedUntil,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.chore == null ? 'Neue Aufgabe' : 'Aufgabe bearbeiten'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _title,
            autofocus: widget.chore == null,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Was musst du erledigen?'),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 20),
          const Text('Wie oft soll Kairo dich erinnern?'),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 0, label: Text('Nie')),
              ButtonSegment(value: 1, label: Text('1×')),
              ButtonSegment(value: 2, label: Text('2×')),
              ButtonSegment(value: 3, label: Text('3×')),
            ],
            selected: {_perDay},
            onSelectionChanged: (s) => setState(() => _perDay = s.first),
          ),
          const SizedBox(height: 4),
          const Text('pro Tag', style: TextStyle(fontSize: 12)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(onPressed: _save, child: const Text('Speichern')),
      ],
    );
  }
}
