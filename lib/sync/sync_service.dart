import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models.dart';
import '../data/store.dart';
import '../firebase_options.dart';

/// Synchronise la base locale avec Firebase quand internet est disponible.
/// Les données sont rangées sous comptes/{uid}/... : chaque compte ne voit que les siennes.
class SyncService extends ChangeNotifier {
  SyncService(this._store, this._prefs);

  final AppStore _store;
  final SharedPreferences _prefs;

  bool configured = false;
  bool available = false;
  bool syncing = false;
  User? user;
  DateTime? lastSync;
  String? lastError;

  Timer? _debounce;
  Timer? _periodic;
  StreamSubscription<User?>? _authSub;

  static bool get isFirebaseConfigured {
    final o = DefaultFirebaseOptions.currentPlatform;
    return !o.apiKey.startsWith('A_CONFIGURER') && !o.projectId.startsWith('A_CONFIGURER');
  }

  Future<void> init() async {
    configured = isFirebaseConfigured;
    if (!configured) return;
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: false);
      available = true;
      _authSub = FirebaseAuth.instance.authStateChanges().listen((u) {
        user = u;
        notifyListeners();
        if (u != null) syncNow();
      });
      _store.onLocalChange = scheduleSync;
      _periodic = Timer.periodic(const Duration(minutes: 2), (_) => syncNow());
    } catch (e) {
      lastError = 'Firebase indisponible : $e';
    }
    notifyListeners();
  }

  // ---------- Compte ----------

  Future<String?> signIn(String email, String password) => _auth(() =>
      FirebaseAuth.instance.signInWithEmailAndPassword(email: email.trim(), password: password));

  Future<String?> register(String email, String password) => _auth(() =>
      FirebaseAuth.instance.createUserWithEmailAndPassword(email: email.trim(), password: password));

  Future<void> signOut() async {
    if (!available) return;
    await FirebaseAuth.instance.signOut();
  }

  Future<String?> _auth(Future<UserCredential> Function() action) async {
    if (!available) return 'La synchro en ligne n\'est pas configurée.';
    try {
      await action();
      return null;
    } on FirebaseAuthException catch (e) {
      return switch (e.code) {
        'invalid-email' => 'Adresse email invalide.',
        'user-not-found' || 'wrong-password' || 'invalid-credential' => 'Email ou mot de passe incorrect.',
        'email-already-in-use' => 'Ce compte existe déjà : utilisez "Se connecter".',
        'weak-password' => 'Mot de passe trop faible (6 caractères minimum).',
        'network-request-failed' => 'Pas de connexion internet.',
        _ => e.message ?? e.code,
      };
    } catch (e) {
      return '$e';
    }
  }

  // ---------- Synchro ----------

  void scheduleSync() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 3), syncNow);
  }

  DocumentReference<Map<String, dynamic>> get _root =>
      FirebaseFirestore.instance.collection('comptes').doc(user!.uid);

  Future<void> syncNow() async {
    if (!available || user == null || syncing) return;
    syncing = true;
    lastError = null;
    notifyListeners();
    try {
      await _push();
      await _pull();
      lastSync = DateTime.now();
    } catch (e) {
      lastError = e is TimeoutException ? 'Pas de connexion, nouvel essai plus tard.' : '$e';
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  Map<String, dynamic> _remote(Map<String, Object?> local) {
    final m = Map<String, dynamic>.from(local)..remove('synced');
    m['serverTs'] = FieldValue.serverTimestamp();
    return m;
  }

  Future<void> _push() async {
    final items = <(DocumentReference<Map<String, dynamic>>, Map<String, dynamic>, Future<void> Function())>[];
    for (final c in _store.unsyncedClients.toList()) {
      final at = c.updatedAt;
      items.add((_root.collection('clients').doc(c.id), _remote(c.toMap()), () async {
        if (c.updatedAt == at) await _store.markClientSynced(c);
      }));
    }
    for (final t in _store.unsyncedTxns.toList()) {
      final at = t.updatedAt;
      items.add((_root.collection('operations').doc(t.id), _remote(t.toMap()), () async {
        if (t.updatedAt == at) await _store.markTxnSynced(t);
      }));
    }
    for (final o in _store.unsyncedOpenings.toList()) {
      final at = o.updatedAt;
      items.add((_root.collection('ouvertures').doc(o.day), _remote(o.toMap()), () async {
        if (o.updatedAt == at) await _store.markOpeningSynced(o);
      }));
    }
    for (var i = 0; i < items.length; i += 400) {
      final chunk = items.sublist(i, i + 400 > items.length ? items.length : i + 400);
      final batch = FirebaseFirestore.instance.batch();
      for (final (ref, data, _) in chunk) {
        batch.set(ref, data);
      }
      await batch.commit().timeout(const Duration(seconds: 30));
      for (final (_, _, done) in chunk) {
        await done();
      }
    }
  }

  Future<void> _pull() async {
    final key = 'sync_last_pull_${user!.uid}';
    final since = Timestamp.fromMillisecondsSinceEpoch(_prefs.getInt(key) ?? 0);
    var maxTs = since.millisecondsSinceEpoch;
    var changed = false;

    Future<void> pullCollection(String name, Future<bool> Function(Map<String, dynamic>) apply) async {
      final snap = await _root
          .collection(name)
          .where('serverTs', isGreaterThanOrEqualTo: since)
          .get()
          .timeout(const Duration(seconds: 30));
      for (final doc in snap.docs) {
        final data = doc.data();
        final ts = data['serverTs'];
        if (ts is Timestamp && ts.millisecondsSinceEpoch > maxTs) maxTs = ts.millisecondsSinceEpoch;
        if (await apply(data)) changed = true;
      }
    }

    await pullCollection('clients', (d) => _store.applyRemoteClient(Client.fromMap(d)));
    await pullCollection('operations', (d) => _store.applyRemoteTxn(Txn.fromMap(d)));
    await pullCollection('ouvertures', (d) => _store.applyRemoteOpening(DayOpening.fromMap(d)));

    await _prefs.setInt(key, maxTs);
    if (changed) _store.refresh();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _periodic?.cancel();
    _authSub?.cancel();
    super.dispose();
  }
}
