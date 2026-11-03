import 'package:flutter/material.dart';

import '../app.dart';
import 'opening_screen.dart';
import 'pin_setup_screen.dart';
import 'widgets.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _message;

  Future<void> _auth(bool register) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    final sync = Deps.of(context).sync;
    final err = register
        ? await sync.register(_email.text, _password.text)
        : await sync.signIn(_email.text, _password.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = err;
    });
    if (err == null) _password.clear();
  }

  @override
  Widget build(BuildContext context) {
    final deps = Deps.of(context);
    final sync = deps.sync;
    final store = deps.store;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Réglages')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          const SectionTitle('Sauvegarde en ligne'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Builder(builder: (context) {
                if (!sync.configured) {
                  return const Text(
                    'Mode local : vos données sont enregistrées sur ce téléphone uniquement.\n\n'
                    'Pour la sauvegarde en ligne et la synchro entre téléphones, il faut configurer Firebase '
                    '(voir le fichier README du projet).',
                  );
                }
                if (!sync.available) {
                  return Text(sync.lastError ?? 'Connexion à Firebase impossible.');
                }
                if (sync.user == null) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Connectez-vous pour sauvegarder vos données et les retrouver sur un autre téléphone. '
                          'Utilisez le même compte sur chaque téléphone.'),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'Email'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _password,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Mot de passe'),
                      ),
                      if (_message != null) ...[
                        const SizedBox(height: 8),
                        Text(_message!, style: TextStyle(color: theme.colorScheme.error)),
                      ],
                      const SizedBox(height: 12),
                      FilledButton(onPressed: _busy ? null : () => _auth(false), child: const Text('Se connecter')),
                      const SizedBox(height: 8),
                      OutlinedButton(onPressed: _busy ? null : () => _auth(true), child: const Text('Créer un compte')),
                    ],
                  );
                }
                final pending = store.pendingCount;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.cloud_done_outlined, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(child: Text(sync.user!.email ?? 'Connecté', style: theme.textTheme.titleSmall)),
                    ]),
                    const SizedBox(height: 8),
                    Text(sync.syncing
                        ? 'Synchronisation en cours…'
                        : sync.lastSync == null
                            ? 'Pas encore synchronisé'
                            : 'Dernière synchro : ${formatDay(sync.lastSync!)} à ${formatTime(sync.lastSync!)}'),
                    Text(pending == 0 ? 'Tout est envoyé.' : '$pending élément(s) en attente d\'envoi.'),
                    if (sync.lastError != null)
                      Text(sync.lastError!, style: TextStyle(color: theme.colorScheme.error)),
                    const SizedBox(height: 12),
                    Wrap(spacing: 8, children: [
                      FilledButton.icon(
                        onPressed: sync.syncing ? null : sync.syncNow,
                        icon: const Icon(Icons.sync),
                        label: const Text('Synchroniser'),
                      ),
                      TextButton(onPressed: sync.signOut, child: const Text('Se déconnecter')),
                    ]),
                  ],
                );
              }),
            ),
          ),
          const SectionTitle('Journée'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.wb_sunny_outlined),
                  title: const Text('Caisse du matin'),
                  subtitle: const Text('FCFA, dollars et euros'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OpeningScreen())),
                ),
              ],
            ),
          ),
          const SectionTitle('Sécurité'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.pin_outlined),
                  title: const Text('Changer le code secret'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PinSetupScreen())),
                ),
                const ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('Pour ouvrir le carnet'),
                  subtitle: Text('Dans la calculatrice, tapez votre code puis « = ». '
                      'Le carnet se referme dès que vous quittez l\'app.'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Center(child: Text('Version 1.1', style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}
