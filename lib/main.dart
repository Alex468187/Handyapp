import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quick_actions/quick_actions.dart';

import 'data/chore_store.dart';
import 'data/settings.dart';
import 'data/task_store.dart';
import 'screens/calendar_screen.dart';
import 'screens/chores_screen.dart';
import 'screens/more_screen.dart';
import 'screens/today_screen.dart';
import 'screens/voice_sheet.dart';
import 'services/notifications.dart';
import 'services/voice_input.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'de_DE';
  await initializeDateFormatting('de_DE');
  await Future.wait([taskStore.load(), choreStore.load(), settings.load()]);
  runApp(const KairoApp());
  Notifications.init();
}

class KairoApp extends StatelessWidget {
  const KairoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kairo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
      ),
      locale: const Locale('de', 'DE'),
      supportedLocales: const [Locale('de', 'DE')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _index = 0;
  DateTime? _pausedAt;

  static const _screens = [
    TodayScreen(),
    CalendarScreen(),
    ChoresScreen(),
    MoreScreen(),
  ];

  @override
  void initState() {
    super.initState();
    if (!VoiceInput.supported) return;
    WidgetsBinding.instance.addObserver(this);

    var launchedByShortcut = false;
    const quickActions = QuickActions();
    quickActions.initialize((type) {
      if (type == 'speak') {
        launchedByShortcut = true;
        _listenSoon();
      }
    });
    quickActions.setShortcutItems(const [
      ShortcutItem(type: 'speak', localizedTitle: 'Sprechen'),
    ]);

    // „Hey Google, öffne Kairo“ → direkt zuhören.
    if (settings.autoListen) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (!launchedByShortcut) _listenSoon();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final away = _pausedAt == null
          ? Duration.zero
          : DateTime.now().difference(_pausedAt!);
      _pausedAt = null;
      taskStore.refresh(); // „Heute“ neu berechnen, falls ein neuer Tag ist
      if (settings.autoListen && away > const Duration(minutes: 2)) {
        _listenSoon();
      }
    }
  }

  void _listenSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) openVoice(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.today), label: 'Heute'),
          NavigationDestination(
              icon: Icon(Icons.calendar_month), label: 'Kalender'),
          NavigationDestination(icon: Icon(Icons.checklist), label: 'Aufgaben'),
          NavigationDestination(icon: Icon(Icons.apps), label: 'Mehr'),
        ],
      ),
    );
  }
}
