import 'package:flutter/material.dart';

import 'config.dart';
import 'screens/settings_screen.dart';
import 'screens/verify_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.load();
  runApp(const IdzExampleApp());
}

class IdzExampleApp extends StatelessWidget {
  const IdzExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IDz Flutter SDK Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0D47A1),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final ready = AppConfig.isReady;
    final body = !ready && _index == 0
        ? const SettingsScreen()
        : (_index == 0 ? const VerifyScreen() : const SettingsScreen());

    return Scaffold(
      appBar: AppBar(
        title: const Text('IDz SDK Demo'),
        actions: [
          if (!ready)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: Chip(
                  label: Text('No API key'),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
        ],
      ),
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.fact_check_outlined),
            selectedIcon: Icon(Icons.fact_check),
            label: 'Verify',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
