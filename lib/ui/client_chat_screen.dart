import 'package:flutter/material.dart';

import '../app.dart';
import '../core/money.dart';
import '../data/ledger.dart';
import '../data/models.dart';
import 'client_form.dart';
import 'txn_form.dart';
import 'txn_view.dart';
import 'widgets.dart';

void openClient(BuildContext context, String clientId) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => ClientChatScreen(clientId: clientId)));
}

/// Fiche client façon conversation : toutes ses opérations, son solde, et des boutons rapides.
class ClientChatScreen extends StatelessWidget {
  const ClientChatScreen({super.key, required this.clientId});
  final String clientId;

  @override
  Widget build(BuildContext context) {
    final store = Deps.of(context).store;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final client = store.client(clientId);
        if (client == null || client.deleted) {
          return Scaffold(appBar: AppBar(), body: const Center(child: Text('Client introuvable')));
        }
        final txns = store.txnsOfClient(clientId).reversed.toList();
        final balance = store.balanceOf(clientId);
        final flows = store.flowsOfClient(clientId);
        final theme = Theme.of(context);
        final dark = theme.brightness == Brightness.dark;

        return Scaffold(
          backgroundColor: dark ? const Color(0xFF0B141A) : const Color(0xFFEFE7DE),
          appBar: AppBar(
            titleSpacing: 0,
            title: Row(
              children: [
                InitialsAvatar(name: client.name, radius: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(client.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (client.phone.isNotEmpty) Text(client.phone, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'edit') {
                    await showClientForm(context, edit: client);
                  } else if (v == 'delete') {
                    final ok = await confirm(context,
                        title: 'Supprimer ${client.name} ?',
                        message: 'Le client disparaît de la liste. Ses opérations restent dans le journal.');
                    if (ok) {
                      await store.deleteClient(client);
                      if (context.mounted) Navigator.of(context).pop();
                    }
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Modifier')),
                  PopupMenuItem(value: 'delete', child: Text('Supprimer le client')),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              Material(
                color: theme.colorScheme.surface,
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            BalanceText(balance: balance),
                            if (!flows.cashIn.isZero || !flows.cashOut.isZero) ...[
                              const SizedBox(height: 4),
                              _totals('Reçu de lui', flows.cashIn, Colors.green.shade700),
                              _totals('Donné à lui', flows.cashOut, Colors.red.shade700),
                            ],
                          ],
                        ),
                      ),
                      if (client.note.isNotEmpty)
                        Tooltip(message: client.note, child: const Icon(Icons.sticky_note_2_outlined, size: 20)),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: txns.isEmpty
                    ? const Center(child: Text('Aucune opération.\nUtilisez les boutons en bas.', textAlign: TextAlign.center))
                    : ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: txns.length,
                        itemBuilder: (context, i) {
                          final t = txns[i];
                          final newDay = i == txns.length - 1 || dayKey(txns[i + 1].date) != dayKey(t.date);
                          return Column(
                            children: [
                              if (newDay) _DayChip(date: t.date),
                              TxnBubble(
                                txn: t,
                                onLongPress: () async {
                                  final ok = await confirm(context,
                                      title: 'Supprimer cette opération ?', message: txnTitle(t));
                                  if (ok) await store.deleteTxn(t);
                                },
                              ),
                            ],
                          );
                        },
                      ),
              ),
              Material(
                color: theme.colorScheme.surface,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                    child: Row(
                      children: [
                        _action(context, 'Entrée', Icons.south_west, EntryMode.cashIn, Colors.green.shade700),
                        _action(context, 'Sortie', Icons.north_east, EntryMode.cashOut, Colors.red.shade700),
                        _action(context, 'Dette', Icons.receipt_long, EntryMode.debt, Colors.orange.shade800),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _action(BuildContext context, String label, IconData icon, EntryMode mode, Color color) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: FilledButton.tonal(
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10), foregroundColor: color),
          onPressed: () => showTxnForm(context, clientId: clientId, mode: mode, lockClient: true),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [Icon(icon, size: 20), const SizedBox(height: 2), Text(label, style: const TextStyle(fontSize: 12))],
          ),
        ),
      ),
    );
  }
}

Widget _totals(String label, Amounts a, Color color) {
  final parts = [
    for (final c in Currency.values)
      if (a[c] != 0) formatMoney(a[c], c),
  ];
  if (parts.isEmpty) return const SizedBox.shrink();
  return Text('$label : ${parts.join(' · ')}', style: TextStyle(fontSize: 12, color: color));
}

class _DayChip extends StatelessWidget {
  const _DayChip({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(formatDay(date), style: Theme.of(context).textTheme.labelMedium),
      ),
    );
  }
}
