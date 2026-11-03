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
    case TxnKind.cashIn:
    case TxnKind.received:
      a.add(t.fromCur, t.fromAmt);
    case TxnKind.cashOut:
    case TxnKind.given:
      a.add(t.fromCur, -t.fromAmt);
    case TxnKind.exchange:
      a.add(t.fromCur, t.paidAmt);
      if (t.toCur != null) a.add(t.toCur!, -t.toAmt);
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
    case TxnKind.cashIn:
    case TxnKind.cashOut:
      break;
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

/// Entrées et sorties de caisse, séparées par devise.
class Flows {
  Flows(Iterable<Txn> txns) {
    for (final t in txns) {
      if (t.deleted) continue;
      count++;
      final e = cashEffect(t);
      for (final c in Currency.values) {
        if (e[c] > 0) cashIn.add(c, e[c]);
        if (e[c] < 0) cashOut.add(c, -e[c]);
      }
    }
  }

  final cashIn = Amounts();
  final cashOut = Amounts();
  int count = 0;

  Amounts get net => Amounts({for (final c in Currency.values) c: cashIn[c] - cashOut[c]});
}

/// Résumé d'une journée pour le journal.
class DaySummary {
  DaySummary({required this.opening, required this.flows, required this.newDebt});

  final Amounts opening;
  final Flows flows;

  /// Dettes créées ou remboursées ce jour-là (variation des soldes clients).
  final Amounts newDebt;

  Amounts get cashIn => flows.cashIn;
  Amounts get cashOut => flows.cashOut;
  int get count => flows.count;

  Amounts get closing => Amounts({for (final c in Currency.values) c: opening[c] + cashIn[c] - cashOut[c]});
}

DaySummary summarizeDay(Amounts opening, Iterable<Txn> dayTxns) =>
    DaySummary(opening: opening, flows: Flows(dayTxns), newDebt: sumBalance(dayTxns));
