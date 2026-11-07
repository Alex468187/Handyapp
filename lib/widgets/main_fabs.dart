import 'package:flutter/material.dart';

import '../screens/voice_sheet.dart';
import '../services/voice_input.dart';

/// Kleiner „+“-Knopf und großer Mikrofon-Knopf unten rechts.
class MainFabs extends StatelessWidget {
  const MainFabs({super.key, required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    if (!VoiceInput.supported) {
      return FloatingActionButton(
        heroTag: null,
        onPressed: onAdd,
        tooltip: 'Neu',
        child: const Icon(Icons.add),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        FloatingActionButton.small(
          heroTag: null,
          onPressed: onAdd,
          tooltip: 'Neu',
          child: const Icon(Icons.add),
        ),
        const SizedBox(height: 12),
        FloatingActionButton.large(
          heroTag: null,
          onPressed: () => openVoice(context),
          tooltip: 'Sprechen',
          child: const Icon(Icons.mic),
        ),
      ],
    );
  }
}
