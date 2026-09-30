import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'data/task_store.dart';
import 'screens/calendar_screen.dart';
import 'screens/more_screen.dart';
import 'screens/tasks_screen.dart';
import 'screens/today_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'de_DE';
  await initializeDateFormatting('de_DE');
  await taskStore.load();
  runApp(const HandyApp());
}

class HandyApp extends StatelessWidget {
  const HandyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Manager',
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

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _screens = [
    TodayScreen(),
    CalendarScreen(),
    TasksScreen(),
    MoreScreen(),
  ];

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
