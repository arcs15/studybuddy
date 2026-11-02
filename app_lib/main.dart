import 'package:flutter/material.dart';
import 'db.dart';
import 'native.dart';
import 'screens/expenses_screen.dart';
import 'screens/home_screen.dart';
import 'screens/more_screen.dart';
import 'screens/notes_screen.dart';
import 'screens/tasks_screen.dart';
import 'theme_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  themeNotifier.value = themeFromName(await AppDb.getSetting('theme_mode'));
  AppDb.onChange = Native.requestSync; // refresh reminders + widget after any change
  runApp(const StudyBuddyApp());
}

ThemeData _theme(Brightness b) => ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7C4DFF), brightness: b),
    );

class StudyBuddyApp extends StatelessWidget {
  const StudyBuddyApp({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<ThemeMode>(
        valueListenable: themeNotifier,
        builder: (context, mode, _) => MaterialApp(
          title: 'StudyBuddy',
          debugShowCheckedModeBanner: false,
          themeMode: mode,
          theme: _theme(Brightness.light),
          darkTheme: _theme(Brightness.dark),
          home: const Shell(),
        ),
      );
}

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _i = 0;
  static const _pages = [HomeScreen(), ExpensesScreen(), NotesScreen(), TasksScreen(), MoreScreen()];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Native.requestNotifPermission();
      Native.requestSync();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: _pages[_i], // switching tabs rebuilds the page so data is always fresh
        bottomNavigationBar: NavigationBar(
          selectedIndex: _i,
          onDestinationSelected: (v) => setState(() => _i = v),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.payments_outlined), selectedIcon: Icon(Icons.payments), label: 'Expenses'),
            NavigationDestination(icon: Icon(Icons.sticky_note_2_outlined), selectedIcon: Icon(Icons.sticky_note_2), label: 'Notes'),
            NavigationDestination(icon: Icon(Icons.checklist_outlined), selectedIcon: Icon(Icons.checklist), label: 'Tasks'),
            NavigationDestination(icon: Icon(Icons.apps_outlined), selectedIcon: Icon(Icons.apps), label: 'More'),
          ],
        ),
      );
}
