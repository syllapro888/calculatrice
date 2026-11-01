import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/pin_service.dart';
import 'data/database.dart';
import 'data/store.dart';
import 'sync/sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr');
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final prefs = await SharedPreferences.getInstance();
  final db = await LocalDb.open();
  final store = await AppStore.load(db, prefs);
  final sync = SyncService(store, prefs);
  final pin = PinService(prefs);

  runApp(CarnetApp(store: store, sync: sync, pin: pin));

  // La synchro démarre en arrière-plan : l'app reste utilisable sans internet.
  sync.init();
}
