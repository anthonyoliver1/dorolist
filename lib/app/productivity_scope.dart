import 'dart:async';

import 'package:flutter/foundation.dart';

import '../repositories/activity_journal.dart';
import '../services/session_alerts.dart';
import '../services/session_live_activity.dart';
import '../view_models/pomodoro_live_activity_coordinator.dart';
import '../view_models/pomodoro_view_model.dart';
import '../view_models/summary_view_model.dart';
import '../view_models/tasks_view_model.dart';

/// Owns the shared dependencies for the three productivity tabs.
class ProductivityScope {
  ProductivityScope({
    required VoidCallback onOpenFocus,
    required VoidCallback onOpenFocusFromLiveActivity,
  }) {
    tasks = TasksViewModel(journal: _journal);
    pomodoro = PomodoroViewModel(
      journal: _journal,
      tasks: tasks,
      alerts: NativeSessionAlerts(onOpenFocus: onOpenFocus),
    );
    summary = SummaryViewModel(_journal);
    _liveActivity = PomodoroLiveActivityCoordinator(
      engine: pomodoro,
      activity: NativeSessionLiveActivity(),
      onOpenFocus: onOpenFocusFromLiveActivity,
    );
    unawaited(_liveActivity.initialize());
    unawaited(tasks.load());
    unawaited(pomodoro.load());
  }

  final _journal = ActivityJournal();
  late final TasksViewModel tasks;
  late final PomodoroViewModel pomodoro;
  late final SummaryViewModel summary;
  late final PomodoroLiveActivityCoordinator _liveActivity;

  void dispose() {
    _liveActivity.dispose();
    pomodoro.dispose();
    tasks.dispose();
    _journal.dispose();
  }
}
