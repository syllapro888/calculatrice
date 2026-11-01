import 'package:flutter/material.dart';

import '../app.dart';
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
                      Expanded(child: BalanceText(balance: balance)),
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
                        _action(context, 'Vente', Icons.currency_exchange, TxnKind.exchange),
                        _action(context, 'Reçu', Icons.south_west, TxnKind.received),
                        _action(context, 'Donné', Icons.north_east, TxnKind.given),
                        _action(context, 'Dette', Icons.receipt_long, TxnKind.debt),
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

  Widget _action(BuildContext context, String label, IconData icon, TxnKind kind) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: FilledButton.tonal(
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
          onPressed: () => showTxnForm(context, clientId: clientId, kind: kind, lockClient: true),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [Icon(icon, size: 20), const SizedBox(height: 2), Text(label, style: const TextStyle(fontSize: 12))],
          ),
        ),
      ),
    );
  }
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
