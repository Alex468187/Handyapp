import 'package:flutter/material.dart';

import '../data/task_store.dart';
import '../models/task.dart';
import 'task_edit_screen.dart';

class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: taskStore,
      builder: (context, _) {
        final tasks = [...taskStore.tasks]..sort((a, b) =>
            a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        return Scaffold(
          appBar: AppBar(title: const Text('Alle Termine')),
          floatingActionButton: FloatingActionButton(
            heroTag: null,
            onPressed: () => openTaskEditor(context, date: todayDate()),
            child: const Icon(Icons.add),
          ),
          body: tasks.isEmpty
              ? const Center(child: Text('Noch keine Termine.'))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
                  children: [
                    for (final task in tasks)
                      Card(
                        child: ListTile(
                          leading: Icon(task.repeat == RepeatType.none
                              ? Icons.event
                              : Icons.repeat),
                          title: Text(task.title),
                          subtitle: Text(task.describe()),
                          onTap: () => openTaskEditor(context, task: task),
                        ),
                      ),
                  ],
                ),
        );
      },
    );
  }
}
