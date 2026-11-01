import 'package:flutter/material.dart';

import '../app.dart';
import '../core/money.dart';
import '../data/models.dart';
import 'widgets.dart';

/// Ouverture du matin : je compte ma caisse et je fixe les taux du jour.
class OpeningScreen extends StatefulWidget {
  const OpeningScreen({super.key, this.ratesOnly = false});
  final bool ratesOnly;

  @override
  State<OpeningScreen> createState() => _OpeningScreenState();
}

class _OpeningScreenState extends State<OpeningScreen> {
  final _cash = {for (final c in Currency.values) c: TextEditingController()};
  final _rates = {
    for (final p in CurrencyPair.all) p: (buy: TextEditingController(), sell: TextEditingController()),
  };
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
    String r(double? v) => v == null ? '' : formatRate(v).replaceAll(RegExp(r'[\s  ]'), '');
    for (final p in CurrencyPair.all) {
      _rates[p]!.buy.text = r(store.rate(p, buy: true));
      _rates[p]!.sell.text = r(store.rate(p, buy: false));
    }
  }

  Future<void> _save() async {
    final store = Deps.of(context).store;
    if (!widget.ratesOnly) {
      await store.setOpening(dayKey(DateTime.now()), {
        for (final c in Currency.values) c: parseAmount(_cash[c]!.text) ?? 0,
      });
    }
    for (final p in CurrencyPair.all) {
      await store.setRate(p, buy: true, value: parseRate(_rates[p]!.buy.text));
      await store.setRate(p, buy: false, value: parseRate(_rates[p]!.sell.text));
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasHistory = Deps.of(context).store.activeDays.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: Text(widget.ratesOnly ? 'Taux du jour' : 'Ouverture de la journée')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!widget.ratesOnly) ...[
              Text(formatDay(DateTime.now()), style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                hasHistory
                    ? 'Comptez votre caisse. Les montants proposés sont la clôture du dernier jour.'
                    : 'Comptez l\'argent que vous avez en caisse ce matin.',
                style: theme.textTheme.bodyMedium,
              ),
              const SectionTitle('Caisse du matin'),
              for (final c in Currency.values) ...[
                AmountField(controller: _cash[c]!, label: c == Currency.xaf ? 'Francs CFA' : c.code, currency: c),
                const SizedBox(height: 12),
              ],
            ],
            const SectionTitle('Taux du jour'),
            Text(
              'Achat : quand le client vous vend la devise. Vente : quand vous la lui vendez. '
              'Chaque taux reste modifiable au moment de la vente.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            for (final p in CurrencyPair.all) ...[
              Text('1 ${p.base.label} = ? ${p.quote.label}', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _rateField(_rates[p]!.buy, 'Achat')),
                  const SizedBox(width: 12),
                  Expanded(child: _rateField(_rates[p]!.sell, 'Vente')),
                ],
              ),
              const SizedBox(height: 16),
            ],
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: Text(widget.ratesOnly ? 'Enregistrer les taux' : 'Ouvrir la journée'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rateField(TextEditingController c, String label) => TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, isDense: true),
      );
}
