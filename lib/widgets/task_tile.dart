import 'package:flutter/material.dart';

import '../data/task_store.dart';
import '../models/task.dart';
import '../screens/task_edit_screen.dart';
import '../util/format.dart';

class TaskTile extends StatelessWidget {
  const TaskTile({
    super.key,
    required this.task,
    required this.day,
    this.overdue = false,
  });

  final Task task;
  final DateTime day;
  final bool overdue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = task.isDoneOn(day);
    return Card(
      child: ListTile(
        leading: Checkbox(
          value: done,
          onChanged: (_) => taskStore.toggleDone(task, day),
        ),
        title: Text(
          task.title,
          style: done
              ? TextStyle(
                  decoration: TextDecoration.lineThrough,
                  color: theme.disabledColor,
                )
              : null,
        ),
        subtitle: Text(
          overdue ? 'Fällig am ${formatDate(day)}' : task.describe(),
          style: overdue ? TextStyle(color: theme.colorScheme.error) : null,
        ),
        trailing:
            task.minutes != null ? Text(formatMinutes(task.minutes!)) : null,
        onTap: () => openTaskEditor(context, task: task),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}
