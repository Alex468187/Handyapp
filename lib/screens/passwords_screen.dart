import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/secret.dart';
import '../models/task.dart' show newId;
import '../services/vault.dart';

/// Passwort-Manager: einrichten, entsperren, Konten verwalten.
class PasswordsScreen extends StatelessWidget {
  const PasswordsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: vault,
      builder: (context, _) {
        if (!vault.exists) return const _SetupView();
        if (!vault.unlocked) return const _LockedView();
        return const _ListView();
      },
    );
  }
}

// ---------------------------------------------------------------- Einrichten

class _SetupView extends StatefulWidget {
  const _SetupView();

  @override
  State<_SetupView> createState() => _SetupViewState();
}

class _SetupViewState extends State<_SetupView> {
  final _pw1 = TextEditingController();
  final _pw2 = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _pw1.dispose();
    _pw2.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_pw1.text.length < 8) {
      setState(() => _error = 'Mindestens 8 Zeichen.');
      return;
    }
    if (_pw1.text != _pw2.text) {
      setState(() => _error = 'Die beiden Passwörter sind nicht gleich.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    await vault.create(_pw1.text);
    if (vault.bioAvailable) await vault.enableBio();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Passwörter')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Icon(Icons.lock, size: 56),
          const SizedBox(height: 12),
          const Text('Master-Passwort festlegen',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Text(
              'Damit werden alle deine Passwörter verschlüsselt – auf dem Handy, '
              'auf dem PC und online. Niemand außer dir kann sie lesen, auch '
              'Claude nicht.'),
          const SizedBox(height: 8),
          Text(
            'Wichtig: Wenn du das Master-Passwort vergisst, sind die '
            'gespeicherten Passwörter weg. Schreib es dir an einen sicheren Ort.',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _pw1,
            obscureText: true,
            decoration: const InputDecoration(
                labelText: 'Master-Passwort', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pw2,
            obscureText: true,
            decoration: const InputDecoration(
                labelText: 'Nochmal eingeben', border: OutlineInputBorder()),
            onSubmitted: (_) => _create(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _create,
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Tresor anlegen'),
          ),
          const SizedBox(height: 16),
          const Text(
            'Hast du den Tresor schon auf einem anderen Gerät angelegt? Dann '
            'melde dich hier zuerst unter Mehr → Konto & Abgleich an.',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Gesperrt

class _LockedView extends StatefulWidget {
  const _LockedView();

  @override
  State<_LockedView> createState() => _LockedViewState();
}

class _LockedViewState extends State<_LockedView> {
  final _pw = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (vault.bioEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _bio());
    }
  }

  @override
  void dispose() {
    _pw.dispose();
    super.dispose();
  }

  Future<void> _bio() async {
    await vault.unlockWithBio();
  }

  Future<void> _unlock() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await vault.unlock(_pw.text);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _busy = false;
        _error = 'Falsches Master-Passwort.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Passwörter')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 24),
          const Icon(Icons.lock, size: 56),
          const SizedBox(height: 16),
          TextField(
            controller: _pw,
            obscureText: true,
            autofocus: !vault.bioEnabled,
            decoration: const InputDecoration(
                labelText: 'Master-Passwort', border: OutlineInputBorder()),
            onSubmitted: (_) => _unlock(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _unlock,
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Entsperren'),
          ),
          if (vault.bioEnabled) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _bio,
              icon: const Icon(Icons.fingerprint),
              label: const Text('Mit Fingerabdruck'),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Liste

class _ListView extends StatefulWidget {
  const _ListView();

  @override
  State<_ListView> createState() => _ListViewState();
}

class _ListViewState extends State<_ListView> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.toLowerCase();
    final list = vault.entries
        .where((s) =>
            q.isEmpty ||
            s.service.toLowerCase().contains(q) ||
            s.email.toLowerCase().contains(q) ||
            s.username.toLowerCase().contains(q))
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Passwörter'),
        actions: [
          if (vault.bioAvailable)
            IconButton(
              tooltip: vault.bioEnabled
                  ? 'Fingerabdruck ausschalten'
                  : 'Fingerabdruck einschalten',
              icon: Icon(vault.bioEnabled
                  ? Icons.fingerprint
                  : Icons.fingerprint_outlined),
              onPressed: () async {
                if (vault.bioEnabled) {
                  await vault.disableBio();
                } else {
                  await vault.enableBio();
                }
              },
            ),
          IconButton(
            tooltip: 'Sperren',
            icon: const Icon(Icons.lock_outline),
            onPressed: vault.lock,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => _edit(context, null),
        icon: const Icon(Icons.add),
        label: const Text('Konto hinzufügen'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 96),
        children: [
          Padding(
            padding: const EdgeInsets.all(4),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Suchen',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          if (list.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Text('Noch keine Konten.\nTippe auf „Konto hinzufügen“.',
                  textAlign: TextAlign.center),
            ),
          for (final s in list)
            Card(
              child: ListTile(
                leading: CircleAvatar(
                    child: Text(s.service.isEmpty
                        ? '?'
                        : s.service.characters.first.toUpperCase())),
                title: Text(s.service.isEmpty ? 'Ohne Namen' : s.service),
                subtitle: s.login.isEmpty ? null : Text(s.login),
                trailing: IconButton(
                  tooltip: 'Passwort kopieren',
                  icon: const Icon(Icons.copy),
                  onPressed: s.password.isEmpty
                      ? null
                      : () => copySecret(context, s.password, 'Passwort'),
                ),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => _DetailScreen(id: s.id))),
              ),
            ),
        ],
      ),
    );
  }
}

void _edit(BuildContext context, Secret? s) {
  Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => _EditScreen(secret: s)));
}

Timer? _clipTimer;

/// Kopiert und löscht die Zwischenablage nach 45 Sekunden wieder.
void copySecret(BuildContext context, String value, String what) {
  Clipboard.setData(ClipboardData(text: value));
  _clipTimer?.cancel();
  _clipTimer = Timer(const Duration(seconds: 45), () async {
    final now = await Clipboard.getData(Clipboard.kTextPlain);
    if (now?.text == value) Clipboard.setData(const ClipboardData(text: ''));
  });
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$what kopiert (wird in 45 Sek. gelöscht)'),
      duration: const Duration(seconds: 2)));
}

// ---------------------------------------------------------------- Details

class _DetailScreen extends StatefulWidget {
  const _DetailScreen({required this.id});
  final String id;

  @override
  State<_DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<_DetailScreen> {
  bool _show = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: vault,
      builder: (context, _) {
        final s = vault.entries.where((e) => e.id == widget.id).firstOrNull;
        if (s == null || !vault.unlocked) {
          // Gesperrt oder gelöscht → zurück zur Liste.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.of(context).maybePop();
          });
          return const Scaffold();
        }
        Widget row(IconData icon, String label, String value,
            {bool secret = false}) {
          if (value.isEmpty) return const SizedBox.shrink();
          return Card(
            child: ListTile(
              leading: Icon(icon),
              title: Text(label, style: const TextStyle(fontSize: 13)),
              subtitle: Text(secret && !_show ? '••••••••••' : value,
                  style: const TextStyle(fontSize: 17)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (secret)
                    IconButton(
                      icon:
                          Icon(_show ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _show = !_show),
                    ),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () => copySecret(context, value, label),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(s.service.isEmpty ? 'Konto' : s.service),
            actions: [
              IconButton(
                tooltip: 'Bearbeiten',
                icon: const Icon(Icons.edit),
                onPressed: () => _edit(context, s),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              row(Icons.alternate_email, 'E-Mail', s.email),
              row(Icons.person, 'Benutzername', s.username),
              row(Icons.key, 'Passwort', s.password, secret: true),
              row(Icons.phone, 'Telefonnummer', s.phone),
              row(Icons.notes, 'Notiz', s.note),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------- Bearbeiten

class _EditScreen extends StatefulWidget {
  const _EditScreen({this.secret});
  final Secret? secret;

  @override
  State<_EditScreen> createState() => _EditScreenState();
}

class _EditScreenState extends State<_EditScreen> {
  late final _service = TextEditingController(text: widget.secret?.service);
  late final _email = TextEditingController(text: widget.secret?.email);
  late final _username = TextEditingController(text: widget.secret?.username);
  late final _password = TextEditingController(text: widget.secret?.password);
  late final _phone = TextEditingController(text: widget.secret?.phone);
  late final _note = TextEditingController(text: widget.secret?.note);
  bool _show = false;

  @override
  void dispose() {
    for (final c in [_service, _email, _username, _password, _phone, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_service.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Bitte gib an, wofür das Konto ist (z. B. „Amazon“).')));
      return;
    }
    final s = Secret(
      id: widget.secret?.id ?? newId(),
      service: _service.text.trim(),
      email: _email.text.trim(),
      username: _username.text.trim(),
      password: _password.text,
      phone: _phone.text.trim(),
      note: _note.text.trim(),
    );
    await vault.save(s);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konto löschen?'),
        content: const Text('Das gespeicherte Passwort ist danach weg.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Löschen')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    vault.delete(widget.secret!.id);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    Widget field(TextEditingController c, String label, IconData icon,
            {TextInputType? type, Widget? suffix, bool obscure = false}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            controller: c,
            keyboardType: type,
            obscureText: obscure,
            decoration: InputDecoration(
              labelText: label,
              prefixIcon: Icon(icon),
              suffixIcon: suffix,
              border: const OutlineInputBorder(),
            ),
          ),
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.secret == null ? 'Konto hinzufügen' : 'Bearbeiten'),
        actions: [
          if (widget.secret != null)
            IconButton(
                tooltip: 'Löschen',
                icon: const Icon(Icons.delete_outline),
                onPressed: _delete),
          IconButton(
              tooltip: 'Speichern',
              icon: const Icon(Icons.check),
              onPressed: _save),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          field(_service, 'Dienst (z. B. Amazon)', Icons.apps),
          field(_email, 'E-Mail', Icons.alternate_email,
              type: TextInputType.emailAddress),
          field(_username, 'Benutzername', Icons.person),
          field(
            _password,
            'Passwort',
            Icons.key,
            obscure: !_show,
            suffix: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Anzeigen',
                  icon: Icon(_show ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _show = !_show),
                ),
                IconButton(
                  tooltip: 'Sicheres Passwort erzeugen',
                  icon: const Icon(Icons.auto_fix_high),
                  onPressed: () => setState(() {
                    _password.text = generatePassword();
                    _show = true;
                  }),
                ),
              ],
            ),
          ),
          field(_phone, 'Telefonnummer', Icons.phone, type: TextInputType.phone),
          TextField(
            controller: _note,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Notiz',
              prefixIcon: Icon(Icons.notes),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check),
            label: const Text('Speichern'),
          ),
        ],
      ),
    );
  }
}
