import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/pin_service.dart';
import 'data/store.dart';
import 'sync/sync_service.dart';
import 'ui/calculator_screen.dart';
import 'ui/pin_setup_screen.dart';

/// Donne accès aux services partout dans l'app.
class Deps extends InheritedWidget {
  const Deps({super.key, required this.store, required this.sync, required this.pin, required super.child});

  final AppStore store;
  final SyncService sync;
  final PinService pin;

  static Deps of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<Deps>()!;

  @override
  bool updateShouldNotify(Deps oldWidget) => false;
}

const brandGreen = Color(0xFF0B6E4F);

ThemeData _theme(Brightness b) {
  final scheme = ColorScheme.fromSeed(seedColor: brandGreen, brightness: b);
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    appBarTheme: AppBarTheme(
      backgroundColor: b == Brightness.light ? brandGreen : scheme.surface,
      foregroundColor: b == Brightness.light ? Colors.white : scheme.onSurface,
    ),
    inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
    cardTheme: const CardThemeData(margin: EdgeInsets.zero),
  );
}

class CarnetApp extends StatefulWidget {
  const CarnetApp({super.key, required this.store, required this.sync, required this.pin});

  final AppStore store;
  final SyncService sync;
  final PinService pin;

  @override
  State<CarnetApp> createState() => _CarnetAppState();
}

class _CarnetAppState extends State<CarnetApp> with WidgetsBindingObserver {
  final _navKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Dès que l'app passe en arrière-plan, on revient à la calculatrice :
    // il faudra retaper le code pour rouvrir le carnet.
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _navKey.currentState?.popUntil((r) => r.isFirst);
    }
    if (state == AppLifecycleState.resumed) widget.sync.scheduleSync();
  }

  @override
  Widget build(BuildContext context) {
    return Deps(
      store: widget.store,
      sync: widget.sync,
      pin: widget.pin,
      child: MaterialApp(
        navigatorKey: _navKey,
        title: 'Calculatrice',
        debugShowCheckedModeBanner: false,
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        locale: const Locale('fr'),
        supportedLocales: const [Locale('fr'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: widget.pin.hasPin ? const CalculatorScreen() : const PinSetupScreen(firstLaunch: true),
      ),
    );
  }
}
