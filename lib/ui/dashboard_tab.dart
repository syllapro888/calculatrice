import 'package:flutter/material.dart';

import '../app.dart';
import '../core/money.dart';
import '../data/models.dart';
import 'client_chat_screen.dart';
import 'opening_screen.dart';
import 'sync_badge.dart';
import 'txn_form.dart';
import 'txn_view.dart';
import 'widgets.dart';

class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key, required this.onOpenTab});
  final ValueChanged<int> onOpenTab;

  @override
  Widget build(BuildContext context) {
    final store = Deps.of(context).store;
    final theme = Theme.of(context);
    final today = dayKey(DateTime.now());
    final summary = store.summaryOf(today);
    final cash = summary.closing;
    final debts = store.debtTotals;
    final recent = store.txns.reversed.take(6).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon carnet'),
        actions: [
          const SyncBadge(),
          IconButton(
            tooltip: 'Verrouiller',
            icon: const Icon(Icons.lock_outline),
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showTxnForm(context),
        icon: const Icon(Icons.currency_exchange),
        label: const Text('Nouvelle vente'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          SectionTitle(
            'Caisse · ${formatDay(DateTime.now())}',
            trailing: store.todayOpened
                ? TextButton(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OpeningScreen())),
                    child: const Text('Modifier'),
                  )
                : null,
          ),
          if (!store.todayOpened)
            Card(
              color: theme.colorScheme.primaryContainer,
              child: ListTile(
                leading: const Icon(Icons.wb_sunny_outlined),
                title: const Text('Ouvrir la journée'),
                subtitle: const Text('Notez votre caisse du matin et les taux du jour'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OpeningScreen())),
              ),
            )
          else
            Row(
              children: [
                for (final c in Currency.values) ...[
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.label, style: TextStyle(color: currencyColor(c), fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                formatNumber(cash[c], c),
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: cash[c] < 0 ? Colors.red : null,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text('Matin : ${formatNumber(summary.opening[c], c)}', style: theme.textTheme.bodySmall),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (c != Currency.values.last) const SizedBox(width: 8),
                ],
              ],
            ),

          SectionTitle(
            'Taux du jour',
            trailing: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const OpeningScreen(ratesOnly: true)),
              ),
              child: const Text('Modifier'),
            ),
          ),
          Card(
            child: Column(
              children: [
                for (final p in CurrencyPair.all)
                  ListTile(
                    dense: true,
                    title: Text('1 ${p.base.label} en ${p.quote.label}'),
                    trailing: Text(
                      'Achat ${_r(store.rate(p, buy: true))}   ·   Vente ${_r(store.rate(p, buy: false))}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ),

          const SectionTitle('Aujourd\'hui'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${summary.exchangeCount} vente(s) de devises', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 10),
                  const Text('Entrées'),
                  const SizedBox(height: 4),
                  AmountChips(amounts: summary.cashIn),
                  const SizedBox(height: 10),
                  const Text('Sorties'),
                  const SizedBox(height: 4),
                  AmountChips(amounts: summary.cashOut),
                ],
              ),
            ),
          ),

          SectionTitle('Dettes', trailing: TextButton(onPressed: () => onOpenTab(1), child: const Text('Clients'))),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Les clients me doivent', style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  AmountChips(amounts: debts.owedToMe),
                  const SizedBox(height: 12),
                  Text('Je dois aux clients', style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  AmountChips(amounts: debts.iOwe),
                ],
              ),
            ),
          ),

          SectionTitle('Dernières opérations', trailing: TextButton(onPressed: () => onOpenTab(2), child: const Text('Journal'))),
          if (recent.isEmpty)
            const Card(child: ListTile(title: Text('Aucune opération pour le moment')))
          else
            Card(
              child: Column(
                children: [
                  for (final t in recent)
                    TxnTile(
                      txn: t,
                      clientName: store.clientName(t.clientId),
                      showDate: dayKey(t.date) != today,
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

  static String _r(double? v) => v == null ? '—' : formatRate(v);
}
