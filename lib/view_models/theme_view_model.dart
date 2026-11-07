import 'package:flutter/material.dart';

import '../services/json_storage.dart';

class ThemeViewModel extends ChangeNotifier {
  ThemeViewModel({JsonStorage? storage, ThemeMode mode = ThemeMode.system})
      : _storage = storage ?? JsonStorage('theme_settings.json'),
        _mode = mode;

  final JsonStorage _storage;
  ThemeMode _mode;

  ThemeMode get mode => _mode;

  Future<void> load() async {
    try {
      final settings = await _storage.read();
      _mode = switch (settings?['mode']) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
      notifyListeners();
    } catch (_) {
      // Keep the current theme if the stored preference is unreadable.
    }
  }

  Future<void> select(ThemeMode mode) {
    if (mode != _mode) {
      _mode = mode;
      notifyListeners();
    }
    return _storage.save({'mode': mode.name});
  }
}
