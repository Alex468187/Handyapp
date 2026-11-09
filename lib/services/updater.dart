import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

/// Build-Nummer dieser Version (vom Build-Server per --dart-define gesetzt).
const buildNumber = int.fromEnvironment('BUILD_NUMBER');

const _latestRelease =
    'https://api.github.com/repos/Alex468187/Handyapp/releases/latest';

class UpdateInfo {
  const UpdateInfo(this.build, this.notes, this.url);
  final int build;
  final String notes;
  final String url;
}

/// Sucht auf GitHub nach einer neueren Version und installiert sie.
class Updater {
  static DateTime? _lastAutoCheck;
  static bool _busy = false;

  static bool get supported =>
      buildNumber > 0 && (Platform.isAndroid || Platform.isWindows);

  static Future<UpdateInfo?> check() async {
    final res = await http.get(Uri.parse(_latestRelease), headers: {
      'Accept': 'application/vnd.github+json'
    }).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception('GitHub antwortet mit ${res.statusCode}');
    }
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    final tag = (j['tag_name'] ?? '') as String;
    final build = int.tryParse(tag.replaceFirst('build-', ''));
    if (build == null || build <= buildNumber) return null;
    final want = Platform.isAndroid ? 'Summer.apk' : 'Summer-Windows.zip';
    final asset = (j['assets'] as List)
        .cast<Map<String, dynamic>>()
        .where((a) => a['name'] == want)
        .firstOrNull;
    if (asset == null) return null;
    final notes = ((j['body'] ?? '') as String).split('\n').first.trim();
    return UpdateInfo(build, notes, asset['browser_download_url'] as String);
  }

  /// Beim Start / Zurückkehren: höchstens alle 6 Stunden still nachsehen.
  static Future<void> autoCheck(BuildContext context) async {
    if (!supported || _busy) return;
    final now = DateTime.now();
    if (_lastAutoCheck != null &&
        now.difference(_lastAutoCheck!) < const Duration(hours: 6)) {
      return;
    }
    _lastAutoCheck = now;
    try {
      final info = await check();
      if (info != null && context.mounted) await _offer(context, info);
    } catch (_) {
      // Kein Internet o. Ä. – beim nächsten Mal wieder versuchen.
      _lastAutoCheck = null;
    }
  }

  /// Knopf „Nach Updates suchen“.
  static Future<void> manualCheck(BuildContext context) async {
    if (!supported || _busy) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final info = await check();
      if (!context.mounted) return;
      if (info == null) {
        messenger.showSnackBar(const SnackBar(
            content: Text('Du hast schon die neueste Version.')));
      } else {
        await _offer(context, info);
      }
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('Suche fehlgeschlagen: $e')));
    }
  }

  static Future<void> _offer(BuildContext context, UpdateInfo info) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.system_update),
        title: const Text('Update verfügbar'),
        content: Text('Build ${info.build} ist da (du hast Build $buildNumber).'
            '${info.notes.isEmpty ? '' : '\n\nNeu: ${info.notes}'}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Später')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Jetzt installieren')),
        ],
      ),
    );
    if (go == true && context.mounted) await _install(context, info);
  }

  static Future<void> _install(BuildContext context, UpdateInfo info) async {
    _busy = true;
    final progress = ValueNotifier<double?>(null);
    final navigator = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Lade Update …'),
          content: ValueListenableBuilder<double?>(
            valueListenable: progress,
            builder: (_, p, __) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(value: p),
                const SizedBox(height: 8),
                Text(p == null ? '' : '${(p * 100).round()} %'),
              ],
            ),
          ),
        ),
      ),
    );
    try {
      final file = await _download(info, progress);
      navigator.pop();
      if (Platform.isAndroid) {
        final r = await OpenFilex.open(file.path,
            type: 'application/vnd.android.package-archive');
        if (r.type != ResultType.done) {
          messenger.showSnackBar(SnackBar(
              content: Text('Installation nicht gestartet: ${r.message}')));
        }
      } else {
        await _replaceWindowsApp(file);
      }
    } catch (e) {
      navigator.pop();
      messenger.showSnackBar(
          SnackBar(content: Text('Update fehlgeschlagen: $e')));
    } finally {
      _busy = false;
    }
  }

  static Future<File> _download(
      UpdateInfo info, ValueNotifier<double?> progress) async {
    Directory dir;
    if (Platform.isAndroid) {
      final ext = await getExternalCacheDirectories();
      dir = (ext != null && ext.isNotEmpty)
          ? ext.first
          : await getTemporaryDirectory();
    } else {
      dir = await getTemporaryDirectory();
    }
    final name = Platform.isAndroid ? 'Summer-update.apk' : 'Summer-update.zip';
    final file = File('${dir.path}${Platform.pathSeparator}$name');

    final client = http.Client();
    try {
      final res = await client.send(http.Request('GET', Uri.parse(info.url)));
      if (res.statusCode != 200) {
        throw Exception('Download: HTTP ${res.statusCode}');
      }
      final total = res.contentLength ?? 0;
      var received = 0;
      final sink = file.openWrite();
      await for (final chunk in res.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) progress.value = received / total;
      }
      await sink.close();
    } finally {
      client.close();
    }
    return file;
  }

  /// Windows: Hilfsskript entpackt die neue Version über die alte und
  /// startet Summer neu, sobald diese Version beendet ist.
  static Future<void> _replaceWindowsApp(File zip) async {
    final exe = Platform.resolvedExecutable;
    final dir = File(exe).parent.path;
    final me = '$pid';
    final script = File('${zip.parent.path}\\summer-update.cmd');
    await script.writeAsString([
      '@echo off',
      ':wait',
      'tasklist /FI "PID eq $me" | find "$me" >nul',
      'if not errorlevel 1 (timeout /t 1 /nobreak >nul & goto wait)',
      'powershell -NoProfile -Command "Expand-Archive -Force -LiteralPath \'${zip.path}\' -DestinationPath \'$dir\'"',
      'start "" "$exe"',
      '',
    ].join('\r\n'));
    await Process.start('cmd', ['/c', script.path],
        mode: ProcessStartMode.detached);
    exit(0);
  }
}
