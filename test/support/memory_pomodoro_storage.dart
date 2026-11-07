import 'package:doro_list/models/pomodoro_settings.dart';
import 'package:doro_list/services/pomodoro_settings_storage.dart';

class MemoryPomodoroStorage extends PomodoroSettingsStorage {
  PomodoroSettings settings = const PomodoroSettings();
  bool failRead = false;
  bool failSave = false;

  @override
  Future<PomodoroSettings> read() async {
    if (failRead) throw const FormatException('Invalid settings');
    return settings;
  }

  @override
  Future<void> save(PomodoroSettings value) async {
    if (failSave) throw Exception('Write failed');
    settings = value;
  }
}
