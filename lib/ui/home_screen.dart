import 'package:flutter/material.dart';

import '../app.dart';
import 'clients_tab.dart';
import 'dashboard_tab.dart';
import 'journal_tab.dart';
import 'opening_screen.dart';
import 'settings_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    // Le matin, on commence par l'ouverture de la caisse.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!Deps.of(context).store.todayOpened) {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OpeningScreen()));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final deps = Deps.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([deps.store, deps.sync]),
      builder: (context, _) {
        final pages = [
          DashboardTab(onOpenTab: (i) => setState(() => _tab = i)),
          const ClientsTab(),
          const JournalTab(),
          const SettingsTab(),
        ];
        return Scaffold(
          body: IndexedStack(index: _tab, children: pages),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Accueil'),
              NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Clients'),
              NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'Journal'),
              NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Réglages'),
            ],
          ),
        );
      },
    );
  }
}
