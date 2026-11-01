import 'package:flutter/material.dart';

import '../app.dart';
import '../data/models.dart';

/// Créer ou modifier un client. Renvoie le client enregistré.
Future<Client?> showClientForm(BuildContext context, {Client? edit}) {
  return showModalBottomSheet<Client>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ClientForm(edit: edit),
  );
}

class _ClientForm extends StatefulWidget {
  const _ClientForm({this.edit});
  final Client? edit;

  @override
  State<_ClientForm> createState() => _ClientFormState();
}

class _ClientFormState extends State<_ClientForm> {
  late final _name = TextEditingController(text: widget.edit?.name);
  late final _phone = TextEditingController(text: widget.edit?.phone);
  late final _note = TextEditingController(text: widget.edit?.note);
  String? _error;

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Le nom est obligatoire.');
      return;
    }
    final store = Deps.of(context).store;
    Client c;
    if (widget.edit != null) {
      c = widget.edit!;
      await store.updateClient(c, name: _name.text, phone: _phone.text, note: _note.text);
    } else {
      c = await store.addClient(name: _name.text, phone: _phone.text, note: _note.text);
    }
    if (mounted) Navigator.of(context).pop(c);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.edit == null ? 'Nouveau client' : 'Modifier le client',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              autofocus: widget.edit == null,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: 'Nom', errorText: _error),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Téléphone (facultatif)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Note (facultatif)'),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}
