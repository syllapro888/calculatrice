import 'package:flutter/material.dart';

import '../app.dart';
import '../core/money.dart';
import '../data/models.dart';
import 'client_chat_screen.dart';
import 'sync_badge.dart';
import 'txn_view.dart';
import 'widgets.dart';

/// Journal : le récapitulatif de chaque journée et toutes ses opérations.
class JournalTab extends StatefulWidget {
  const JournalTab({super.key});

  @override
  State<JournalTab> createState() => _JournalTabState();
}

class _JournalTabState extends State<JournalTab> {
  DateTime _day = DateTime.now();
  TxnKind? _filter;

  void _shift(int days) => setState(() => _day = _day.add(Duration(days: days)));

  Future<void> _pick() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _day = d);
  }

  @override
  Widget build(BuildContext context) {
    final store = Deps.of(context).store;
    final theme = Theme.of(context);
    final key = dayKey(_day);
    final isToday = key == dayKey(DateTime.now());
    final summary = store.summaryOf(key);
    final all = store.txnsOfDay(key).reversed.toList();
    final txns = _filter == null ? all : all.where((t) => t.kind == _filter).toList();
    final opened = store.opening(key) != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Journal'), actions: const [SyncBadge()]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        children: [
          Row(
            children: [
              IconButton(onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left)),
              Expanded(
                child: TextButton.icon(
                  onPressed: _pick,
                  icon: const Icon(Icons.calendar_month),
                  label: Text(formatDay(_day), textAlign: TextAlign.center),
                ),
              ),
              IconButton(onPressed: isToday ? null : () => _shift(1), icon: const Icon(Icons.chevron_right)),
            ],
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${summary.exchangeCount} vente(s) · ${all.length} opération(s)', style: theme.textTheme.titleSmall),
                  if (!opened)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Caisse du matin non notée ce jour-là', style: TextStyle(color: Colors.orange.shade800)),
                    ),
                  const SizedBox(height: 12),
                  Table(
                    columnWidths: const {0: IntrinsicColumnWidth()},
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    children: [
                      TableRow(children: [
                        const SizedBox(),
                        for (final c in Currency.values)
                          _cell(c.label, bold: true, color: currencyColor(c)),
                      ]),
                      _row('Matin', (c) => summary.opening[c]),
                      _row('Entrées', (c) => summary.cashIn[c], color: Colors.green.shade700),
                      _row('Sorties', (c) => summary.cashOut[c], color: Colors.red.shade700),
                      _row('Soir', (c) => summary.closing[c], bold: true),
                    ],
                  ),
                  if (!summary.newDebt.isZero) ...[
                    const Divider(height: 24),
                    const Text('Dettes du jour (+ : clients me doivent plus)'),
                    const SizedBox(height: 4),
                    AmountChips(amounts: summary.newDebt, signed: true),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chip('Tout', null),
                for (final k in TxnKind.values) _chip(k == TxnKind.exchange ? 'Ventes' : k.label, k),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (txns.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('Aucune opération ce jour-là')),
            )
          else
            Card(
              child: Column(
                children: [
                  for (final t in txns)
                    TxnTile(
                      txn: t,
                      clientName: store.clientName(t.clientId),
                      onTap: t.clientId == null || store.client(t.clientId)?.deleted == true
                          ? null
                          : () => openClient(context, t.clientId!),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _chip(String label, TxnKind? kind) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ChoiceChip(
          label: Text(label),
          selected: _filter == kind,
          onSelected: (_) => setState(() => _filter = kind),
        ),
      );

  TableRow _row(String label, int Function(Currency) value, {Color? color, bool bold = false}) => TableRow(children: [
        Padding(padding: const EdgeInsets.only(right: 8), child: _cell(label, bold: bold, align: TextAlign.left)),
        for (final c in Currency.values) _cell(formatNumber(value(c), c), color: color, bold: bold),
      ]);

  Widget _cell(String text, {bool bold = false, Color? color, TextAlign align = TextAlign.right}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          text,
          textAlign: align,
          style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: color, fontSize: 13),
        ),
      );
}
