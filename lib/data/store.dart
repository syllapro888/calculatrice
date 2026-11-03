import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/money.dart';
import 'database.dart';
import 'ledger.dart';
import 'models.dart';

const _uuid = Uuid();

/// Toutes les données de l'app, en mémoire, sauvegardées dans la base locale.
class AppStore extends ChangeNotifier {
  AppStore(this._db);

  final LocalDb _db;

  final Map<String, Client> _clients = {};
  final Map<String, Txn> _txns = {};
  final Map<String, DayOpening> _openings = {};

  /// Appelé après chaque modification locale (pour lancer la synchro).
  VoidCallback? onLocalChange;

  static Future<AppStore> load(LocalDb db) async {
    final s = AppStore(db);
    await s.reload();
    return s;
  }

  Future<void> reload() async {
    _clients
      ..clear()
      ..addEntries((await _db.allClients()).map((c) => MapEntry(c.id, c)));
    _txns
      ..clear()
      ..addEntries((await _db.allTxns()).map((t) => MapEntry(t.id, t)));
    _openings
      ..clear()
      ..addEntries((await _db.allOpenings()).map((o) => MapEntry(o.day, o)));
    notifyListeners();
  }

  // ---------- Lecture ----------

  List<Client> get clients {
    final list = _clients.values.where((c) => !c.deleted).toList();
    list.sort((a, b) {
      final ta = lastTxnOf(a.id)?.createdAt ?? a.createdAt;
      final tb = lastTxnOf(b.id)?.createdAt ?? b.createdAt;
      return tb.compareTo(ta);
    });
    return list;
  }

  Client? client(String? id) => id == null ? null : _clients[id];

  String clientName(String? id) {
    final c = client(id);
    if (c == null) return 'Client de passage';
    return c.deleted ? '${c.name} (supprimé)' : c.name;
  }

  /// Opérations actives, de la plus ancienne à la plus récente.
  List<Txn> get txns {
    final list = _txns.values.where((t) => !t.deleted).toList();
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  List<Txn> txnsOfClient(String clientId) => txns.where((t) => t.clientId == clientId).toList();

  List<Txn> txnsOfDay(String day) => txns.where((t) => dayKey(t.date) == day).toList();

  Txn? lastTxnOf(String clientId) {
    Txn? last;
    for (final t in _txns.values) {
      if (t.deleted || t.clientId != clientId) continue;
      if (last == null || t.createdAt > last.createdAt) last = t;
    }
    return last;
  }

  Amounts balanceOf(String clientId) => sumBalance(_txns.values.where((t) => t.clientId == clientId));

  /// Total de ce que les clients me doivent (positif) et de ce que je leur dois.
  ({Amounts owedToMe, Amounts iOwe}) get debtTotals {
    final owed = Amounts();
    final iOwe = Amounts();
    for (final c in _clients.values) {
      if (c.deleted) continue;
      final b = balanceOf(c.id);
      for (final cur in Currency.values) {
        if (b[cur] > 0) owed.add(cur, b[cur]);
        if (b[cur] < 0) iOwe.add(cur, -b[cur]);
      }
    }
    return (owedToMe: owed, iOwe: iOwe);
  }

  DayOpening? opening(String day) => _openings[day];

  bool get todayOpened => _openings.containsKey(dayKey(DateTime.now()));

  Amounts openingAmounts(String day) => Amounts(_openings[day]?.amounts);

  DaySummary summaryOf(String day) => summarizeDay(openingAmounts(day), txnsOfDay(day));

  /// Caisse actuelle = ouverture du jour + mouvements du jour.
  Amounts get currentCash => summaryOf(dayKey(DateTime.now())).closing;

  /// Proposition pour l'ouverture : la clôture du dernier jour ouvert.
  Amounts suggestedOpening() {
    final today = dayKey(DateTime.now());
    final days = _openings.keys.where((d) => d.compareTo(today) < 0).toList()..sort();
    if (days.isEmpty) return Amounts();
    return summaryOf(days.last).closing;
  }

  /// Jours qui ont une activité (ouverture ou opérations), du plus récent au plus ancien.
  List<String> get activeDays {
    final set = <String>{..._openings.keys, ...txns.map((t) => dayKey(t.date))};
    return set.toList()..sort((a, b) => b.compareTo(a));
  }

  // ---------- Historique ----------

  /// Opérations entre [start] (inclus) et [end] (exclu).
  List<Txn> txnsBetween(DateTime start, DateTime end) {
    final s = start.millisecondsSinceEpoch;
    final e = end.millisecondsSinceEpoch;
    return txns.where((t) => t.createdAt >= s && t.createdAt < e).toList();
  }

  List<Txn> txnsOfMonth(int year, int month) => txnsBetween(DateTime(year, month), DateTime(year, month + 1));

  /// Vrai si l'opération concerne la devise [c] (mouvement ou dette).
  static bool touches(Txn t, Currency c) => t.fromCur == c || t.toCur == c;

  /// Recherche dans le nom du client et la note.
  bool matches(Txn t, String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    return clientName(t.clientId).toLowerCase().contains(q) ||
        t.note.toLowerCase().contains(q) ||
        (client(t.clientId)?.phone.contains(q) ?? false);
  }

  /// Toutes les entrées / sorties d'un client, par devise.
  Flows flowsOfClient(String clientId) => Flows(txnsOfClient(clientId));

  // ---------- Écriture ----------

  Future<Client> addClient({required String name, String phone = '', String note = ''}) async {
    final now = nowMs();
    final c = Client(id: _uuid.v4(), name: name.trim(), phone: phone.trim(), note: note.trim(), createdAt: now, updatedAt: now);
    await _saveClient(c);
    return c;
  }

  Future<void> updateClient(Client c, {required String name, required String phone, required String note}) async {
    c
      ..name = name.trim()
      ..phone = phone.trim()
      ..note = note.trim();
    await _saveClient(c);
  }

  Future<void> deleteClient(Client c) async {
    c.deleted = true;
    await _saveClient(c);
  }

  Future<void> _saveClient(Client c) async {
    c
      ..updatedAt = nowMs()
      ..synced = false;
    _clients[c.id] = c;
    await _db.upsertClient(c);
    _changed();
  }

  String newId() => _uuid.v4();

  Future<void> saveTxn(Txn t) async {
    t
      ..updatedAt = nowMs()
      ..synced = false;
    _txns[t.id] = t;
    await _db.upsertTxn(t);
    _changed();
  }

  Future<void> deleteTxn(Txn t) async {
    t.deleted = true;
    await saveTxn(t);
  }

  Future<void> setOpening(String day, Map<Currency, int> amounts) async {
    final o = DayOpening(day: day, amounts: amounts, updatedAt: nowMs());
    _openings[day] = o;
    await _db.upsertOpening(o);
    _changed();
  }

  void _changed() {
    notifyListeners();
    onLocalChange?.call();
  }

  // ---------- Synchro ----------

  Iterable<Client> get unsyncedClients => _clients.values.where((c) => !c.synced);
  Iterable<Txn> get unsyncedTxns => _txns.values.where((t) => !t.synced);
  Iterable<DayOpening> get unsyncedOpenings => _openings.values.where((o) => !o.synced);
  int get pendingCount => unsyncedClients.length + unsyncedTxns.length + unsyncedOpenings.length;

  Future<void> markClientSynced(Client c) async {
    c.synced = true;
    await _db.markSynced('clients', 'id', c.id);
  }

  Future<void> markTxnSynced(Txn t) async {
    t.synced = true;
    await _db.markSynced('txns', 'id', t.id);
  }

  Future<void> markOpeningSynced(DayOpening o) async {
    o.synced = true;
    await _db.markSynced('openings', 'day', o.day);
  }

  /// Applique une donnée venue du serveur si elle est plus récente que la version locale.
  Future<bool> applyRemoteClient(Client c) async {
    final local = _clients[c.id];
    if (local != null && (!local.synced || local.updatedAt > c.updatedAt)) return false;
    c.synced = true;
    _clients[c.id] = c;
    await _db.upsertClient(c);
    return true;
  }

  Future<bool> applyRemoteTxn(Txn t) async {
    final local = _txns[t.id];
    if (local != null && (!local.synced || local.updatedAt > t.updatedAt)) return false;
    t.synced = true;
    _txns[t.id] = t;
    await _db.upsertTxn(t);
    return true;
  }

  Future<bool> applyRemoteOpening(DayOpening o) async {
    final local = _openings[o.day];
    if (local != null && (!local.synced || local.updatedAt > o.updatedAt)) return false;
    o.synced = true;
    _openings[o.day] = o;
    await _db.upsertOpening(o);
    return true;
  }

  void refresh() => notifyListeners();
}
