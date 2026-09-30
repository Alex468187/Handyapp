import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/task_store.dart';
import '../models/task.dart';
import '../widgets/task_tile.dart';
import 'task_edit_screen.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: taskStore,
      builder: (context, _) {
        final theme = Theme.of(context);
        final today = todayDate();
        final todays = taskStore.tasksOn(today);
        final overdue = taskStore.overdue(today);
        final doneCount = todays.where((t) => t.isDoneOn(today)).length;

        return Scaffold(
          appBar: AppBar(
            title: Text(DateFormat('EEEE, d. MMMM').format(DateTime.now())),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => openTaskEditor(context, date: today),
            child: const Icon(Icons.add),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
            children: [
              if (todays.isNotEmpty) ...[
                LinearProgressIndicator(value: doneCount / todays.length),
                const SizedBox(height: 6),
                Text('$doneCount von ${todays.length} erledigt',
                    style: theme.textTheme.bodySmall),
              ],
              if (overdue.isNotEmpty) ...[
                SectionHeader('Überfällig', color: theme.colorScheme.error),
                for (final (task, day) in overdue)
                  TaskTile(task: task, day: day, overdue: true),
              ],
              const SectionHeader('Heute'),
              if (todays.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Nichts geplant. Tipp auf + für eine Aufgabe.'),
                ),
              for (final task in todays) TaskTile(task: task, day: today),
            ],
          ),
        );
      },
    );
  }
}
