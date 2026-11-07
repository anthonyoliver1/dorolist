import 'package:flutter/foundation.dart';

import '../models/pomodoro_settings.dart';

class PomodoroSettingsViewModel extends ChangeNotifier {
  PomodoroSettingsViewModel(PomodoroSettings settings, this._persist)
      : _autoStart = settings.autoStart,
        _values = [
          _durationStep(settings.focusMinutes, 180),
          _durationStep(settings.shortBreakMinutes, 60),
          _durationStep(settings.longBreakMinutes, 90),
          settings.sessionsBeforeLongBreak.clamp(1, 30),
        ];

  final Future<void> Function(PomodoroSettings) _persist;
  final List<int> _values;
  bool _autoStart;
  bool _saving = false;
  String? _error;
  bool _disposed = false;

  bool get autoStart => _autoStart;
  bool get saving => _saving;
  String? get error => _error;
  int valueAt(int index) => _values[index];

  // Older preferences may contain durations outside the five-minute steps.
  static int _durationStep(int value, int maximum) =>
      ((value / 5).round() * 5).clamp(5, maximum);

  void select(int index, int value) {
    _values[index] = value;
    notifyListeners();
  }

  void setAutoStart(bool value) {
    _autoStart = value;
    notifyListeners();
  }

  void restoreDefaults() {
    const defaults = PomodoroSettings();
    _values.setAll(0, [
      defaults.focusMinutes,
      defaults.shortBreakMinutes,
      defaults.longBreakMinutes,
      defaults.sessionsBeforeLongBreak,
    ]);
    _autoStart = defaults.autoStart;
    _error = null;
    notifyListeners();
  }

  Future<bool> save() async {
    if (_saving) return false;
    _saving = true;
    _error = null;
    notifyListeners();
    try {
      await _persist(PomodoroSettings(
        focusMinutes: _values[0],
        shortBreakMinutes: _values[1],
        longBreakMinutes: _values[2],
        sessionsBeforeLongBreak: _values[3],
        autoStart: _autoStart,
      ));
      return true;
    } catch (_) {
      _error = 'Não foi possível salvar. Tente novamente.';
      return false;
    } finally {
      _saving = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
