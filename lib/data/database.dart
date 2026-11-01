import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'models.dart';

/// Base de données locale (fonctionne sans internet).
class LocalDb {
  LocalDb._(this.db);
  final Database db;

  static Future<LocalDb> open() async {
    final dir = await getDatabasesPath();
    final db = await openDatabase(
      p.join(dir, 'carnet.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE clients(
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            phone TEXT,
            note TEXT,
            createdAt INTEGER,
            updatedAt INTEGER,
            deleted INTEGER DEFAULT 0,
            synced INTEGER DEFAULT 0
          )''');
        await db.execute('''
          CREATE TABLE txns(
            id TEXT PRIMARY KEY,
            clientId TEXT,
            kind TEXT NOT NULL,
            createdAt INTEGER,
            fromCur TEXT,
            fromAmt INTEGER,
            toCur TEXT,
            toAmt INTEGER,
            rate REAL,
            paidAmt INTEGER,
            note TEXT,
            updatedAt INTEGER,
            deleted INTEGER DEFAULT 0,
            synced INTEGER DEFAULT 0
          )''');
        await db.execute('CREATE INDEX idx_txns_client ON txns(clientId)');
        await db.execute('CREATE INDEX idx_txns_date ON txns(createdAt)');
        await db.execute('''
          CREATE TABLE openings(
            day TEXT PRIMARY KEY,
            xaf INTEGER,
            usd INTEGER,
            eur INTEGER,
            updatedAt INTEGER,
            synced INTEGER DEFAULT 0
          )''');
      },
    );
    return LocalDb._(db);
  }

  // Clients
  Future<List<Client>> allClients() async =>
      (await db.query('clients')).map(Client.fromMap).toList();

  Future<void> upsertClient(Client c) =>
      db.insert('clients', c.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

  // Opérations
  Future<List<Txn>> allTxns() async =>
      (await db.query('txns', orderBy: 'createdAt ASC')).map(Txn.fromMap).toList();

  Future<void> upsertTxn(Txn t) =>
      db.insert('txns', t.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

  // Ouvertures de caisse
  Future<List<DayOpening>> allOpenings() async =>
      (await db.query('openings')).map(DayOpening.fromMap).toList();

  Future<void> upsertOpening(DayOpening o) =>
      db.insert('openings', o.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

  // Synchro
  Future<void> markSynced(String table, String keyCol, String key) =>
      db.update(table, {'synced': 1}, where: '$keyCol = ?', whereArgs: [key]);
}
