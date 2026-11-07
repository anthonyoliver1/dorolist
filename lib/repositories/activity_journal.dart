import 'package:flutter/foundation.dart';
import '../models/activity.dart';
import '../models/timer_snapshot.dart';
import '../services/json_storage.dart';

class ActivityJournal extends ChangeNotifier {
  ActivityJournal({JsonStorage? storage})
      : _storage = storage ?? JsonStorage('activity.json');
  final JsonStorage _storage;
  final Map<String, FocusRecord> _focus = {};
  final Map<String, String> _completedTasks = {};
  TimerSnapshot? timer;
  bool loaded = false;
  String? error;
  Future<void>? _loading;

  List<FocusRecord> get sessions => List.unmodifiable(_focus.values);

  Future<void> load() => loaded ? Future.value() : _loading ??= _load();
  Future<void> _load() async {
    try {
      final data = await _storage.read();
      final focus = <String, FocusRecord>{};
      final completed = <String, String>{};
      TimerSnapshot? snapshot;
      if (data != null) {
        if (data['schema'] != 1 ||
            data['sessions'] is! List ||
            data['completedTasks'] is! Map) {
          throw const FormatException('Histórico inválido');
        }
        for (final value in data['sessions']) {
          final record = FocusRecord.fromJson(value);
          if (focus.containsKey(record.id)) {
            throw const FormatException('Sessão duplicada');
          }
          focus[record.id] = record;
        }
        for (final entry in (data['completedTasks'] as Map).entries) {
          if (entry.key is! String ||
              entry.value is! String ||
              !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(entry.value)) {
            throw const FormatException('Histórico inválido');
          }
          completed[entry.key] = entry.value;
        }
        if (data['timer'] != null) {
          snapshot = TimerSnapshot.fromJson(data['timer']);
        }
      }
      _focus
        ..clear()
        ..addAll(focus);
      _completedTasks
        ..clear()
        ..addAll(completed);
      timer = snapshot;
      loaded = true;
      error = null;
    } catch (_) {
      error = 'Não foi possível carregar o histórico e a sessão.';
      rethrow;
    } finally {
      _loading = null;
      _emit();
    }
  }

  int tasksOn(DateTime date) =>
      _completedTasks.values.where((day) => day == dayKey(date)).length;
  List<FocusRecord> sessionsOn(DateTime date) => _focus.values
      .where((record) => dayKey(record.endedAt) == dayKey(date))
      .toList()
    ..sort((a, b) => b.endedAt.compareTo(a.endedAt));
  int secondsOn(DateTime date) =>
      sessionsOn(date).fold(0, (total, record) => total + record.seconds);

  void taskCompleted(String id, DateTime date) {
    _completedTasks['$id:${dayKey(date)}'] = dayKey(date);
  }

  void taskReopened(String id, DateTime date) =>
      _completedTasks.remove('$id:${dayKey(date)}');

  // Completed sessions and the next timer state are persisted in one snapshot.
  void recordFocus(FocusRecord record) {
    _focus.putIfAbsent(record.id, () => record);
  }

  Future<void> persist() async {
    if (!loaded) throw StateError('Histórico ainda não carregado');
    try {
      await _storage.save({
        'schema': 1,
        'sessions': _focus.values.map((r) => r.toJson()).toList(),
        'completedTasks': Map.of(_completedTasks),
        'timer': timer?.toJson()
      });
      error = null;
    } catch (_) {
      error = 'Não foi possível salvar o histórico e a sessão.';
      rethrow;
    } finally {
      _emit();
    }
  }

  bool _disposed = false;
  void _emit() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
