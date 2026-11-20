import 'package:flutter/material.dart';

import '../app.dart';
import '../data/models.dart';
import '../data/store.dart';
import 'client_chat_screen.dart';
import 'sync_badge.dart';
import 'txn_form.dart';
import 'txn_view.dart';
import 'widgets.dart';

enum _DebtView { clients, history }

/// Page des dettes, complètement à part : rien ici ne compte dans la caisse
/// ni dans le journal, et la caisse / le journal ne comptent rien d'ici.
class DebtsTab extends StatefulWidget {
  const DebtsTab({super.key});

  @override
  State<DebtsTab> createState() => _DebtsTabState();
}

class _DebtsTabState extends State<DebtsTab> {
  _DebtView _view = _DebtView.clients;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final store = Deps.of(context).store;
    final theme = Theme.of(context);
    final totals = store.debtTotals;
    final q = _query.toLowerCase();

    final clients = store.clientsWithDebt
        .where((c) => q.isEmpty || c.name.toLowerCase().contains(q) || c.phone.contains(q))
        .toList();
    final history = store.debtTxns.where((t) => store.matches(t, _query)).toList().reversed.toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Dettes'), actions: const [SyncBadge()]),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.orange.shade800,
        foregroundColor: Colors.white,
        onPressed: () => showTxnForm(context, mode: EntryMode.debt),
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle dette'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Les clients me doivent', style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  AmountChips(amounts: totals.owedToMe),
                  const SizedBox(height: 12),
                  Text('Je dois aux clients', style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  AmountChips(amounts: totals.iOwe),
                  const SizedBox(height: 10),
                  Text(
                    'Les dettes et leurs remboursements restent ici : ils ne comptent ni dans la caisse, ni dans le journal.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Chercher un nom ou une note',
              isDense: true,
            ),
            onChanged: (v) => setState(() => _query = v.trim()),
          ),
          const SizedBox(height: 12),
          SegmentedButton<_DebtView>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: _DebtView.clients, label: Text('Par client')),
              ButtonSegment(value: _DebtView.history, label: Text('Historique')),
            ],
            selected: {_view},
            onSelectionChanged: (s) => setState(() => _view = s.first),
          ),
          const SizedBox(height: 8),
          if (_view == _DebtView.clients)
            ..._clientList(store, clients)
          else
            ..._history(store, history),
        ],
      ),
    );
  }

  List<Widget> _clientList(AppStore store, List<Client> clients) {
    if (clients.isEmpty) {
      return const [
        Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Aucune dette en cours'))),
      ];
    }
    return [
      Card(
        child: Column(
          children: [
            for (final c in clients)
              ListTile(
                leading: InitialsAvatar(name: c.name, radius: 20),
                title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: BalanceText(balance: store.balanceOf(c.id), compact: true),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => openClient(context, c.id),
              ),
          ],
        ),
      ),
    ];
  }

  /// Toutes les opérations de dette, groupées par jour.
  List<Widget> _history(AppStore store, List<Txn> txns) {
    if (txns.isEmpty) {
      return const [
        Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Aucune opération de dette'))),
      ];
    }
    final widgets = <Widget>[];
    String? lastDay;
    var current = <Widget>[];
    void flush() {
      if (current.isNotEmpty) widgets.add(Card(child: Column(children: current)));
      current = [];
    }

    for (final t in txns) {
      final d = dayKey(t.date);
      if (d != lastDay) {
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
}
