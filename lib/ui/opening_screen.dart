import 'package:flutter/material.dart';

import '../app.dart';
import '../core/money.dart';
import '../data/models.dart';
import 'widgets.dart';

/// Ouverture du matin : je compte l'argent que j'ai, devise par devise.
class OpeningScreen extends StatefulWidget {
  const OpeningScreen({super.key});

  @override
  State<OpeningScreen> createState() => _OpeningScreenState();
}

class _OpeningScreenState extends State<OpeningScreen> {
  final _cash = {for (final c in Currency.values) c: TextEditingController()};
  bool _init = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    final store = Deps.of(context).store;
    final today = store.opening(dayKey(DateTime.now()));
    final suggested = store.suggestedOpening();
    for (final c in Currency.values) {
      final v = today?.of(c) ?? suggested[c];
      _cash[c]!.text = v == 0 && today == null ? '' : amountToInput(v, c);
    }
  }

  Future<void> _save() async {
    final store = Deps.of(context).store;
    await store.setOpening(dayKey(DateTime.now()), {
      for (final c in Currency.values) c: parseAmount(_cash[c]!.text) ?? 0,
    });
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasHistory = Deps.of(context).store.activeDays.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('Caisse du matin')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(formatDay(DateTime.now()), style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              hasHistory
                  ? 'Comptez votre argent. Les montants proposés sont ceux du soir du dernier jour.'
                  : 'Comptez l\'argent que vous avez ce matin, devise par devise.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            for (final c in Currency.values) ...[
              AmountField(controller: _cash[c]!, label: currencyName(c), currency: c),
              const SizedBox(height: 14),
            ],
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: const Text('Enregistrer'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
            ),
          ],
        ),
      ),
    );
  }
}
