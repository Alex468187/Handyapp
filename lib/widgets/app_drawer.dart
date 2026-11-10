import 'package:flutter/material.dart';

import '../data/message_store.dart';
import '../screens/account_screen.dart';
import '../screens/connections_screen.dart';
import '../screens/notes_screen.dart';
import '../screens/passwords_screen.dart';
import '../screens/tasks_screen.dart';
import '../services/sync.dart';

/// Schlüssel des Haupt-Gerüsts – damit jede Seite das Menü öffnen kann.
final homeScaffoldKey = GlobalKey<ScaffoldState>();

/// ☰-Knopf oben links in den Haupt-Seiten.
class MenuButton extends StatelessWidget {
  const MenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    // Als eigene Seite geöffnet (nicht als Tab): normaler Zurück-Pfeil.
    if (Navigator.of(context).canPop()) return const BackButton();
    return IconButton(
      tooltip: 'Menü',
      icon: const Icon(Icons.menu),
      onPressed: () => homeScaffoldKey.currentState?.openDrawer(),
    );
  }
}

/// Seitenleiste mit allen Bereichen von Summer.
class AppDrawer extends StatelessWidget {
  const AppDrawer({
    super.key,
    required this.tabLabels,
    required this.selectedTab,
    required this.onTab,
  });

  /// Beschriftung + Symbol der unteren Tabs (in derselben Reihenfolge).
  final List<(IconData, String)> tabLabels;
  final int selectedTab;
  final ValueChanged<int> onTab;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    void open(Widget page) {
      Navigator.of(context).pop(); // Menü schließen
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    }

    return NavigationDrawer(
      selectedIndex: selectedTab,
      onDestinationSelected: (i) {
        Navigator.of(context).pop();
        onTab(i);
      },
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 20, 16, 12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(Icons.wb_sunny,
                    color: theme.colorScheme.onPrimaryContainer),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ListenableBuilder(
                  listenable: sync,
                  builder: (context, _) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Summer', style: theme.textTheme.titleLarge),
                      Text(
                        sync.signedIn
                            ? sync.user?.email ?? ''
                            : 'Nicht angemeldet',
                        style: theme.textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        for (final (icon, label) in tabLabels)
          NavigationDrawerDestination(icon: Icon(icon), label: Text(label)),
        const Padding(
          padding: EdgeInsets.fromLTRB(28, 12, 28, 8),
          child: Divider(),
        ),
        _Item(Icons.sticky_note_2, 'Notizen',
            () => open(const NotesScreen())),
        _Item(Icons.lock, 'Passwörter', () => open(const PasswordsScreen())),
        _Item(Icons.event_note, 'Alle Termine',
            () => open(const TasksScreen())),
        const Padding(
          padding: EdgeInsets.fromLTRB(28, 12, 28, 8),
          child: Divider(),
        ),
        _Item(Icons.hub, 'Verbindungen', () => open(const ConnectionsScreen()),
            subtitle: MessageStore.supported
                ? 'Gmail, WhatsApp, Claude'
                : 'Claude'),
        _Item(Icons.cloud, 'Konto & Abgleich',
            () => open(const AccountScreen())),
      ],
    );
  }
}

class _Item extends StatelessWidget {
  const _Item(this.icon, this.label, this.onTap, {this.subtitle});
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: ListTile(
          shape: const StadiumBorder(),
          leading: Icon(icon),
          title: Text(label),
          subtitle: subtitle == null ? null : Text(subtitle!),
          onTap: onTap,
        ),
      );
}
