import '../widgets/app_drawer.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/chore_store.dart';
import '../data/task_store.dart';
import '../models/task.dart';
import '../widgets/chore_tile.dart';
import '../widgets/main_fabs.dart';
import '../widgets/task_tile.dart';
import 'task_edit_screen.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([taskStore, choreStore]),
      builder: (context, _) {
        final theme = Theme.of(context);
        final today = todayDate();
        final todays = taskStore.tasksOn(today);
        final overdue = taskStore.overdue(today);
        final chores = choreStore.open;
        final doneCount = todays.where((t) => t.isDoneOn(today)).length;

        return Scaffold(
          appBar: AppBar(
            leading: const MenuButton(),
            title: Text(DateFormat('EEEE, d. MMMM').format(DateTime.now())),
          ),
          floatingActionButton:
              MainFabs(onAdd: () => openTaskEditor(context, date: today)),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 160),
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
                  child: Text('Nichts geplant. Tipp aufs Mikrofon und sag '
                      'z. B. „Morgen um 15 Uhr Zahnarzt“.'),
                ),
              for (final task in todays) TaskTile(task: task, day: today),
              if (chores.isNotEmpty) ...[
                SectionHeader('Offene Aufgaben (${chores.length})'),
                for (final c in chores.take(3)) ChoreTile(chore: c),
                if (chores.length > 3)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text('… und ${chores.length - 3} weitere im Tab „Aufgaben“',
                        style: theme.textTheme.bodySmall),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}
