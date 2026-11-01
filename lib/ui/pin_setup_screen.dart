import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app.dart';
import '../core/pin_service.dart';
import 'calculator_screen.dart';

/// Création ou changement du code secret.
class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key, this.firstLaunch = false});
  final bool firstLaunch;

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  final _pin = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;

  Future<void> _save() async {
    final pin = _pin.text.trim();
    if (!PinService.isValidPin(pin)) {
      setState(() => _error = 'Le code doit contenir 4 à 8 chiffres.');
      return;
    }
    if (pin != _confirm.text.trim()) {
      setState(() => _error = 'Les deux codes ne sont pas identiques.');
      return;
    }
    await Deps.of(context).pin.setPin(pin);
    if (!mounted) return;
    if (widget.firstLaunch) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const CalculatorScreen()));
    } else {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code secret modifié.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.firstLaunch ? 'Bienvenue' : 'Changer le code secret'),
        automaticallyImplyLeading: !widget.firstLaunch,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Icon(Icons.lock_outline, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              widget.firstLaunch ? 'Créez votre code secret' : 'Nouveau code secret',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'L\'app s\'affiche comme une calculatrice normale.\n'
              'Pour ouvrir votre carnet, tapez votre code puis appuyez sur « = ».',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 28),
            TextField(
              controller: _pin,
              obscureText: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(8)],
              decoration: const InputDecoration(labelText: 'Code (4 à 8 chiffres)'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirm,
              obscureText: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(8)],
              decoration: const InputDecoration(labelText: 'Confirmer le code'),
              onSubmitted: (_) => _save(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}
