import '../widgets/app_drawer.dart';
import 'package:flutter/material.dart';

import '../data/message_store.dart';
import '../util/format.dart';

const _waGreen = Color(0xFF25D366);
const _gmailRed = Color(0xFFEA4335);

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  bool _onlyImportant = true;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: messageStore,
      builder: (context, _) {
        final store = messageStore;
        final list = store.visible(onlyImportant: _onlyImportant);
        return Scaffold(
          appBar: AppBar(
            leading: const MenuButton(),
            title: const Text('Nachrichten'),
            actions: [
              if (store.accounts.isNotEmpty)
                IconButton(
                  tooltip: 'Gmail-Konten',
                  icon: const Icon(Icons.alternate_email),
                  onPressed: () => _chooseAccounts(context),
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
            children: [
              if (!store.enabled) const _PermissionCard(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                        value: true,
                        icon: Icon(Icons.star),
                        label: Text('Wichtig')),
                    ButtonSegment(
                        value: false,
                        icon: Icon(Icons.forum),
                        label: Text('Alle')),
                  ],
                  selected: {_onlyImportant},
                  onSelectionChanged: (s) =>
                      setState(() => _onlyImportant = s.first),
                ),
              ),
              if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    _onlyImportant
                        ? 'Noch keine wichtigen Kontakte.\n\nWechsle zu „Alle“, '
                            'öffne einen Chat und tippe auf den Stern – dann '
                            'landet er hier.'
                        : 'Noch keine Nachrichten.\n\nNeue WhatsApp-Nachrichten '
                            'und Mails erscheinen hier, sobald sie ankommen.',
                    textAlign: TextAlign.center,
                  ),
                ),
              for (final c in list) _ConversationTile(c),
            ],
          ),
        );
      },
    );
  }

  Future<void> _chooseAccounts(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => ListenableBuilder(
        listenable: messageStore,
        builder: (ctx, _) => AlertDialog(
          title: const Text('Welche Gmail-Konten anzeigen?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final a in messageStore.accounts.toList()..sort())
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(a),
                  value: !messageStore.hiddenAccounts.contains(a),
                  onChanged: (v) =>
                      messageStore.setAccountHidden(a, v != true),
                ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Fertig')),
          ],
        ),
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Zugriff auf Benachrichtigungen erlauben',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            const Text(
                'Damit Summer deine WhatsApp-Nachrichten und Mails zeigen kann, '
                'muss sie die Benachrichtigungen mitlesen dürfen. Die Nachrichten '
                'bleiben nur auf diesem Handy.'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: messageStore.openSettings,
              child: const Text('Zugriff erlauben'),
            ),
            const SizedBox(height: 12),
            const Text(
                'Ist Summer dort ausgegraut („Eingeschränkte Einstellung“)? '
                'Dann zuerst: App-Info öffnen → ⋮ oben rechts → '
                '„Eingeschränkte Einstellungen zulassen“ – danach nochmal '
                '„Zugriff erlauben“.',
                style: TextStyle(fontSize: 13)),
            TextButton(
              onPressed: messageStore.openAppInfo,
              child: const Text('App-Info öffnen'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceIcon extends StatelessWidget {
  const _SourceIcon(this.isMail);
  final bool isMail;

  @override
  Widget build(BuildContext context) => CircleAvatar(
        backgroundColor: isMail ? _gmailRed : _waGreen,
        foregroundColor: Colors.white,
        child: Icon(isMail ? Icons.mail : Icons.chat),
      );
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile(this.c);
  final Conversation c;

  @override
  Widget build(BuildContext context) {
    final unread = messageStore.unread(c);
    final last = c.last;
    final preview = last.isMail
        ? last.text.split('\n').first
        : '${last.outgoing ? 'Du: ' : (last.sender != c.name ? '${last.sender}: ' : '')}${last.text}';
    return Card(
      child: ListTile(
        leading: _SourceIcon(c.isMail),
        title: Row(
          children: [
            Expanded(
              child: Text(c.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontWeight:
                          unread > 0 ? FontWeight.bold : FontWeight.normal)),
            ),
            if (messageStore.important.contains(c.key))
              const Icon(Icons.star, size: 16, color: Colors.amber),
          ],
        ),
        subtitle:
            Text(preview, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(formatWhen(last.time), style: const TextStyle(fontSize: 12)),
            if (unread > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Badge(label: Text('$unread')),
              ),
          ],
        ),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ConversationScreen(chatKey: c.key))),
      ),
    );
  }
}

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({super.key, required this.chatKey});
  final String chatKey;

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final _input = TextEditingController();
  bool _canReply = false;
  bool _sending = false;

  Conversation? get _c => messageStore.conversations
      .where((c) => c.key == widget.chatKey)
      .firstOrNull;

  @override
  void initState() {
    super.initState();
    final c = _c;
    if (c != null) {
      messageStore.markRead(c);
      if (!c.isMail) {
        messageStore.canReply(c).then((v) {
          if (mounted) setState(() => _canReply = v);
        });
      }
    }
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send(Conversation c) async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    final ok = await messageStore.reply(c, text);
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) {
      _input.clear();
    } else {
      setState(() => _canReply = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Antworten geht gerade nicht – öffne den Chat in WhatsApp.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: messageStore,
      builder: (context, _) {
        final c = _c;
        if (c == null) {
          return Scaffold(appBar: AppBar(), body: const SizedBox());
        }
        final important = messageStore.important.contains(c.key);
        final scheme = Theme.of(context).colorScheme;
        final msgs = c.messages.reversed.toList();
        return Scaffold(
          appBar: AppBar(
            title: Text(c.name, overflow: TextOverflow.ellipsis),
            actions: [
              IconButton(
                tooltip: important ? 'Nicht mehr wichtig' : 'Als wichtig markieren',
                icon: Icon(important ? Icons.star : Icons.star_border,
                    color: important ? Colors.amber : null),
                onPressed: () => messageStore.toggleImportant(c.key),
              ),
              IconButton(
                tooltip: c.isMail ? 'In Gmail öffnen' : 'In WhatsApp öffnen',
                icon: const Icon(Icons.open_in_new),
                onPressed: () => messageStore.openInApp(c),
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: msgs.length,
                  itemBuilder: (context, i) {
                    final m = msgs[i];
                    final mine = m.outgoing;
                    return Align(
                      alignment:
                          mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.8),
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: mine
                              ? scheme.primaryContainer
                              : scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!mine && m.sender != c.name)
                              Text(m.sender,
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: scheme.primary)),
                            if (m.isMail && m.account != null)
                              Text('an ${m.account}',
                                  style: TextStyle(
                                      fontSize: 12, color: scheme.outline)),
                            Text(m.text),
                            const SizedBox(height: 2),
                            Text(formatWhen(m.time),
                                style: TextStyle(
                                    fontSize: 11, color: scheme.outline)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (!c.isMail)
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                    child: _canReply
                        ? Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _input,
                                  minLines: 1,
                                  maxLines: 4,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  decoration: const InputDecoration(
                                      hintText: 'Antworten …',
                                      border: OutlineInputBorder()),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton.filled(
                                onPressed: _sending ? null : () => _send(c),
                                icon: const Icon(Icons.send),
                              ),
                            ],
                          )
                        : Text(
                            'Antworten geht, solange die WhatsApp-Benachrichtigung '
                            'noch da ist. Sonst oben rechts in WhatsApp öffnen.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: scheme.outline),
                          ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
