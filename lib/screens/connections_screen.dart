import 'package:flutter/material.dart';

import '../data/message_store.dart';
import '../services/sync.dart';
import 'account_screen.dart';
import 'messages_screen.dart';

const _waGreen = Color(0xFF25D366);
const _gmailRed = Color(0xFFEA4335);
const _claudeOrange = Color(0xFFD97757);

/// Verbindungen zu Gmail, WhatsApp und Claude an einem Ort.
class ConnectionsScreen extends StatelessWidget {
  const ConnectionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([sync, messageStore]),
      builder: (context, _) {
        final phone = MessageStore.supported;
        final access = messageStore.enabled;
        final waChats =
            messageStore.conversations.where((c) => !c.isMail).length;
        final accounts = messageStore.accounts.toList()..sort();

        return Scaffold(
          appBar: AppBar(title: const Text('Verbindungen')),
          body: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              // ---------------------------------------------------- Claude
              _ConnectionCard(
                color: _claudeOrange,
                icon: Icons.auto_awesome,
                title: 'Claude',
                connected: sync.signedIn,
                status: sync.signedIn
                    ? 'Verbunden über ${sync.user?.email}'
                    : 'Nicht verbunden',
                description:
                    'Claude kann dir Termine, Aufgaben und Notizen eintragen – '
                    'sag es einfach im Chat mit Claude, z. B. „Trag mir für '
                    'Freitag 10 Uhr Zahnarzt ein“. Deine Passwörter kann Claude '
                    'nicht lesen.',
                actions: [
                  if (!sync.signedIn)
                    FilledButton(
                      onPressed: () => _push(context, const AccountScreen()),
                      child: const Text('Verbinden (anmelden)'),
                    )
                  else
                    OutlinedButton(
                      onPressed: () => _push(context, const AccountScreen()),
                      child: const Text('Konto ansehen'),
                    ),
                ],
              ),

              // ---------------------------------------------------- WhatsApp
              _ConnectionCard(
                color: _waGreen,
                icon: Icons.chat,
                title: 'WhatsApp',
                connected: phone && access,
                status: !phone
                    ? 'Nur auf dem Handy'
                    : access
                        ? 'Verbunden${waChats > 0 ? ' · $waChats Chats' : ''}'
                        : 'Nicht verbunden',
                description:
                    'Neue WhatsApp-Nachrichten erscheinen unter „Nachrichten“. '
                    'Du kannst direkt aus Summer antworten. Markiere wichtige '
                    'Kontakte mit dem Stern.',
                actions: [
                  if (phone && !access) ..._accessButtons(),
                  if (phone && access)
                    OutlinedButton(
                      onPressed: () => _push(context, const MessagesScreen()),
                      child: const Text('Nachrichten öffnen'),
                    ),
                ],
              ),

              // ---------------------------------------------------- Gmail
              _ConnectionCard(
                color: _gmailRed,
                icon: Icons.mail,
                title: 'Gmail',
                connected: phone && access,
                status: !phone
                    ? 'Nur auf dem Handy'
                    : access
                        ? (accounts.isEmpty
                            ? 'Verbunden · noch keine Mail empfangen'
                            : 'Verbunden · ${accounts.length} Konto${accounts.length == 1 ? '' : 'en'}')
                        : 'Nicht verbunden',
                description:
                    'Neue Mails erscheinen unter „Nachrichten“. Wähle unten, '
                    'welche Konten Summer zeigen soll.\n\nWichtig: In der '
                    'Gmail-App bei jedem Konto Einstellungen → Benachrichtigungen '
                    'auf „Alle“ stellen – Summer sieht nur Mails, für die Gmail '
                    'eine Benachrichtigung schickt.',
                actions: [
                  if (phone && !access) ..._accessButtons(),
                ],
                extra: [
                  if (phone && access)
                    for (final a in accounts)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(a),
                        value: !messageStore.hiddenAccounts.contains(a),
                        onChanged: (v) =>
                            messageStore.setAccountHidden(a, v != true),
                      ),
                ],
              ),

              if (phone && !access)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    'WhatsApp und Gmail nutzen denselben Zugriff: Summer liest '
                    'deren Benachrichtigungen mit. Ist Summer in der Liste '
                    'ausgegraut („Eingeschränkte Einstellung“)? Dann zuerst '
                    '„App-Info“ → ⋮ oben rechts → „Eingeschränkte Einstellungen '
                    'zulassen“, danach nochmal „Verbinden“.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  static List<Widget> _accessButtons() => [
        FilledButton(
          onPressed: messageStore.openSettings,
          child: const Text('Verbinden'),
        ),
        TextButton(
          onPressed: messageStore.openAppInfo,
          child: const Text('App-Info'),
        ),
      ];

  static void _push(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({
    required this.color,
    required this.icon,
    required this.title,
    required this.connected,
    required this.status,
    required this.description,
    this.actions = const [],
    this.extra = const [],
  });

  final Color color;
  final IconData icon;
  final String title;
  final bool connected;
  final String status;
  final String description;
  final List<Widget> actions;
  final List<Widget> extra;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  child: Icon(icon),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          Icon(
                            connected ? Icons.check_circle : Icons.circle_outlined,
                            size: 14,
                            color: connected ? Colors.green : scheme.outline,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(status,
                                style: TextStyle(
                                    fontSize: 13, color: scheme.outline)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(description),
            ...extra,
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: actions),
            ],
          ],
        ),
      ),
    );
  }
}
