import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app.dart';
import '../core/calc_engine.dart';
import 'home_screen.dart';

/// Calculatrice qui fonctionne vraiment. Taper le code secret puis « = » ouvre le carnet.
class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  final _engine = CalcEngine();

  static const _bg = Colors.black;
  static const _grey = Color(0xFFA5A5A5);
  static const _dark = Color(0xFF333333);
  static const _orange = Color(0xFFFF9F0A);

  void _press(String key) {
    HapticFeedback.selectionClick();
    setState(() {
      switch (key) {
        case 'AC':
          _engine.clear();
        case 'C':
          _engine.backspace();
        case '±':
          _engine.toggleSign();
        case '%':
          _engine.percent();
        case ',':
          _engine.comma();
        case '=':
          _equals();
        case '+' || '−' || '×' || '÷':
          _engine.applyOperator(key);
        default:
          _engine.digit(key);
      }
    });
  }

  void _equals() {
    final raw = _engine.rawDigits;
    if (RegExp(r'^[0-9]{4,8}$').hasMatch(raw) && Deps.of(context).pin.check(raw)) {
      _engine.clear();
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HomeScreen()));
      return;
    }
    _engine.equals();
  }

  String get _display {
    final text = _engine.result ?? (_engine.expression.isEmpty ? '0' : _engine.expression);
    return text.replaceAll('-', '−');
  }

  @override
  Widget build(BuildContext context) {
    final showC = _engine.expression.isNotEmpty && _engine.result == null;
    final rows = [
      [showC ? 'C' : 'AC', '±', '%', '÷'],
      ['7', '8', '9', '×'],
      ['4', '5', '6', '−'],
      ['1', '2', '3', '+'],
      ['0', ',', '='],
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: LayoutBuilder(builder: (context, constraints) {
            final gap = 12.0;
            final size = ((constraints.maxWidth - 24 - gap * 3) / 4).clamp(56.0, 96.0);
            return Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              child: Column(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      // Glisser sur l'écran efface le dernier chiffre.
                      onHorizontalDragEnd: (_) => _press('C'),
                      child: Container(
                        alignment: Alignment.bottomRight,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (_engine.result != null && _engine.expression.isNotEmpty)
                              Text(
                                _engine.expression.replaceAll('-', '−'),
                                style: const TextStyle(color: _grey, fontSize: 28),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                _display,
                                maxLines: 1,
                                style: const TextStyle(color: Colors.white, fontSize: 80, fontWeight: FontWeight.w300),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  for (final row in rows)
                    Padding(
                      padding: EdgeInsets.only(top: gap),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          for (final key in row) _button(key, size, gap),
                        ],
                      ),
                    ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _button(String key, double size, double gap) {
    final isOp = ['÷', '×', '−', '+', '='].contains(key);
    final isFn = ['AC', 'C', '±', '%'].contains(key);
    final bg = isOp ? _orange : (isFn ? _grey : _dark);
    final fg = isFn ? Colors.black : Colors.white;
    final wide = key == '0';
    return SizedBox(
      width: wide ? size * 2 + gap : size,
      height: size,
      child: Material(
        color: bg,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _press(key),
          child: Align(
            alignment: wide ? const Alignment(-0.6, 0) : Alignment.center,
            child: Text(key, style: TextStyle(color: fg, fontSize: isFn ? 30 : 36, fontWeight: FontWeight.w400)),
          ),
        ),
      ),
    );
  }
}
