import 'package:calculatrice/core/calc_engine.dart';
import 'package:calculatrice/core/money.dart';
import 'package:calculatrice/data/ledger.dart';
import 'package:calculatrice/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

Txn _t(TxnKind kind, Currency from, int amt, {Currency? to, int toAmt = 0, int? paid, String? client = 'c1'}) => Txn(
      id: '${kind.code}-$amt-${DateTime.now().microsecondsSinceEpoch}',
      clientId: client,
      kind: kind,
      createdAt: 0,
      fromCur: from,
      fromAmt: amt,
      toCur: to,
      toAmt: toAmt,
      paidAmt: paid,
      updatedAt: 0,
    );

void main() {
  group('Montants', () {
    test('lecture des montants saisis', () {
      expect(parseAmount('2 000 000'), 200000000);
      expect(parseAmount('3500,50'), 350050);
      expect(parseAmount('1.234,5'), 123450);
      expect(parseAmount(''), isNull);
      expect(parseRate('615,5'), 615.5);
    });

    test('conversion avec le taux de la paire', () {
      // 1 USD = 600 FCFA
      expect(convert(100 * 100, Currency.usd, Currency.xaf, 600), 60000 * 100);
      expect(convert(60000 * 100, Currency.xaf, Currency.usd, 600), 100 * 100);
      // 1 EUR = 1,10 USD
      expect(convert(100 * 100, Currency.eur, Currency.usd, 1.10), 110 * 100);
    });
  });

  group('Caisse et dettes', () {
    test('vente payée entièrement', () {
      final t = _t(TxnKind.exchange, Currency.xaf, 600000 * 100, to: Currency.usd, toAmt: 1000 * 100);
      final cash = cashEffect(t);
      expect(cash[Currency.xaf], 600000 * 100);
      expect(cash[Currency.usd], -1000 * 100);
      expect(balanceEffect(t).isZero, isTrue);
    });

    test('vente avec paiement partiel crée une dette', () {
      final t = _t(TxnKind.exchange, Currency.xaf, 600000 * 100,
          to: Currency.usd, toAmt: 1000 * 100, paid: 400000 * 100);
      expect(cashEffect(t)[Currency.xaf], 400000 * 100);
      expect(balanceEffect(t)[Currency.xaf], 200000 * 100);
    });

    test('remboursement et dépôt', () {
      final txns = [
        _t(TxnKind.debt, Currency.usd, 500 * 100),
        _t(TxnKind.received, Currency.usd, 300 * 100),
        _t(TxnKind.received, Currency.eur, 100 * 100),
        _t(TxnKind.given, Currency.xaf, 50000 * 100),
      ];
      final b = sumBalance(txns);
      expect(b[Currency.usd], 200 * 100); // me doit encore 200 USD
      expect(b[Currency.eur], -100 * 100); // je lui dois 100 EUR
      expect(b[Currency.xaf], 50000 * 100);
      final cash = sumCash(txns);
      expect(cash[Currency.usd], 300 * 100);
      expect(cash[Currency.xaf], -50000 * 100);
    });

    test('entrées et sorties comptées par devise, sans toucher aux dettes', () {
      final txns = [
        _t(TxnKind.cashIn, Currency.xaf, 500000 * 100),
        _t(TxnKind.cashOut, Currency.eur, 200 * 100),
        _t(TxnKind.cashIn, Currency.eur, 50 * 100),
      ];
      final f = Flows(txns);
      expect(f.cashIn[Currency.xaf], 500000 * 100);
      expect(f.cashIn[Currency.eur], 50 * 100);
      expect(f.cashOut[Currency.eur], 200 * 100);
      expect(f.net[Currency.eur], -150 * 100);
      expect(f.cashOut[Currency.usd], 0);
      expect(sumBalance(txns).isZero, isTrue);
    });

    test('opération supprimée ignorée', () {
      final t = _t(TxnKind.received, Currency.usd, 100)..deleted = true;
      expect(cashEffect(t).isZero, isTrue);
      expect(balanceEffect(t).isZero, isTrue);
    });

    test('résumé de journée', () {
      final opening = Amounts({Currency.xaf: 2000000 * 100, Currency.usd: 3500 * 100, Currency.eur: 2000 * 100});
      final s = summarizeDay(opening, [
        _t(TxnKind.exchange, Currency.xaf, 600000 * 100, to: Currency.usd, toAmt: 1000 * 100),
      ]);
      expect(s.count, 1);
      expect(s.closing[Currency.xaf], 2600000 * 100);
      expect(s.closing[Currency.usd], 2500 * 100);
      expect(s.closing[Currency.eur], 2000 * 100);
    });
  });

  group('Calculatrice', () {
    test('priorités des opérations', () {
      expect(CalcEngine.evaluate('2+3×4'), 14);
      expect(CalcEngine.evaluate('10÷4'), 2.5);
      expect(CalcEngine.evaluate('-5+2'), -3);
      expect(CalcEngine.evaluate('1,5×2'), 3);
      expect(CalcEngine.evaluate('5÷0'), isNull);
    });

    test('saisie', () {
      final e = CalcEngine();
      for (final k in ['1', '2']) {
        e.digit(k);
      }
      e.applyOperator('+');
      e.digit('3');
      e.equals();
      expect(e.result, '15');
      e.applyOperator('×');
      e.digit('2');
      e.equals();
      expect(e.result, '30');
    });

    test('pourcentage', () {
      final e = CalcEngine();
      e.digit('5');
      e.digit('0');
      e.percent();
      e.equals();
      expect(e.result, '0,5');
    });
  });
}
