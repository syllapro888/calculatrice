import 'package:flutter/material.dart';

import '../app.dart';
import '../core/money.dart';
import '../data/ledger.dart';
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
    final debts = store.debtTotals;
    final recent = store.txns.reversed.take(8).toList();

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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          SectionTitle(
            formatDay(DateTime.now()),
            trailing: TextButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OpeningScreen())),
              icon: const Icon(Icons.wb_sunny_outlined, size: 18),
              label: Text(store.todayOpened ? 'Caisse du matin' : 'Noter la caisse'),
            ),
          ),
          if (!store.todayOpened)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                color: theme.colorScheme.primaryContainer,
                child: ListTile(
                  leading: const Icon(Icons.wb_sunny_outlined),
                  title: const Text('Notez votre argent du matin'),
                  subtitle: const Text('FCFA, dollars et euros, chacun à part'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OpeningScreen())),
                ),
              ),
            ),
          for (final c in Currency.values) ...[
            _CurrencyCard(currency: c, summary: summary),
            const SizedBox(height: 12),
          ],

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
}

/// Un bloc par devise : ce que j'ai maintenant, le matin, les entrées et sorties du jour,
/// et les boutons pour noter une entrée ou une sortie dans cette devise.
class _CurrencyCard extends StatelessWidget {
  const _CurrencyCard({required this.currency, required this.summary});
  final Currency currency;
  final DaySummary summary;

  @override
  Widget build(BuildContext context) {
    final c = currency;
    final theme = Theme.of(context);
    final color = currencyColor(c);
    final now = summary.closing[c];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: color.withValues(alpha: 0.10),
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Row(
              children: [
                Text(currencyName(c), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
                const Spacer(),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      formatMoney(now, c),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: now < 0 ? Colors.red : null,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
            child: Row(
              children: [
                _figure('Matin', summary.opening[c], c, null),
                _figure('Entrées', summary.cashIn[c], c, Colors.green.shade700, prefix: '+'),
                _figure('Sorties', summary.cashOut[c], c, Colors.red.shade700, prefix: '−'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.green.shade700),
                    onPressed: () => showTxnForm(context, mode: EntryMode.cashIn, currency: c),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Entrée'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red.shade700),
                    onPressed: () => showTxnForm(context, mode: EntryMode.cashOut, currency: c),
                    icon: const Icon(Icons.remove, size: 18),
                    label: const Text('Sortie'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _figure(String label, int value, Currency c, Color? color, {String prefix = ''}) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '${value == 0 ? '' : prefix}${formatNumber(value, c)}',
                style: TextStyle(fontWeight: FontWeight.w600, color: color),
              ),
            ),
          ],
        ),
      );
}
