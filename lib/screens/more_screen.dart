import 'package:flutter/material.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  static const _upcoming = [
    (Icons.sticky_note_2, 'Notizen', 'Geschenkideen, Gedanken, alles Mögliche'),
    (Icons.lock, 'Passwörter', 'Logins mit E-Mail, Benutzername, Telefonnummer'),
    (Icons.mail, 'Nachrichten', 'Wichtige Mails und WhatsApp'),
    (Icons.swap_horiz, 'Dateien teilen', 'Zwischen Handy und PC'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mehr')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          for (final (icon, title, subtitle) in _upcoming)
            Card(
              child: ListTile(
                leading: Icon(icon),
                title: Text(title),
                subtitle: Text(subtitle),
                trailing: const Text('kommt bald'),
              ),
            ),
        ],
      ),
    );
  }
}
