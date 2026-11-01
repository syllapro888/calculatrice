import 'package:flutter/material.dart';

import '../app.dart';
import '../data/models.dart';
import 'client_chat_screen.dart';
import 'client_form.dart';
import 'sync_badge.dart';
import 'txn_view.dart';
import 'widgets.dart';

/// Liste des clients, comme une liste de discussions.
class ClientsTab extends StatefulWidget {
  const ClientsTab({super.key});

  @override
  State<ClientsTab> createState() => _ClientsTabState();
}

class _ClientsTabState extends State<ClientsTab> {
  String _query = '';
  bool _onlyDebts = false;

  @override
  Widget build(BuildContext context) {
    final store = Deps.of(context).store;
    final q = _query.toLowerCase();
    final clients = store.clients.where((c) {
      if (q.isNotEmpty && !c.name.toLowerCase().contains(q) && !c.phone.contains(q)) return false;
      if (_onlyDebts && store.balanceOf(c.id).isZero) return false;
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clients'),
        actions: const [SyncBadge()],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Nouveau client',
        onPressed: () async {
          final c = await showClientForm(context);
          if (c != null && context.mounted) openClient(context, c.id);
        },
        child: const Icon(Icons.person_add_alt_1),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: SearchBar(
              hintText: 'Rechercher un client',
              leading: const Icon(Icons.search),
              elevation: const WidgetStatePropertyAll(0),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Avec dette'),
                  selected: _onlyDebts,
                  onSelected: (v) => setState(() => _onlyDebts = v),
                ),
                const Spacer(),
                Text('${clients.length} client(s)', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Expanded(
            child: clients.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        store.clients.isEmpty ? 'Ajoutez votre premier client avec le bouton +' : 'Aucun client trouvé',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 88),
                    itemCount: clients.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 76),
                    itemBuilder: (context, i) {
                      final c = clients[i];
                      final last = store.lastTxnOf(c.id);
                      return ListTile(
                        leading: InitialsAvatar(name: c.name),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(c.name,
                                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                            ),
                            if (last != null)
                              Text(
                                dayKey(last.date) == dayKey(DateTime.now()) ? formatTime(last.date) : formatDay(last.date),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(last == null ? 'Aucune opération' : txnTitle(last), maxLines: 1, overflow: TextOverflow.ellipsis),
                            BalanceText(balance: store.balanceOf(c.id), compact: true),
                          ],
                        ),
                        onTap: () => openClient(context, c.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
