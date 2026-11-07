import 'package:flutter/material.dart';

import '../data/chore_store.dart';
import '../widgets/chore_tile.dart';
import '../widgets/main_fabs.dart';
import '../widgets/task_tile.dart';

/// Aufgaben ohne Termin – das, was man gerne vor sich herschiebt.
class ChoresScreen extends StatefulWidget {
  const ChoresScreen({super.key});

  @override
  State<ChoresScreen> createState() => _ChoresScreenState();
}

class _ChoresScreenState extends State<ChoresScreen> {
  bool _showDone = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: choreStore,
      builder: (context, _) {
        final open = choreStore.open;
        final done = choreStore.done;
        return Scaffold(
          appBar: AppBar(title: const Text('Aufgaben')),
          floatingActionButton: MainFabs(onAdd: () => editChore(context)),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 160),
            children: [
              if (open.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Nichts offen. 🎉\n\nHier landet alles, was du erledigen '
                    'musst, aber keinen festen Termin hat. Kairo erinnert '
                    'dich zwischendurch daran, bis du es abhakst.',
                  ),
                ),
              for (final c in open) ChoreTile(chore: c),
              if (done.isNotEmpty) ...[
                InkWell(
                  onTap: () => setState(() => _showDone = !_showDone),
                  child: Row(
                    children: [
                      Expanded(child: SectionHeader('Erledigt (${done.length})')),
                      Icon(_showDone ? Icons.expand_less : Icons.expand_more),
                    ],
                  ),
                ),
                if (_showDone)
                  for (final c in done.take(30)) ChoreTile(chore: c),
              ],
            ],
          ),
        );
      },
    );
  }
}
