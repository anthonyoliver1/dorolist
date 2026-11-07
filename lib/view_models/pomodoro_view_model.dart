import 'dart:async';
import 'package:flutter/widgets.dart';
import '../models/timer_snapshot.dart';
import '../models/pomodoro_settings.dart';
import '../models/task.dart';
import '../models/activity.dart';
import '../services/pomodoro_settings_storage.dart';
import '../services/session_alerts.dart';
import '../repositories/activity_journal.dart';
import 'tasks_view_model.dart';
import 'summary_view_model.dart';

class PomodoroViewModel extends ChangeNotifier with WidgetsBindingObserver {
  PomodoroViewModel(
      {PomodoroSettingsStorage? settingsStorage,
      this.journal,
      this.tasks,
      SessionAlerts? alerts,
      this.now = DateTime.now})
      : _storage = settingsStorage ?? PomodoroSettingsStorage(),
        alerts = alerts ?? SessionAlerts() {
    WidgetsBinding.instance.addObserver(this);
    tasks?.addListener(_tasksChanged);
  }
  final PomodoroSettingsStorage _storage;
  final ActivityJournal? journal;
  final TasksViewModel? tasks;
  final SessionAlerts alerts;
  final DateTime Function() now;
  PomodoroSettings settings = const PomodoroSettings();
  TimeType phase = TimeType.pomodoro;
  int totalSeconds = 1500;
  int remainingSeconds = 1500;
  int completedSessions = 0;
  DateTime? deadline;
  DateTime? startedAt;
  String? sessionId;
  String? taskId;
  String? taskTitle;
  bool running = false;
  bool stopped = false;
  bool loading = true;
  bool loadFailed = false;
  String? error;
  String? message;
  int messageVersion = 0;
  Timer? _ticker;
  int _counter = 0;
  bool _disposed = false;
  bool _foreground = true;
  Future<void> _alertWork = Future.value();
  int _alertGeneration = 0;

  bool get canChooseTask => !running && startedAt == null;
  String get phaseLabel => switch (phase) {
        TimeType.pomodoro => 'Pomodoro',
        TimeType.short => 'Pausa curta',
        TimeType.long => 'Pausa longa',
        TimeType.custom => 'Tempo customizado',
      };
  String get timeText => formatTime(remainingSeconds);
  String get totalTimeText => formatTime(totalSeconds);
  bool get hasActiveSession => startedAt != null && remainingSeconds > 0;
  SummaryViewModel? get summary {
    final source = journal;
    return source == null ? null : SummaryViewModel(source, now: now);
  }

  String linkedTaskTitle(TasksViewModel? source) {
    for (final task in (source ?? tasks)?.tasks ?? const <Task>[]) {
      if (task.id == taskId) return task.title;
    }
    return taskTitle ?? 'Vincular tarefa';
  }

  static int? parseCustomTime(String text) {
    if (!RegExp(r'^\d{2}:[0-5]\d$').hasMatch(text) || text == '00:00') {
      return null;
    }
    return int.parse(text.substring(0, 2)) * 60 + int.parse(text.substring(3));
  }

  static String formatTime(int seconds) =>
      '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';

  Future<void> load() async {
    loading = true;
    loadFailed = false;
    _emit();
    try {
      settings = await _storage.read();
      try {
        await alerts.initialize();
      } catch (_) {/* Starting a timer still works without notifications. */}
      await journal?.load();
      if (_disposed) return;
      final saved = journal?.timer;
      if (saved == null) {
        _setPhase(TimeType.pomodoro, settings.focusMinutes * 60);
      } else {
        phase = saved.phase;
        totalSeconds = saved.totalSeconds;
        remainingSeconds = saved.remainingSeconds;
        completedSessions = saved.completedSessions;
        deadline = saved.deadline;
        startedAt = saved.startedAt;
        sessionId = saved.sessionId;
        taskId = saved.taskId;
        taskTitle = saved.taskTitle;
        stopped = saved.stopped;
        running = deadline != null;
        if (_unlinkUnavailableTask()) _save();
        if (running) {
          if (deadline!.isAfter(now())) {
            tick();
            _startTicker();
            _scheduleAlert(requestPermissions: false);
          } else {
            _finish(restored: true);
          }
        }
      }
      loading = false;
      _tasksChanged();
      _emit();
    } catch (_) {
      if (_disposed) return;
      loading = false;
      loadFailed = true;
      _emit();
    }
  }

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  void _announce(String value) {
    message = value;
    messageVersion++;
    _emit();
  }

  TimerSnapshot get snapshot => TimerSnapshot(
      phase: phase,
      totalSeconds: totalSeconds,
      remainingSeconds: remainingSeconds,
      completedSessions: completedSessions,
      deadline: running ? deadline : null,
      startedAt: startedAt,
      sessionId: sessionId,
      taskId: taskId,
      taskTitle: taskTitle,
      stopped: stopped);

  Future<void> persist() async {
    if (journal == null) return;
    journal!.timer = snapshot;
    await journal!.persist();
  }

  void _save() {
    unawaited(persist().catchError((Object _) {
      if (_disposed) return;
      error = 'Não foi possível salvar a sessão. Tente novamente.';
      _emit();
    }));
  }

  Future<void> retrySave() async {
    try {
      await persist();
      error = null;
      _emit();
    } catch (_) {
      error = 'Não foi possível salvar a sessão. Tente novamente.';
      _emit();
    }
  }

  void _setPhase(TimeType value, int seconds) {
    _ticker?.cancel();
    phase = value;
    totalSeconds = seconds;
    remainingSeconds = seconds;
    deadline = null;
    startedAt = null;
    sessionId = null;
    running = false;
    stopped = false;
  }

  int _duration(TimeType value) => switch (value) {
        TimeType.pomodoro => settings.focusMinutes * 60,
        TimeType.short => settings.shortBreakMinutes * 60,
        TimeType.long => settings.longBreakMinutes * 60,
        TimeType.custom => totalSeconds,
      };

  void _cancelAlert(String? id) {
    _alertGeneration++;
    if (id == null) return;
    _alertWork =
        _alertWork.then((_) => alerts.cancel(id)).catchError((Object _) {
      if (!_disposed) _announce('Não foi possível cancelar o aviso anterior.');
    });
  }

  void select(TimeType value, {int? seconds}) {
    if (running) return;
    _cancelAlert(sessionId);
    _setPhase(value, seconds ?? _duration(value));
    _save();
    _emit();
  }

  bool selectTask(Task? task) {
    if (loading || loadFailed || !canChooseTask || (task?.completed ?? false)) {
      return false;
    }
    taskId = task?.id;
    taskTitle = task?.title;
    _save();
    _emit();
    return true;
  }

  bool focusOn(Task task) {
    if (!selectTask(task)) return false;
    select(TimeType.pomodoro);
    return true;
  }

  bool _unlinkUnavailableTask() {
    final source = tasks;
    if (source == null ||
        source.loading ||
        source.loadFailed ||
        taskId == null) {
      return false;
    }
    if (source.tasks.any((task) => task.id == taskId && !task.completed)) {
      return false;
    }
    taskId = null;
    taskTitle = null;
    return true;
  }

  void _tasksChanged() {
    if (_disposed || loading || loadFailed || !_unlinkUnavailableTask()) return;
    _save();
    if (running) {
      // Replace the scheduled message without changing the session deadline.
      _cancelAlert(sessionId);
      _scheduleAlert(requestPermissions: false);
    }
    _emit();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  void start() {
    if (running || remainingSeconds <= 0 || loading || loadFailed) return;
    if (phase == TimeType.pomodoro &&
        completedSessions >= settings.sessionsBeforeLongBreak) {
      completedSessions = 0;
    }
    if (startedAt == null && tasks != null && taskId != null) {
      final matches =
          tasks!.tasks.where((task) => task.id == taskId && !task.completed);
      if (matches.isEmpty) {
        taskId = null;
        taskTitle = null;
      } else {
        taskTitle = matches.first.title;
      }
    }
    startedAt ??= now();
    sessionId ??= '${now().microsecondsSinceEpoch}-${_counter++}';
    deadline = now().add(Duration(seconds: remainingSeconds));
    running = true;
    stopped = false;
    _save();
    _startTicker();
    _emit();
    _scheduleAlert();
  }

  void _scheduleAlert({bool requestPermissions = true}) {
    final generation = ++_alertGeneration;
    final id = sessionId!;
    final ends = deadline!;
    final title = _alertTitle;
    final body = _alertBody;
    _alertWork = _alertWork.then((_) async {
      if (_disposed || generation != _alertGeneration) return;
      final warning = await alerts.schedule(
          sessionId: id,
          deadline: ends,
          title: title,
          body: body,
          requestPermissions: requestPermissions);
      if (!_disposed && generation == _alertGeneration && warning != null) {
        _announce(warning);
      }
    }).catchError((Object _) {
      if (!_disposed && generation == _alertGeneration) {
        _announce(
            'Não foi possível agendar o aviso. O cronômetro continua funcionando.');
      }
    });
  }

  String get _alertTitle => phase == TimeType.pomodoro
      ? 'Sessão de foco concluída'
      : phase == TimeType.custom
          ? 'Tempo concluído'
          : 'Fim da pausa';
  String get _alertBody => phase == TimeType.pomodoro
      ? taskTitle == null
          ? 'Hora de descansar.'
          : 'Foco em $taskTitle concluído. Hora de descansar.'
      : 'Sua próxima etapa está pronta para iniciar.';

  bool tick() {
    if (!running || deadline == null || _disposed) return false;
    final milliseconds = deadline!.difference(now()).inMilliseconds;
    if (milliseconds <= 0) {
      _finish();
      return true;
    }
    remainingSeconds = (milliseconds / 1000).ceil();
    _emit();
    return false;
  }

  void pause() {
    if (!running || tick()) return;
    _ticker?.cancel();
    _cancelAlert(sessionId);
    running = false;
    stopped = true;
    deadline = null;
    _save();
    _emit();
  }

  void reset() {
    _cancelAlert(sessionId);
    _setPhase(phase, totalSeconds);
    _save();
    _emit();
  }

  void _finish({bool restored = false}) {
    final oldId = sessionId;
    final title = _alertTitle;
    final body = _alertBody;
    final endedAt = deadline ?? now();
    _ticker?.cancel();
    if (restored) _cancelAlert(oldId);
    if (phase == TimeType.pomodoro) {
      if (oldId != null) {
        journal?.recordFocus(FocusRecord(
            id: oldId,
            endedAt: endedAt,
            seconds: totalSeconds,
            taskId: taskId,
            taskTitle: taskTitle));
      }
      completedSessions++;
      final longBreak = completedSessions >= settings.sessionsBeforeLongBreak;
      _setPhase(
          longBreak ? TimeType.long : TimeType.short,
          (longBreak ? settings.longBreakMinutes : settings.shortBreakMinutes) *
              60);
    } else if (phase == TimeType.custom) {
      running = false;
      stopped = true;
      deadline = null;
      remainingSeconds = 0;
    } else {
      if (phase == TimeType.long) completedSessions = 0;
      _setPhase(TimeType.pomodoro, settings.focusMinutes * 60);
    }
    _save();
    if (!restored && oldId != null) {
      unawaited(alerts
          .completed(
              sessionId: oldId,
              title: title,
              body: body,
              foreground: _foreground)
          .catchError((Object _) {}));
    }
    if (phase != TimeType.custom && settings.autoStart && !restored) start();
    _announce(phase == TimeType.custom
        ? 'Tempo concluído.'
        : settings.autoStart && !restored
            ? 'Etapa concluída. $phaseLabel em andamento.'
            : 'Etapa concluída. $phaseLabel pronto para iniciar.');
  }

  Future<void> updateSettings(PomodoroSettings value) async {
    if (running) return;
    await _storage.save(value);
    if (_disposed) return;
    settings = value;
    completedSessions = 0;
    _cancelAlert(sessionId);
    _setPhase(TimeType.pomodoro, settings.focusMinutes * 60);
    await persist();
    _emit();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (loading || loadFailed) return;
    if (state == AppLifecycleState.resumed) tick();
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _save();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    tasks?.removeListener(_tasksChanged);
    _ticker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    // The OS notification remains scheduled when the application closes.
    super.dispose();
  }
}
