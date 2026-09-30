import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../data/task_store.dart';
import '../models/task.dart';
import '../util/format.dart';
import '../widgets/task_tile.dart';
import 'task_edit_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focused = DateTime.now();
  DateTime _selected = DateTime.now();
  CalendarFormat _format = CalendarFormat.month;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: taskStore,
      builder: (context, _) {
        final day = dateOnly(_selected);
        final tasks = taskStore.tasksOn(day);
        return Scaffold(
          appBar: AppBar(title: const Text('Kalender')),
          floatingActionButton: FloatingActionButton(
            onPressed: () => openTaskEditor(context, date: day),
            child: const Icon(Icons.add),
          ),
          body: Column(
            children: [
              TableCalendar<Task>(
                locale: 'de_DE',
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2100, 12, 31),
                focusedDay: _focused,
                startingDayOfWeek: StartingDayOfWeek.monday,
                calendarFormat: _format,
                availableCalendarFormats: const {
                  CalendarFormat.month: 'Monat',
                  CalendarFormat.twoWeeks: '2 Wochen',
                  CalendarFormat.week: 'Woche',
                },
                onFormatChanged: (f) => setState(() => _format = f),
                selectedDayPredicate: (d) => isSameDay(d, _selected),
                onDaySelected: (selected, focused) => setState(() {
                  _selected = selected;
                  _focused = focused;
                }),
                onPageChanged: (focused) => _focused = focused,
                eventLoader: (d) => taskStore.tasksOn(d),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
                  children: [
                    SectionHeader(formatDate(day)),
                    if (tasks.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('Keine Aufgaben an diesem Tag.'),
                      ),
                    for (final task in tasks) TaskTile(task: task, day: day),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
