/// Tracks model license acceptance via SharedPreferences
library;

import 'package:shared_preferences/shared_preferences.dart';

class LicenseService {
  static const _kPrefix = 'license_accepted_';
  final SharedPreferences _prefs;

  LicenseService({required SharedPreferences prefs}) : _prefs = prefs;

  bool isAccepted(String modelId) {
    return _prefs.getBool('$_kPrefix$modelId') ?? false;
  }

  Future<void> markAccepted(String modelId) async {
    await _prefs.setBool('$_kPrefix$modelId', true);
  }
}
