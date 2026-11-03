import 'package:flutter/material.dart';

import '../app.dart';
import '../core/money.dart';
import '../data/ledger.dart';
import '../data/models.dart';
import '../data/store.dart';
import 'client_chat_screen.dart';
import 'sync_badge.dart';
import 'txn_view.dart';
import 'widgets.dart';

enum _Period { day, month }

enum _KindFilter {
  all('Tout'),
  cashIn('Entrées'),
  cashOut('Sorties'),
  debt('Dettes');

  const _KindFilter(this.label);
  final String label;

  bool accepts(Txn t) => switch (this) {
        _KindFilter.all => true,
        _KindFilter.cashIn => cashEffect(t).values.values.any((v) => v > 0),
        _KindFilter.cashOut => cashEffect(t).values.values.any((v) => v < 0),
        _KindFilter.debt => t.kind == TxnKind.debt || t.kind == TxnKind.received || t.kind == TxnKind.given,
      };
}

/// Journal : jour par jour ou mois par mois, devise par devise, avec recherche.
class JournalTab extends StatefulWidget {
  const JournalTab({super.key});

  @override
  State<JournalTab> createState() => _JournalTabState();
}

class _JournalTabState extends State<JournalTab> {
  _Period _period = _Period.day;
  DateTime _date = DateTime.now();
  Currency? _currency;
  _KindFilter _kind = _KindFilter.all;
  String _query = '';

  bool get _isCurrent {
    final now = DateTime.now();
    return _period == _Period.day
        ? dayKey(_date) == dayKey(now)
        : _date.year == now.year && _date.month == now.month;
  }

  void _shift(int step) => setState(() {
        _date = _period == _Period.day
            ? DateTime(_date.year, _date.month, _date.day + step)
            : DateTime(_date.year, _date.month + step, 1);
      });

  Future<void> _pick() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: _period == _Period.day ? 'Choisir un jour' : 'Choisir un jour du mois',
    );
    if (d != null) setState(() => _date = d);
  }

  @override
  Widget build(BuildContext context) {
    final store = Deps.of(context).store;
    final theme = Theme.of(context);

    final periodTxns = _period == _Period.day ? store.txnsOfDay(dayKey(_date)) : store.txnsOfMonth(_date.year, _date.month);
    final txns = periodTxns
        .where((t) => _currency == null || AppStore.touches(t, _currency!))
        .where(_kind.accepts)
        .where((t) => store.matches(t, _query))
        .toList()
        .reversed
        .toList();
    final flows = Flows(periodTxns.where((t) => store.matches(t, _query)));
    final currencies = _currency == null ? Currency.values : [_currency!];

    return Scaffold(
      appBar: AppBar(title: const Text('Journal'), actions: const [SyncBadge()]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        children: [
          SegmentedButton<_Period>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: _Period.day, label: Text('Par jour')),
              ButtonSegment(value: _Period.month, label: Text('Par mois')),
            ],
            selected: {_period},
            onSelectionChanged: (s) => setState(() => _period = s.first),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              IconButton(onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left)),
              Expanded(
                child: TextButton.icon(
                  onPressed: _pick,
                  icon: const Icon(Icons.calendar_month),
                  label: Text(_period == _Period.day ? formatDay(_date) : formatMonth(_date), textAlign: TextAlign.center),
                ),
              ),
              IconButton(onPressed: _isCurrent ? null : () => _shift(1), icon: const Icon(Icons.chevron_right)),
            ],
          ),
          TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Chercher un nom ou une note',
              isDense: true,
            ),
            onChanged: (v) => setState(() => _query = v.trim()),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chip('Toutes devises', _currency == null, () => setState(() => _currency = null)),
                for (final c in Currency.values)
                  _chip(c.label, _currency == c, () => setState(() => _currency = c), color: currencyColor(c)),
              ],
            ),
          ),

          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${flows.count} opération(s)${_query.isEmpty ? '' : ' pour « $_query »'}',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  _summaryTable(store, currencies, flows),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final k in _KindFilter.values) _chip(k.label, _kind == k, () => setState(() => _kind = k)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (txns.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('Aucune opération')),
            )
          else
            ..._grouped(store, txns),
        ],
      ),
    );
  }

  /// Tableau : une ligne par devise (Matin / Entrées / Sorties / Soir pour un jour,
  /// Entrées / Sorties / Différence pour un mois).
  Widget _summaryTable(AppStore store, List<Currency> currencies, Flows flows) {
    final isDay = _period == _Period.day && _query.isEmpty;
    final key = dayKey(_date);
    final opening = store.openingAmounts(key);
    final headers = isDay ? ['', 'Matin', 'Entrées', 'Sorties', 'Soir'] : ['', 'Entrées', 'Sorties', 'Différence'];

    return Table(
      columnWidths: const {0: IntrinsicColumnWidth()},
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(children: [for (final h in headers) _cell(h, bold: true, small: true)]),
        for (final c in currencies)
          TableRow(children: [
            _cell(c.label, bold: true, color: currencyColor(c), align: TextAlign.left),
            if (isDay) _cell(formatNumber(opening[c], c)),
            _cell(formatNumber(flows.cashIn[c], c), color: Colors.green.shade700),
            _cell(formatNumber(flows.cashOut[c], c), color: Colors.red.shade700),
            if (isDay)
              _cell(formatNumber(opening[c] + flows.net[c], c), bold: true)
            else
              _cell('${flows.net[c] > 0 ? '+' : ''}${formatNumber(flows.net[c], c)}', bold: true),
          ]),
      ],
    );
  }

  /// Liste des opérations, avec un titre par jour en vue mensuelle.
  List<Widget> _grouped(AppStore store, List<Txn> txns) {
    final widgets = <Widget>[];
    String? lastDay;
    var current = <Widget>[];
    void flush() {
      if (current.isNotEmpty) widgets.add(Card(child: Column(children: current)));
      current = [];
    }

    for (final t in txns) {
      final d = dayKey(t.date);
      if (_period == _Period.month && d != lastDay) {
        flush();
        widgets.add(Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
          child: Text(formatDay(t.date), style: const TextStyle(fontWeight: FontWeight.bold)),
        ));
        lastDay = d;
      }
      current.add(TxnTile(
        txn: t,
        clientName: store.clientName(t.clientId),
        onTap: t.clientId == null || store.client(t.clientId)?.deleted == true ? null : () => openClient(context, t.clientId!),
      ));
    }
    flush();
    return widgets;
  }

  Widget _chip(String label, bool selected, VoidCallback onTap, {Color? color}) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ChoiceChip(
          label: Text(label, style: TextStyle(color: selected ? null : color)),
          selected: selected,
          onSelected: (_) => onTap(),
        ),
      );

  Widget _cell(String text, {bool bold = false, bool small = false, Color? color, TextAlign align = TextAlign.right}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Text(
          text,
          textAlign: align,
          style: TextStyle(
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: color ?? (small ? Colors.grey : null),
            fontSize: small ? 11 : 13,
          ),
        ),
      );
}
