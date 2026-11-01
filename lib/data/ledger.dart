import '../core/money.dart';
import 'models.dart';

/// Montants par devise.
class Amounts {
  Amounts([Map<Currency, int>? values]) : values = {for (final c in Currency.values) c: values?[c] ?? 0};

  final Map<Currency, int> values;

  int operator [](Currency c) => values[c] ?? 0;
  void add(Currency c, int v) => values[c] = this[c] + v;

  bool get isZero => values.values.every((v) => v == 0);

  Amounts operator +(Amounts o) => Amounts({for (final c in Currency.values) c: this[c] + o[c]});
}

/// Effet d'une opération sur ma caisse (positif = entre dans la caisse).
Amounts cashEffect(Txn t) {
  final a = Amounts();
  if (t.deleted) return a;
  switch (t.kind) {
    case TxnKind.exchange:
      a.add(t.fromCur, t.paidAmt);
      if (t.toCur != null) a.add(t.toCur!, -t.toAmt);
    case TxnKind.received:
      a.add(t.fromCur, t.fromAmt);
    case TxnKind.given:
      a.add(t.fromCur, -t.fromAmt);
    case TxnKind.debt:
      break;
  }
  return a;
}

/// Effet d'une opération sur le solde du client.
/// Positif = le client me doit ; négatif = je dois au client.
Amounts balanceEffect(Txn t) {
  final a = Amounts();
  if (t.deleted) return a;
  switch (t.kind) {
    case TxnKind.exchange:
      a.add(t.fromCur, t.fromAmt - t.paidAmt);
    case TxnKind.received:
      a.add(t.fromCur, -t.fromAmt);
    case TxnKind.given:
      a.add(t.fromCur, t.fromAmt);
    case TxnKind.debt:
      a.add(t.fromCur, t.fromAmt);
  }
  return a;
}

Amounts sumCash(Iterable<Txn> txns) => txns.fold(Amounts(), (acc, t) => acc + cashEffect(t));

Amounts sumBalance(Iterable<Txn> txns) => txns.fold(Amounts(), (acc, t) => acc + balanceEffect(t));

/// Résumé d'une journée pour le journal.
class DaySummary {
  DaySummary({
    required this.opening,
    required this.cashIn,
    required this.cashOut,
    required this.exchangeCount,
    required this.newDebt,
  });

  final Amounts opening;
  final Amounts cashIn;
  final Amounts cashOut;
  final int exchangeCount;

  /// Dettes créées ou remboursées ce jour-là (variation des soldes clients).
  final Amounts newDebt;

  Amounts get closing => Amounts({for (final c in Currency.values) c: opening[c] + cashIn[c] - cashOut[c]});
}

DaySummary summarizeDay(Amounts opening, Iterable<Txn> dayTxns) {
  final cashIn = Amounts();
  final cashOut = Amounts();
  var count = 0;
  for (final t in dayTxns) {
    if (t.deleted) continue;
    if (t.kind == TxnKind.exchange) count++;
    final e = cashEffect(t);
    for (final c in Currency.values) {
      if (e[c] > 0) cashIn.add(c, e[c]);
      if (e[c] < 0) cashOut.add(c, -e[c]);
    }
  }
  return DaySummary(
    opening: opening,
    cashIn: cashIn,
    cashOut: cashOut,
    exchangeCount: count,
    newDebt: sumBalance(dayTxns),
  );
}
