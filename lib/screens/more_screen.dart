import 'package:flutter/material.dart';

import '../data/settings.dart';
import '../services/sync.dart';
import 'account_screen.dart';
import 'notes_screen.dart';
import '../services/voice_input.dart';
import 'tasks_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  static const _upcoming = [
    (Icons.lock, 'Passwörter', 'Logins mit E-Mail, Benutzername, Telefonnummer'),
    (Icons.mail, 'Nachrichten', 'Wichtige Mails und WhatsApp'),
    (Icons.swap_horiz, 'Dateien teilen', 'Zwischen Handy und PC'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([settings, sync]),
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('Mehr')),
        body: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Card(
              child: ListTile(
                leading: Icon(sync.signedIn ? Icons.cloud_done : Icons.cloud_off),
                title: const Text('Konto & Abgleich'),
                subtitle: Text(sync.signedIn
                    ? 'Angemeldet als ${sync.user?.email}'
                    : 'Anmelden, um Handy, PC und Claude zu verbinden'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AccountScreen())),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.sticky_note_2),
                title: const Text('Notizen'),
                subtitle: const Text('Geschenkideen, Gedanken, alles Mögliche'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const NotesScreen())),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.event_note),
                title: const Text('Alle Termine'),
                subtitle: const Text('Wiederholungen bearbeiten oder löschen'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TasksScreen())),
              ),
            ),
            if (VoiceInput.supported) ...[
              Card(
                child: SwitchListTile(
                  secondary: const Icon(Icons.mic),
                  title: const Text('Beim Öffnen sofort zuhören'),
                  subtitle: const Text(
                      'Sag „Hey Google, öffne Summer“ – und sprich direkt los.'),
                  value: settings.autoListen,
                  onChanged: settings.setAutoListen,
                ),
              ),
              const Card(
                child: ListTile(
                  leading: Icon(Icons.touch_app),
                  title: Text('Schnellstart'),
                  subtitle: Text(
                      'Halte das Summer-Symbol auf dem Startbildschirm gedrückt '
                      '→ „Sprechen“. Das kannst du auch als eigenes Symbol '
                      'auf den Startbildschirm ziehen.'),
                ),
              ),
            ],
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 16, 4, 4),
              child: Text('Kommt bald',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            for (final (icon, title, subtitle) in _upcoming)
              Card(
                child: ListTile(
                  enabled: false,
                  leading: Icon(icon),
                  title: Text(title),
                  subtitle: Text(subtitle),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
