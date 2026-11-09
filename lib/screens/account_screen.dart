import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/sync.dart';
import '../util/format.dart';

/// Konto: anmelden, damit Handy, PC und Claude dieselben Daten sehen.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: sync,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('Konto & Abgleich')),
        body: sync.signedIn ? const _SignedIn() : const _SignInForm(),
      ),
    );
  }
}

class _SignedIn extends StatelessWidget {
  const _SignedIn();

  @override
  Widget build(BuildContext context) {
    final last = sync.lastSync;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.cloud_done),
            title: Text(sync.user?.email ?? ''),
            subtitle: Text(sync.busy
                ? 'Gleiche ab …'
                : last == null
                    ? 'Noch nicht abgeglichen'
                    : 'Zuletzt abgeglichen: ${formatTime(last)}'),
          ),
        ),
        if (sync.lastError != null)
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: ListTile(
              leading: const Icon(Icons.error_outline),
              title: const Text('Abgleich fehlgeschlagen'),
              subtitle: Text(sync.lastError!),
            ),
          ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: sync.busy ? null : sync.syncNow,
          icon: const Icon(Icons.sync),
          label: const Text('Jetzt abgleichen'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Abmelden?'),
                content: const Text(
                    'Deine Einträge bleiben auf diesem Gerät, werden aber '
                    'nicht mehr abgeglichen.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Abbrechen')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Abmelden')),
                ],
              ),
            );
            if (ok == true) await sync.signOut();
          },
          icon: const Icon(Icons.logout),
          label: const Text('Abmelden'),
        ),
        const SizedBox(height: 24),
        const Text(
          'Termine, Aufgaben und Notizen werden automatisch zwischen deinen '
          'Geräten abgeglichen – und Claude kann sie für dich eintragen.',
          style: TextStyle(color: Colors.grey),
        ),
      ],
    );
  }
}

class _SignInForm extends StatefulWidget {
  const _SignInForm();

  @override
  State<_SignInForm> createState() => _SignInFormState();
}

class _SignInFormState extends State<_SignInForm> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _message;
  bool _isError = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(bool register) async {
    final email = _email.text.trim();
    final password = _password.text;
    if (!email.contains('@') || password.length < 6) {
      setState(() {
        _message = 'Bitte E-Mail und ein Passwort mit mindestens 6 Zeichen eingeben.';
        _isError = true;
      });
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (register) {
        final direct = await sync.signUp(email, password);
        if (!direct && mounted) {
          setState(() {
            _message = 'Fast geschafft: Öffne die Bestätigungsmail und tippe auf '
                'den Link. (Danach kommt evtl. eine Fehlerseite – das ist egal.) '
                'Dann hier auf „Anmelden“ tippen.';
            _isError = false;
          });
        }
      } else {
        await sync.signIn(email, password);
      }
    } on AuthException catch (e) {
      setState(() {
        _message = _translate(e.message);
        _isError = true;
      });
    } catch (e) {
      setState(() {
        _message = 'Fehler: $e';
        _isError = true;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _translate(String m) {
    final l = m.toLowerCase();
    if (l.contains('invalid login')) return 'E-Mail oder Passwort falsch.';
    if (l.contains('not confirmed')) {
      return 'Bitte zuerst den Link in der Bestätigungsmail antippen.';
    }
    if (l.contains('already registered')) {
      return 'Dieses Konto gibt es schon – tippe auf „Anmelden“.';
    }
    return m;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Melde dich an, damit Handy, PC und Claude dieselben Termine, '
          'Aufgaben und Notizen sehen. Beim ersten Mal „Konto erstellen“, '
          'auf weiteren Geräten „Anmelden“.',
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(
              labelText: 'E-Mail', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _password,
          obscureText: true,
          autofillHints: const [AutofillHints.password],
          decoration: const InputDecoration(
              labelText: 'Passwort', border: OutlineInputBorder()),
          onSubmitted: (_) => _run(false),
        ),
        if (_message != null) ...[
          const SizedBox(height: 12),
          Text(_message!,
              style: TextStyle(color: _isError ? scheme.error : scheme.primary)),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : () => _run(false),
          child: const Text('Anmelden'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _busy ? null : () => _run(true),
          child: const Text('Konto erstellen'),
        ),
        if (_busy) ...[
          const SizedBox(height: 16),
          const Center(child: CircularProgressIndicator()),
        ],
      ],
    );
  }
}
