import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app.dart';
import '../core/money.dart';
import '../data/models.dart';
import 'client_form.dart';
import 'widgets.dart';

/// Ouvre le formulaire d'opération. [clientId] fixe le client (depuis sa fiche).
Future<void> showTxnForm(BuildContext context, {String? clientId, TxnKind kind = TxnKind.exchange, bool lockClient = false}) {
  return Navigator.of(context).push(MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => TxnFormScreen(clientId: clientId, initialKind: kind, lockClient: lockClient),
  ));
}

class TxnFormScreen extends StatefulWidget {
  const TxnFormScreen({super.key, this.clientId, required this.initialKind, this.lockClient = false});
  final String? clientId;
  final TxnKind initialKind;
  final bool lockClient;

  @override
  State<TxnFormScreen> createState() => _TxnFormScreenState();
}

class _TxnFormScreenState extends State<TxnFormScreen> {
  late TxnKind _kind = widget.initialKind;
  late String? _clientId = widget.clientId;

  Currency _fromCur = Currency.xaf;
  Currency _toCur = Currency.usd;
  final _from = TextEditingController();
  final _to = TextEditingController();
  final _rate = TextEditingController();
  final _paid = TextEditingController();
  final _note = TextEditingController();
  bool _partial = false;
  bool _clientOwes = true;
  DateTime _date = DateTime.now();
  bool _lastEditedTo = false;
  String? _error;
  bool _rateInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_rateInit) {
      _rateInit = true;
      _applySuggestedRate();
    }
  }

  void _applySuggestedRate() {
    final r = Deps.of(context).store.suggestedRate(_fromCur, _toCur);
    _rate.text = r == null ? '' : formatRate(r).replaceAll(RegExp(r'[\s  ]'), '');
    _recompute();
  }

  void _recompute() {
    final rate = parseRate(_rate.text);
    if (rate == null) return;
    if (_lastEditedTo) {
      final to = parseAmount(_to.text);
      if (to != null) _from.text = amountToInput(convert(to, _toCur, _fromCur, rate), _fromCur);
    } else {
      final from = parseAmount(_from.text);
      if (from != null) _to.text = amountToInput(convert(from, _fromCur, _toCur, rate), _toCur);
    }
  }

  CurrencyPair get _pair => CurrencyPair.of(_fromCur, _toCur);

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

  Future<void> _save() async {
    final store = Deps.of(context).store;
    final amount = parseAmount(_from.text);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Entrez un montant valide.');
      return;
    }
    if (_kind != TxnKind.exchange && _clientId == null) {
      setState(() => _error = 'Choisissez un client.');
      return;
    }

    Txn txn;
    if (_kind == TxnKind.exchange) {
      final to = parseAmount(_to.text);
      final rate = parseRate(_rate.text) ?? 0;
      if (to == null || to <= 0) {
        setState(() => _error = 'Entrez le montant que reçoit le client.');
        return;
      }
      var paid = amount;
      if (_partial) {
        final p = parseAmount(_paid.text);
        if (p == null || p < 0 || p > amount) {
          setState(() => _error = 'Le montant payé doit être entre 0 et ${formatMoney(amount, _fromCur)}.');
          return;
        }
        if (_clientId == null) {
          setState(() => _error = 'Un paiement partiel nécessite un client (pour noter sa dette).');
          return;
        }
        paid = p;
      }
      txn = Txn(
        id: store.newId(),
        clientId: _clientId,
        kind: TxnKind.exchange,
        createdAt: _date.millisecondsSinceEpoch,
        fromCur: _fromCur,
        fromAmt: amount,
        toCur: _toCur,
        toAmt: to,
        rate: rate,
        paidAmt: paid,
        note: _note.text.trim(),
        updatedAt: nowMs(),
      );
    } else {
      final signed = _kind == TxnKind.debt && !_clientOwes ? -amount : amount;
      txn = Txn(
        id: store.newId(),
        clientId: _clientId,
        kind: _kind,
        createdAt: _date.millisecondsSinceEpoch,
        fromCur: _fromCur,
        fromAmt: signed,
        note: _note.text.trim(),
        updatedAt: nowMs(),
      );
    }

    // Avertit si la caisse du jour devient négative.
    if (txn.kind == TxnKind.exchange || txn.kind == TxnKind.given) {
      final cur = txn.kind == TxnKind.exchange ? txn.toCur! : txn.fromCur;
      final out = txn.kind == TxnKind.exchange ? txn.toAmt : txn.fromAmt;
      final cash = store.currentCash[cur];
      if (store.todayOpened && dayKey(_date) == dayKey(DateTime.now()) && cash - out < 0) {
        final ok = await confirm(context,
            title: 'Caisse insuffisante',
            message: 'Il reste ${formatMoney(cash, cur)} en caisse. Enregistrer quand même ?',
            ok: 'Enregistrer');
        if (!ok) return;
      }
    }

    await store.saveTxn(txn);
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${txn.kind.label} enregistré.')));
  }

  @override
  Widget build(BuildContext context) {
    final store = Deps.of(context).store;
    final theme = Theme.of(context);
    final amount = parseAmount(_from.text) ?? 0;
    final paid = parseAmount(_paid.text) ?? 0;
    final rest = _partial ? amount - paid : 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle opération')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<TxnKind>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: TxnKind.exchange, label: Text('Vente'), icon: Icon(Icons.currency_exchange, size: 18)),
                ButtonSegment(value: TxnKind.received, label: Text('Reçu')),
                ButtonSegment(value: TxnKind.given, label: Text('Donné')),
                ButtonSegment(value: TxnKind.debt, label: Text('Dette')),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() {
                _kind = s.first;
                _error = null;
              }),
            ),
            const SizedBox(height: 8),
            Text(_kindHelp, style: theme.textTheme.bodySmall),
            const SizedBox(height: 16),

            // Client
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
                      key: ValueKey('client-$_clientId-${_kind.code}'),
                      initialValue: _clientId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Client'),
                      items: [
                        if (_kind == TxnKind.exchange)
                          const DropdownMenuItem<String?>(value: null, child: Text('Client de passage')),
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

            if (_kind == TxnKind.debt) ...[
              SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: true, label: Text('Le client me doit')),
                  ButtonSegment(value: false, label: Text('Je dois au client')),
                ],
                selected: {_clientOwes},
                onSelectionChanged: (s) => setState(() => _clientOwes = s.first),
              ),
              const SizedBox(height: 16),
            ],

            Text(_kind == TxnKind.exchange ? 'Le client donne' : 'Devise', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            CurrencySelector(
              value: _fromCur,
              onChanged: (c) => setState(() {
                if (c == _toCur) _toCur = _fromCur;
                _fromCur = c;
                if (_kind == TxnKind.exchange) _applySuggestedRate();
              }),
            ),
            const SizedBox(height: 12),
            AmountField(
              controller: _from,
              label: 'Montant',
              currency: _fromCur,
              autofocus: true,
              onChanged: (_) => setState(() {
                _lastEditedTo = false;
                _recompute();
              }),
            ),

            if (_kind == TxnKind.exchange) ...[
              const SizedBox(height: 20),
              Text('Le client reçoit', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              CurrencySelector(
                value: _toCur,
                exclude: _fromCur,
                onChanged: (c) => setState(() {
                  _toCur = c;
                  _applySuggestedRate();
                }),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _rate,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(_recompute),
                decoration: InputDecoration(
                  labelText: 'Taux : 1 ${_pair.base.label} = ? ${_pair.quote.label}',
                  helperText: store.suggestedRate(_fromCur, _toCur) == null
                      ? 'Aucun taux du jour : réglez-le dans l\'accueil.'
                      : 'Taux du jour proposé, modifiable.',
                ),
              ),
              const SizedBox(height: 12),
              AmountField(
                controller: _to,
                label: 'Montant remis',
                currency: _toCur,
                onChanged: (_) => setState(() {
                  _lastEditedTo = true;
                  _recompute();
                }),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Paiement partiel'),
                subtitle: const Text('Le reste sera noté comme dette du client'),
                value: _partial,
                onChanged: (v) => setState(() {
                  _partial = v;
                  if (v && _paid.text.isEmpty) _paid.text = '0';
                }),
              ),
              if (_partial) ...[
                AmountField(
                  controller: _paid,
                  label: 'Payé maintenant',
                  currency: _fromCur,
                  onChanged: (_) => setState(() {}),
                ),
                if (rest > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('Dette du client : ${formatMoney(rest, _fromCur)}',
                        style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold)),
                  ),
              ],
            ],

            const SizedBox(height: 16),
            TextField(
              controller: _note,
              decoration: const InputDecoration(labelText: 'Note (facultatif)'),
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
              label: const Text('Enregistrer'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
            ),
          ],
        ),
      ),
    );
  }

  String get _kindHelp => switch (_kind) {
        TxnKind.exchange => 'Vente de devises : le client vous donne une devise et reçoit une autre.',
        TxnKind.received => 'Le client vous remet de l\'argent (remboursement, dépôt…). Entre dans la caisse.',
        TxnKind.given => 'Vous remettez de l\'argent au client (prêt, rendu de dépôt…). Sort de la caisse.',
        TxnKind.debt => 'Noter une dette sans mouvement de caisse (ex. ancienne dette).',
      };
}
