import '../core/money.dart';

int nowMs() => DateTime.now().millisecondsSinceEpoch;

String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class Client {
  Client({
    required this.id,
    required this.name,
    this.phone = '',
    this.note = '',
    required this.createdAt,
    required this.updatedAt,
    this.deleted = false,
    this.synced = false,
  });

  final String id;
  String name;
  String phone;
  String note;
  final int createdAt;
  int updatedAt;
  bool deleted;
  bool synced;

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'note': note,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'deleted': deleted ? 1 : 0,
        'synced': synced ? 1 : 0,
      };

  factory Client.fromMap(Map<String, Object?> m) => Client(
        id: m['id'] as String,
        name: (m['name'] as String?) ?? '',
        phone: (m['phone'] as String?) ?? '',
        note: (m['note'] as String?) ?? '',
        createdAt: (m['createdAt'] as num?)?.toInt() ?? 0,
        updatedAt: (m['updatedAt'] as num?)?.toInt() ?? 0,
        deleted: _bool(m['deleted']),
        synced: _bool(m['synced']),
      );
}

bool _bool(Object? v) => v == true || v == 1;

/// Types d'opérations.
enum TxnKind {
  /// Vente / change : le client donne [fromAmt] en [fromCur] et reçoit [toAmt] en [toCur].
  exchange('exchange', 'Change'),

  /// Le client me donne de l'argent (paiement d'une dette, dépôt...).
  received('received', 'Reçu du client'),

  /// Je donne de l'argent au client (prêt, remboursement...).
  given('given', 'Donné au client'),

  /// Dette notée sans mouvement de caisse. fromAmt > 0 : le client me doit ;
  /// fromAmt < 0 : je dois au client.
  debt('debt', 'Dette');

  const TxnKind(this.code, this.label);
  final String code;
  final String label;

  static TxnKind fromCode(String c) => TxnKind.values.firstWhere((k) => k.code == c, orElse: () => TxnKind.received);
}

class Txn {
  Txn({
    required this.id,
    this.clientId,
    required this.kind,
    required this.createdAt,
    required this.fromCur,
    required this.fromAmt,
    this.toCur,
    this.toAmt = 0,
    this.rate = 0,
    int? paidAmt,
    this.note = '',
    required this.updatedAt,
    this.deleted = false,
    this.synced = false,
  }) : paidAmt = paidAmt ?? fromAmt;

  final String id;
  String? clientId;
  TxnKind kind;
  int createdAt;
  Currency fromCur;
  int fromAmt;
  Currency? toCur;
  int toAmt;
  double rate;

  /// Pour un change : la part payée tout de suite par le client (le reste devient dette).
  int paidAmt;
  String note;
  int updatedAt;
  bool deleted;
  bool synced;

  DateTime get date => DateTime.fromMillisecondsSinceEpoch(createdAt);

  Map<String, Object?> toMap() => {
        'id': id,
        'clientId': clientId,
        'kind': kind.code,
        'createdAt': createdAt,
        'fromCur': fromCur.code,
        'fromAmt': fromAmt,
        'toCur': toCur?.code,
        'toAmt': toAmt,
        'rate': rate,
        'paidAmt': paidAmt,
        'note': note,
        'updatedAt': updatedAt,
        'deleted': deleted ? 1 : 0,
        'synced': synced ? 1 : 0,
      };

  factory Txn.fromMap(Map<String, Object?> m) => Txn(
        id: m['id'] as String,
        clientId: m['clientId'] as String?,
        kind: TxnKind.fromCode((m['kind'] as String?) ?? 'received'),
        createdAt: (m['createdAt'] as num?)?.toInt() ?? 0,
        fromCur: Currency.fromCode((m['fromCur'] as String?) ?? 'XAF'),
        fromAmt: (m['fromAmt'] as num?)?.toInt() ?? 0,
        toCur: m['toCur'] == null ? null : Currency.fromCode(m['toCur'] as String),
        toAmt: (m['toAmt'] as num?)?.toInt() ?? 0,
        rate: (m['rate'] as num?)?.toDouble() ?? 0,
        paidAmt: (m['paidAmt'] as num?)?.toInt(),
        note: (m['note'] as String?) ?? '',
        updatedAt: (m['updatedAt'] as num?)?.toInt() ?? 0,
        deleted: _bool(m['deleted']),
        synced: _bool(m['synced']),
      );
}

/// Caisse d'ouverture d'une journée (ce que je compte le matin).
class DayOpening {
  DayOpening({
    required this.day,
    required this.amounts,
    required this.updatedAt,
    this.synced = false,
  });

  final String day;
  final Map<Currency, int> amounts;
  int updatedAt;
  bool synced;

  int of(Currency c) => amounts[c] ?? 0;

  Map<String, Object?> toMap() => {
        'day': day,
        'xaf': of(Currency.xaf),
        'usd': of(Currency.usd),
        'eur': of(Currency.eur),
        'updatedAt': updatedAt,
        'synced': synced ? 1 : 0,
      };

  factory DayOpening.fromMap(Map<String, Object?> m) => DayOpening(
        day: m['day'] as String,
        amounts: {
          Currency.xaf: (m['xaf'] as num?)?.toInt() ?? 0,
          Currency.usd: (m['usd'] as num?)?.toInt() ?? 0,
          Currency.eur: (m['eur'] as num?)?.toInt() ?? 0,
        },
        updatedAt: (m['updatedAt'] as num?)?.toInt() ?? 0,
        synced: _bool(m['synced']),
      );
}
