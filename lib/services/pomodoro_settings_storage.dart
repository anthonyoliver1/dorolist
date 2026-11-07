import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/pomodoro_settings.dart';

class PomodoroSettingsStorage {
  PomodoroSettingsStorage({Future<Directory> Function()? directory})
      : _directory = directory ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _directory;

  Future<File> _file() async => File(
        '${(await _directory()).path}/pomodoro_settings.json',
      );

  Future<PomodoroSettings> read() async {
    final file = await _file();
    if (!await file.exists()) return const PomodoroSettings();
    return PomodoroSettings.fromJson(jsonDecode(await file.readAsString()));
  }

  Future<void> save(PomodoroSettings settings) async {
    final file = await _file();
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(jsonEncode(settings.toJson()), flush: true);
    await temporary.rename(file.path);
  }
}
