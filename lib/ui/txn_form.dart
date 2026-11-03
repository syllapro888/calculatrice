import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app.dart';
import '../core/money.dart';
import '../data/models.dart';
import 'client_form.dart';
import 'widgets.dart';

/// Les trois grands choix du formulaire.
enum EntryMode { cashIn, cashOut, debt }

/// Les choix possibles dans « Dette ».
enum DebtChoice {
  heOwes('Il me doit'),
  iOwe('Je lui dois'),
  heRepaid('Il m\'a remboursé'),
  iRepaid('Je lui ai remboursé');

  const DebtChoice(this.label);
  final String label;
}

/// Ouvre le formulaire. [clientId] fixe le client (depuis sa fiche).
Future<void> showTxnForm(
  BuildContext context, {
  String? clientId,
  EntryMode mode = EntryMode.cashIn,
  Currency currency = Currency.xaf,
  bool lockClient = false,
}) {
  return Navigator.of(context).push(MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => TxnFormScreen(clientId: clientId, mode: mode, currency: currency, lockClient: lockClient),
  ));
}

class TxnFormScreen extends StatefulWidget {
  const TxnFormScreen({
    super.key,
    this.clientId,
    required this.mode,
    required this.currency,
    this.lockClient = false,
  });
  final String? clientId;
  final EntryMode mode;
  final Currency currency;
  final bool lockClient;

  @override
  State<TxnFormScreen> createState() => _TxnFormScreenState();
}

class _TxnFormScreenState extends State<TxnFormScreen> {
  late EntryMode _mode = widget.mode;
  late String? _clientId = widget.clientId;
  late Currency _cur = widget.currency;
  DebtChoice _debt = DebtChoice.heOwes;
  final _amount = TextEditingController();
  final _note = TextEditingController();
  DateTime _date = DateTime.now();
  String? _error;

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_date));
    setState(() => _date = DateTime(d.year, d.month, d.day, t?.hour ?? _date.hour, t?.minute ?? _date.minute));
  }

  TxnKind get _kind => switch (_mode) {
        EntryMode.cashIn => TxnKind.cashIn,
        EntryMode.cashOut => TxnKind.cashOut,
        EntryMode.debt => switch (_debt) {
            DebtChoice.heOwes || DebtChoice.iOwe => TxnKind.debt,
            DebtChoice.heRepaid => TxnKind.received,
            DebtChoice.iRepaid => TxnKind.given,
          },
      };

  Future<void> _save() async {
    final store = Deps.of(context).store;
    final amount = parseAmount(_amount.text);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Entrez un montant valide.');
      return;
    }
    if (_mode == EntryMode.debt && _clientId == null) {
      setState(() => _error = 'Choisissez le client pour une dette.');
      return;
    }

    final kind = _kind;
    final signed = kind == TxnKind.debt && _debt == DebtChoice.iOwe ? -amount : amount;

    // Avertit si la caisse du jour devient négative.
    if ((kind == TxnKind.cashOut || kind == TxnKind.given) &&
        store.todayOpened &&
        dayKey(_date) == dayKey(DateTime.now())) {
      final cash = store.currentCash[_cur];
      if (cash - amount < 0) {
        final ok = await confirm(context,
            title: 'Pas assez en caisse',
            message: 'Il reste ${formatMoney(cash, _cur)}. Enregistrer quand même ?',
            ok: 'Enregistrer');
        if (!ok) return;
      }
    }

    final txn = Txn(
      id: store.newId(),
      clientId: _clientId,
      kind: kind,
      createdAt: _date.millisecondsSinceEpoch,
      fromCur: _cur,
      fromAmt: signed,
      note: _note.text.trim(),
      updatedAt: nowMs(),
    );
    await store.saveTxn(txn);
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Opération enregistrée.')));
  }

  @override
  Widget build(BuildContext context) {
    final store = Deps.of(context).store;
    final theme = Theme.of(context);
    final color = switch (_mode) {
      EntryMode.cashIn => Colors.green.shade700,
      EntryMode.cashOut => Colors.red.shade700,
      EntryMode.debt => Colors.orange.shade800,
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle opération')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<EntryMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: EntryMode.cashIn, label: Text('Entrée'), icon: Icon(Icons.south_west, size: 18)),
                ButtonSegment(value: EntryMode.cashOut, label: Text('Sortie'), icon: Icon(Icons.north_east, size: 18)),
                ButtonSegment(value: EntryMode.debt, label: Text('Dette'), icon: Icon(Icons.receipt_long, size: 18)),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() {
                _mode = s.first;
                _error = null;
              }),
            ),
            const SizedBox(height: 8),
            Text(_help, style: theme.textTheme.bodySmall),

            if (_mode == EntryMode.debt) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final d in DebtChoice.values)
                    ChoiceChip(
                      label: Text(d.label),
                      selected: _debt == d,
                      onSelected: (_) => setState(() => _debt = d),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 20),

            Text('Devise', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            CurrencySelector(value: _cur, onChanged: (c) => setState(() => _cur = c)),
            const SizedBox(height: 16),
            AmountField(
              controller: _amount,
              label: 'Combien ?',
              currency: _cur,
              autofocus: true,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // À qui
            if (widget.lockClient)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: InitialsAvatar(name: store.clientName(_clientId), radius: 20),
                title: Text(store.clientName(_clientId)),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      key: ValueKey('client-$_clientId'),
                      initialValue: _clientId,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: _mode == EntryMode.cashIn ? 'De qui ?' : 'À qui ?'),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('Personne de passage')),
                        for (final c in store.clients) DropdownMenuItem<String?>(value: c.id, child: Text(c.name)),
                      ],
                      onChanged: (v) => setState(() => _clientId = v),
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Nouveau client',
                    icon: const Icon(Icons.person_add_alt_1),
                    onPressed: () async {
                      final c = await showClientForm(context);
                      if (c != null) setState(() => _clientId = c.id);
                    },
                  ),
                ],
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _note,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Note (pourquoi, détail…)'),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule),
              title: Text(DateFormat('EEEE d MMMM y · HH:mm', 'fr').format(_date)),
              trailing: const Text('Modifier'),
              onTap: _pickDate,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: Text(_saveLabel),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54), backgroundColor: color),
            ),
          ],
        ),
      ),
    );
  }

  String get _saveLabel {
    final a = parseAmount(_amount.text);
    final amount = a == null || a <= 0 ? '' : ' ${formatMoney(a, _cur)}';
    return switch (_mode) {
      EntryMode.cashIn => 'Enregistrer l\'entrée$amount',
      EntryMode.cashOut => 'Enregistrer la sortie$amount',
      EntryMode.debt => 'Enregistrer$amount',
    };
  }

  String get _help => switch (_mode) {
        EntryMode.cashIn => 'Argent reçu : il s\'ajoute à votre caisse.',
        EntryMode.cashOut => 'Argent donné : il sort de votre caisse.',
        EntryMode.debt => switch (_debt) {
            DebtChoice.heOwes => 'Le client vous doit de l\'argent (la caisse ne change pas).',
            DebtChoice.iOwe => 'Vous devez de l\'argent au client (la caisse ne change pas).',
            DebtChoice.heRepaid => 'Le client vous rembourse : l\'argent entre en caisse et sa dette diminue.',
            DebtChoice.iRepaid => 'Vous remboursez le client : l\'argent sort de la caisse.',
          },
      };
}
