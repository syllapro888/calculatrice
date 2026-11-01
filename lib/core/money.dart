import 'package:intl/intl.dart';

/// Les trois devises gérées. Les montants sont stockés en "unités mineures"
/// (montant × 100) pour éviter les erreurs d'arrondi, y compris pour le FCFA.
enum Currency {
  xaf('XAF', 'FCFA', 0),
  usd('USD', r'$', 2),
  eur('EUR', '€', 2);

  const Currency(this.code, this.symbol, this.decimals);

  final String code;
  final String symbol;
  final int decimals;

  String get label => this == Currency.xaf ? 'FCFA' : code;

  static Currency fromCode(String code) =>
      Currency.values.firstWhere((c) => c.code == code, orElse: () => Currency.xaf);
}

/// Convertit un montant saisi (ex. "2 000 000", "3500,50") en unités mineures.
int? parseAmount(String input) {
  var s = input.trim().replaceAll(RegExp(r'[\s  ]'), '');
  if (s.isEmpty) return null;
  s = s.replaceAll(',', '.');
  // Garde seulement le dernier point comme séparateur décimal.
  final parts = s.split('.');
  if (parts.length > 2) {
    s = '${parts.sublist(0, parts.length - 1).join()}.${parts.last}';
  }
  final value = double.tryParse(s);
  if (value == null) return null;
  return (value * 100).round();
}

/// Convertit un taux saisi (ex. "615,5") en nombre.
double? parseRate(String input) {
  final s = input.trim().replaceAll(RegExp(r'[\s  ]'), '').replaceAll(',', '.');
  if (s.isEmpty) return null;
  final v = double.tryParse(s);
  if (v == null || v <= 0) return null;
  return v;
}

final Map<int, NumberFormat> _formats = {};

NumberFormat _fmt(int decimals) => _formats.putIfAbsent(decimals, () {
      final f = NumberFormat.decimalPattern('fr');
      f.minimumFractionDigits = 0;
      f.maximumFractionDigits = decimals;
      return f;
    });

/// Montant lisible : "2 000 000" (sans devise).
String formatNumber(int minor, Currency c) => _fmt(c.decimals).format(minor / 100);

/// Montant lisible avec devise : "2 000 000 FCFA", "3 500 USD".
String formatMoney(int minor, Currency c) => '${formatNumber(minor, c)} ${c.label}';

/// Montant saisi dans un champ (sans séparateur de milliers).
String amountToInput(int minor, Currency c) {
  final v = minor / 100;
  if (c.decimals == 0 || v == v.roundToDouble()) return v.round().toString();
  return v.toStringAsFixed(2).replaceAll('.', ',');
}

String formatRate(double rate) {
  final f = NumberFormat.decimalPattern('fr');
  f.maximumFractionDigits = 4;
  return f.format(rate);
}

/// Une paire de devises. La devise de base est la plus "forte" :
/// EUR/XAF, USD/XAF, EUR/USD. Le taux = combien de [quote] pour 1 [base].
class CurrencyPair {
  const CurrencyPair(this.base, this.quote);
  final Currency base;
  final Currency quote;

  static const all = [
    CurrencyPair(Currency.usd, Currency.xaf),
    CurrencyPair(Currency.eur, Currency.xaf),
    CurrencyPair(Currency.eur, Currency.usd),
  ];

  static CurrencyPair of(Currency a, Currency b) {
    assert(a != b);
    return all.firstWhere((p) => (p.base == a && p.quote == b) || (p.base == b && p.quote == a));
  }

  String get key => '${base.code}_${quote.code}';
  String get label => '1 ${base.label} = ? ${quote.label}';

  @override
  bool operator ==(Object other) => other is CurrencyPair && other.base == base && other.quote == quote;

  @override
  int get hashCode => Object.hash(base, quote);
}

/// Convertit [amount] (unités mineures) de [from] vers [to] avec le taux de la paire.
int convert(int amount, Currency from, Currency to, double rate) {
  if (from == to) return amount;
  final pair = CurrencyPair.of(from, to);
  if (from == pair.base) return (amount * rate).round();
  return (amount / rate).round();
}
