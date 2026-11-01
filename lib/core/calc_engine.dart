/// Moteur de la calculatrice : gère la saisie et le calcul avec priorités
/// (× et ÷ avant + et −). Le pourcentage divise le nombre en cours par 100.
class CalcEngine {
  /// Expression en cours, avec les opérateurs + − × ÷ et ',' comme virgule.
  String expression = '';

  /// Dernier résultat affiché après "=".
  String? result;

  static const operators = ['+', '−', '×', '÷'];

  bool get _endsWithOperator => expression.isNotEmpty && operators.contains(expression[expression.length - 1]);

  String get _currentNumber {
    final m = RegExp(r'-?[0-9,]*$').firstMatch(expression);
    return m?.group(0) ?? '';
  }

  /// Saisie brute (chiffres seulement), utilisée pour vérifier le code PIN.
  String get rawDigits => expression;

  void digit(String d) {
    if (result != null) {
      expression = '';
      result = null;
    }
    final cur = _currentNumber;
    if (cur == '0' || cur == '-0') {
      expression = expression.substring(0, expression.length - 1) + d;
    } else {
      expression += d;
    }
  }

  void comma() {
    if (result != null) {
      expression = '0';
      result = null;
    }
    final cur = _currentNumber;
    if (cur.contains(',')) return;
    expression += (cur.isEmpty || cur == '-') ? '0,' : ',';
  }

  void applyOperator(String op) {
    if (result != null) {
      expression = result!;
      result = null;
    }
    if (expression.isEmpty) {
      if (op == '−') expression = '-';
      return;
    }
    if (expression == '-') return;
    if (_endsWithOperator) {
      expression = expression.substring(0, expression.length - 1) + op;
    } else {
      expression += op;
    }
  }

  void clear() {
    expression = '';
    result = null;
  }

  void backspace() {
    if (result != null) {
      result = null;
      return;
    }
    if (expression.isNotEmpty) expression = expression.substring(0, expression.length - 1);
  }

  void toggleSign() {
    if (result != null) {
      expression = result!;
      result = null;
    }
    final cur = _currentNumber;
    if (cur.isEmpty) return;
    final start = expression.length - cur.length;
    expression = expression.substring(0, start) + (cur.startsWith('-') ? cur.substring(1) : '-$cur');
  }

  void percent() {
    if (result != null) {
      expression = result!;
      result = null;
    }
    final cur = _currentNumber;
    if (cur.isEmpty || cur == '-') return;
    final v = double.tryParse(cur.replaceAll(',', '.'));
    if (v == null) return;
    final start = expression.length - cur.length;
    expression = expression.substring(0, start) + formatResult(v / 100);
  }

  /// Calcule l'expression. Renvoie false en cas d'erreur (ex. division par zéro).
  bool equals() {
    if (expression.isEmpty) return true;
    final v = evaluate(expression);
    if (v == null) {
      result = 'Erreur';
      expression = '';
      return false;
    }
    result = formatResult(v);
    return true;
  }

  /// Évalue une expression comme "12+3×4÷2". Renvoie null si invalide.
  static double? evaluate(String expr) {
    var e = expr;
    while (e.isNotEmpty && operators.contains(e[e.length - 1])) {
      e = e.substring(0, e.length - 1);
    }
    if (e.isEmpty || e == '-') return null;

    final numbers = <double>[];
    final ops = <String>[];
    final buf = StringBuffer();
    for (var i = 0; i < e.length; i++) {
      final ch = e[i];
      final isUnaryMinus = ch == '-' && buf.isEmpty;
      if (operators.contains(ch) && !isUnaryMinus) {
        final n = double.tryParse(buf.toString().replaceAll(',', '.'));
        if (n == null) return null;
        numbers.add(n);
        ops.add(ch);
        buf.clear();
      } else {
        buf.write(ch);
      }
    }
    final last = double.tryParse(buf.toString().replaceAll(',', '.'));
    if (last == null) return null;
    numbers.add(last);

    // × et ÷ d'abord.
    final n2 = <double>[numbers.first];
    final o2 = <String>[];
    for (var i = 0; i < ops.length; i++) {
      final op = ops[i];
      final b = numbers[i + 1];
      if (op == '×') {
        n2[n2.length - 1] = n2.last * b;
      } else if (op == '÷') {
        if (b == 0) return null;
        n2[n2.length - 1] = n2.last / b;
      } else {
        n2.add(b);
        o2.add(op);
      }
    }
    var total = n2.first;
    for (var i = 0; i < o2.length; i++) {
      total = o2[i] == '+' ? total + n2[i + 1] : total - n2[i + 1];
    }
    if (total.isNaN || total.isInfinite) return null;
    return total;
  }

  static String formatResult(double v) {
    if (v == v.roundToDouble() && v.abs() < 1e15) return v.round().toString();
    var s = v.toStringAsFixed(10);
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    return s.replaceAll('.', ',');
  }
}
