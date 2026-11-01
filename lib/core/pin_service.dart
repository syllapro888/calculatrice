import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Code secret qui ouvre le carnet depuis la calculatrice.
/// Le code n'est jamais stocké en clair, seulement son empreinte.
class PinService {
  PinService(this._prefs);
  final SharedPreferences _prefs;

  static const _hashKey = 'pin_hash';
  static const _saltKey = 'pin_salt';

  bool get hasPin => _prefs.getString(_hashKey) != null;

  static bool isValidPin(String pin) => RegExp(r'^[0-9]{4,8}$').hasMatch(pin);

  String _hash(String pin, String salt) => sha256.convert(utf8.encode('$salt:$pin')).toString();

  Future<void> setPin(String pin) async {
    final rnd = Random.secure();
    final salt = base64Url.encode(List<int>.generate(16, (_) => rnd.nextInt(256)));
    await _prefs.setString(_saltKey, salt);
    await _prefs.setString(_hashKey, _hash(pin, salt));
  }

  bool check(String pin) {
    final salt = _prefs.getString(_saltKey);
    final hash = _prefs.getString(_hashKey);
    if (salt == null || hash == null || !isValidPin(pin)) return false;
    return _hash(pin, salt) == hash;
  }
}
