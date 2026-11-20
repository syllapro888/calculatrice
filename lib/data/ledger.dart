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

/// Opération du carnet des dettes (dette notée, remboursement reçu ou donné).
/// Ces opérations restent à part : elles ne comptent jamais dans la caisse ni dans le journal.
bool isDebtTxn(Txn t) => t.kind == TxnKind.debt || t.kind == TxnKind.received || t.kind == TxnKind.given;

/// Effet d'une opération sur ma caisse (positif = entre dans la caisse).
/// Les dettes et leurs remboursements n'y touchent pas.
Amounts cashEffect(Txn t) {
  final a = Amounts();
  if (t.deleted) return a;
  switch (t.kind) {
    case TxnKind.cashIn:
      a.add(t.fromCur, t.fromAmt);
    case TxnKind.cashOut:
      a.add(t.fromCur, -t.fromAmt);
    case TxnKind.exchange:
      a.add(t.fromCur, t.paidAmt);
      if (t.toCur != null) a.add(t.toCur!, -t.toAmt);
    case TxnKind.debt:
    case TxnKind.received:
    case TxnKind.given:
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

/// Entrées et sorties de caisse, séparées par devise (sans les dettes).
class Flows {
  Flows(Iterable<Txn> txns) {
    for (final t in txns) {
      if (t.deleted || isDebtTxn(t)) continue;
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

/// Résumé d'une journée pour le journal (caisse seulement, sans les dettes).
class DaySummary {
  DaySummary({required this.opening, required this.flows});

  final Amounts opening;
  final Flows flows;

  Amounts get cashIn => flows.cashIn;
  Amounts get cashOut => flows.cashOut;
  int get count => flows.count;

  Amounts get closing => Amounts({for (final c in Currency.values) c: opening[c] + cashIn[c] - cashOut[c]});
}

DaySummary summarizeDay(Amounts opening, Iterable<Txn> dayTxns) =>
    DaySummary(opening: opening, flows: Flows(dayTxns));
