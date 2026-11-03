import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../core/money.dart';
import '../data/ledger.dart';

/// Couleurs fixes pour chaque devise.
Color currencyColor(Currency c) => switch (c) {
      Currency.xaf => const Color(0xFF0B6E4F),
      Currency.usd => const Color(0xFF1565C0),
      Currency.eur => const Color(0xFF6A1B9A),
    };

String currencyName(Currency c) => switch (c) {
      Currency.xaf => 'Francs CFA',
      Currency.usd => 'Dollars (USD)',
      Currency.eur => 'Euros (EUR)',
    };

String formatMonth(DateTime d) {
  final s = DateFormat('MMMM y', 'fr').format(d);
  return s[0].toUpperCase() + s.substring(1);
}

String formatTime(DateTime d) => DateFormat.Hm('fr').format(d);

String formatDay(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Aujourd\'hui';
  if (diff == 1) return 'Hier';
  return DateFormat('EEEE d MMMM y', 'fr').format(d);
}

DateTime parseDayKey(String key) => DateTime.parse(key);

/// Choix d'une devise.
class CurrencySelector extends StatelessWidget {
  const CurrencySelector({super.key, required this.value, required this.onChanged, this.exclude});
  final Currency value;
  final ValueChanged<Currency> onChanged;
  final Currency? exclude;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<Currency>(
      showSelectedIcon: false,
      segments: [
        for (final c in Currency.values)
          ButtonSegment(value: c, label: Text(c.label), enabled: c != exclude),
      ],
      selected: {value},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

/// Champ de saisie de montant.
class AmountField extends StatelessWidget {
  const AmountField({
    super.key,
    required this.controller,
    required this.label,
    this.currency,
    this.onChanged,
    this.autofocus = false,
    this.helper,
  });

  final TextEditingController controller;
  final String label;
  final Currency? currency;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 ,.]'))],
      onChanged: onChanged,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        suffixText: currency?.label,
      ),
    );
  }
}

/// Affiche des montants par devise sous forme de petites pastilles.
class AmountChips extends StatelessWidget {
  const AmountChips({super.key, required this.amounts, this.showZero = false, this.signed = false});
  final Amounts amounts;
  final bool showZero;
  final bool signed;

  @override
  Widget build(BuildContext context) {
    final items = [
      for (final c in Currency.values)
        if (showZero || amounts[c] != 0) c,
    ];
    if (items.isEmpty) return const Text('—');
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final c in items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: currencyColor(c).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${signed && amounts[c] > 0 ? '+' : ''}${formatMoney(amounts[c], c)}',
              style: TextStyle(color: currencyColor(c), fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
      ],
    );
  }
}

/// Explique un solde client en mots.
class BalanceText extends StatelessWidget {
  const BalanceText({super.key, required this.balance, this.compact = false});
  final Amounts balance;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final owes = <String>[];
    final iOwe = <String>[];
    for (final c in Currency.values) {
      if (balance[c] > 0) owes.add(formatMoney(balance[c], c));
      if (balance[c] < 0) iOwe.add(formatMoney(-balance[c], c));
    }
    if (owes.isEmpty && iOwe.isEmpty) {
      return Text('Compte à jour', style: TextStyle(color: Colors.grey.shade600, fontSize: compact ? 12 : 14));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (owes.isNotEmpty)
          Text('Me doit : ${owes.join(' · ')}',
              style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w600, fontSize: compact ? 12 : 14)),
        if (iOwe.isNotEmpty)
          Text('Je lui dois : ${iOwe.join(' · ')}',
              style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.w600, fontSize: compact ? 12 : 14)),
      ],
    );
  }
}

/// Avatar avec initiales, comme dans une messagerie.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({super.key, required this.name, this.radius = 24});
  final String name;
  final double radius;

  static const _colors = [
    Color(0xFF0B6E4F),
    Color(0xFF1565C0),
    Color(0xFF6A1B9A),
    Color(0xFFC62828),
    Color(0xFFEF6C00),
    Color(0xFF00838F),
    Color(0xFF4E342E),
  ];

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    final initials = parts.isEmpty
        ? '?'
        : parts.length == 1
            ? parts.first.substring(0, 1).toUpperCase()
            : (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
    final color = _colors[name.hashCode.abs() % _colors.length];
    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      child: Text(initials, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: radius * 0.7)),
    );
  }
}

Future<bool> confirm(BuildContext context, {required String title, required String message, String ok = 'Supprimer'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ok)),
      ],
    ),
  );
  return r ?? false;
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Row(
        children: [
          Expanded(child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
