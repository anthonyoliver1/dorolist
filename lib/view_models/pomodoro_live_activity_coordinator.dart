import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'pomodoro_view_model.dart';

import '../services/session_live_activity.dart';

// Native date-based timers handle each second. Only session changes cross the bridge.
class PomodoroLiveActivityCoordinator with WidgetsBindingObserver {
  PomodoroLiveActivityCoordinator(
      {required this.engine,
      required this.activity,
      required this.onOpenFocus});
  final PomodoroViewModel engine;
  final SessionLiveActivity activity;
  final VoidCallback onOpenFocus;
  Future<void> _work = Future.value();
  String? _lastState;
  bool _ready = false;
  (String, String)? _pendingAction;
  bool _disposed = false;

  Future<void> initialize() async {
    engine.addListener(_sync);
    WidgetsBinding.instance.addObserver(this);
    try {
      await activity.initialize(onOpenFocus, onAction: _handleAction);
      if (_disposed) return;
      _ready = true;
      _sync();
    } catch (error) {
      debugPrint('Live Activity indisponível: $error');
    }
  }

  void _sync({bool force = false}) {
    if (!_ready || _disposed || engine.loading || engine.loadFailed) return;
    final pending = _pendingAction;
    if (pending != null) {
      _pendingAction = null;
      _handleAction(pending.$1, pending.$2);
    }
    final active = engine.hasActiveSession;
    final state = active
        ? <String, Object?>{
            'sessionId': engine.sessionId,
            'phase': engine.phase.name,
            'phaseLabel': engine.phaseLabel,
            'taskTitle': engine.taskTitle,
            'totalSeconds': engine.totalSeconds,
            'remainingSeconds': engine.running ? null : engine.remainingSeconds,
            'startedAt': engine.startedAt!.millisecondsSinceEpoch,
            'deadline':
                engine.running ? engine.deadline!.millisecondsSinceEpoch : null,
          }
        : null;
    final key = jsonEncode(state);
    if (!force && key == _lastState) return;
    _lastState = key;
    _work = _work.then((_) async {
      if (!_disposed) await activity.sync(state);
    }).catchError((Object error) {
      _lastState = null;
      debugPrint('Não foi possível atualizar a Live Activity: $error');
    });
  }

  void _handleAction(String action, String sessionId) {
    if (_disposed) return;
    if (engine.loading || engine.loadFailed) {
      _pendingAction = (action, sessionId);
      return;
    }
    if (engine.sessionId != sessionId) return;
    engine.tick();
    if (engine.sessionId != sessionId) return;
    if (action == 'pause') engine.pause();
    if (action == 'resume' && !engine.running) engine.start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      engine.tick();
      _sync(force: true);
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    engine.removeListener(_sync);
    WidgetsBinding.instance.removeObserver(this);
    // Leave the native countdown available if the process closes.
    activity.dispose();
  }
}
