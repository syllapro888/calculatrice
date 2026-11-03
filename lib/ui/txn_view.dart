import 'package:flutter/material.dart';

import '../core/money.dart';
import '../data/models.dart';
import 'widgets.dart';

/// Phrase courte qui décrit une opération.
String txnTitle(Txn t) {
  switch (t.kind) {
    case TxnKind.cashIn:
      return 'Entrée ${formatMoney(t.fromAmt, t.fromCur)}';
    case TxnKind.cashOut:
      return 'Sortie ${formatMoney(t.fromAmt, t.fromCur)}';
    case TxnKind.exchange:
      return 'Change ${formatMoney(t.fromAmt, t.fromCur)} → ${formatMoney(t.toAmt, t.toCur ?? Currency.xaf)}';
    case TxnKind.received:
      return 'Remboursement reçu ${formatMoney(t.fromAmt, t.fromCur)}';
    case TxnKind.given:
      return 'Remboursement donné ${formatMoney(t.fromAmt, t.fromCur)}';
    case TxnKind.debt:
      return t.fromAmt >= 0
          ? 'Dette : me doit ${formatMoney(t.fromAmt, t.fromCur)}'
          : 'Dette : je dois ${formatMoney(-t.fromAmt, t.fromCur)}';
  }
}

String? txnDetail(Txn t) {
  final parts = <String>[];
  if (t.kind == TxnKind.exchange && t.toCur != null && t.rate > 0) {
    final pair = CurrencyPair.of(t.fromCur, t.toCur!);
    parts.add('Taux : 1 ${pair.base.label} = ${formatRate(t.rate)} ${pair.quote.label}');
    final rest = t.fromAmt - t.paidAmt;
    if (rest > 0) parts.add('Payé ${formatMoney(t.paidAmt, t.fromCur)} · reste ${formatMoney(rest, t.fromCur)} en dette');
  }
  if (t.note.isNotEmpty) parts.add(t.note);
  return parts.isEmpty ? null : parts.join('\n');
}

IconData txnIcon(Txn t) => switch (t.kind) {
      TxnKind.cashIn => Icons.south_west,
      TxnKind.cashOut => Icons.north_east,
      TxnKind.exchange => Icons.currency_exchange,
      TxnKind.received => Icons.call_received,
      TxnKind.given => Icons.call_made,
      TxnKind.debt => Icons.receipt_long,
    };

Color txnColor(Txn t) => switch (t.kind) {
      TxnKind.cashIn => const Color(0xFF2E7D32),
      TxnKind.cashOut => const Color(0xFFC62828),
      TxnKind.exchange => const Color(0xFF1565C0),
      TxnKind.received => const Color(0xFF00796B),
      TxnKind.given => const Color(0xFFAD1457),
      TxnKind.debt => const Color(0xFFEF6C00),
    };

/// Ligne d'opération (journal, accueil).
class TxnTile extends StatelessWidget {
  const TxnTile({super.key, required this.txn, required this.clientName, this.onTap, this.showDate = false});
  final Txn txn;
  final String clientName;
  final VoidCallback? onTap;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final detail = txnDetail(txn);
    final time = showDate ? '${formatDay(txn.date)} ${formatTime(txn.date)}' : formatTime(txn.date);
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: txnColor(txn).withValues(alpha: 0.12),
        child: Icon(txnIcon(txn), color: txnColor(txn), size: 20),
      ),
      title: Text(clientName, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(detail == null ? txnTitle(txn) : '${txnTitle(txn)}\n$detail'),
      isThreeLine: detail != null,
      trailing: Text(time, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

/// Bulle de conversation dans la fiche client.
/// À gauche : ce que le client me donne. À droite : ce que je lui donne / lui vends.
class TxnBubble extends StatelessWidget {
  const TxnBubble({super.key, required this.txn, this.onLongPress});
  final Txn txn;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    // À droite : ce qui sort de chez moi. À gauche : ce que je reçois.
    final mine = switch (txn.kind) {
      TxnKind.cashOut || TxnKind.given || TxnKind.exchange => true,
      TxnKind.debt => txn.fromAmt >= 0,
      _ => false,
    };
    final bg = mine
        ? (dark ? const Color(0xFF005C4B) : const Color(0xFFD9FDD3))
        : (dark ? const Color(0xFF202C33) : Colors.white);
    final detail = txnDetail(txn);

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(12),
              topRight: const Radius.circular(12),
              bottomLeft: Radius.circular(mine ? 12 : 2),
              bottomRight: Radius.circular(mine ? 2 : 12),
            ),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 2, offset: const Offset(0, 1))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(txnIcon(txn), size: 16, color: txnColor(txn)),
                  const SizedBox(width: 6),
                  Text(txn.kind.label, style: TextStyle(color: txnColor(txn), fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 4),
              Text(txnTitle(txn), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              if (detail != null) ...[
                const SizedBox(height: 2),
                Text(detail, style: theme.textTheme.bodySmall),
              ],
              Align(
                alignment: Alignment.bottomRight,
                child: Text(formatTime(txn.date), style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
