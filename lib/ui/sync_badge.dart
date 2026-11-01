import 'package:flutter/material.dart';

import '../app.dart';

/// Petite icône d'état de la synchro en ligne.
class SyncBadge extends StatelessWidget {
  const SyncBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final deps = Deps.of(context);
    final sync = deps.sync;
    final pending = deps.store.pendingCount;

    IconData icon;
    String tip;
    if (!sync.configured || !sync.available) {
      icon = Icons.cloud_off_outlined;
      tip = 'Mode local (synchro non configurée)';
    } else if (sync.user == null) {
      icon = Icons.cloud_off_outlined;
      tip = 'Non connecté : voir Réglages';
    } else if (sync.syncing) {
      icon = Icons.cloud_sync_outlined;
      tip = 'Synchronisation…';
    } else if (sync.lastError != null || pending > 0) {
      icon = Icons.cloud_upload_outlined;
      tip = pending > 0 ? '$pending élément(s) en attente d\'envoi' : sync.lastError!;
    } else {
      icon = Icons.cloud_done_outlined;
      tip = 'Tout est sauvegardé en ligne';
    }

    return IconButton(
      tooltip: tip,
      icon: Icon(icon),
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tip)));
        sync.syncNow();
      },
    );
  }
}
