import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doro_list/controllers/activity_journal.dart';
import 'package:doro_list/controllers/pomodoro_controller.dart';
import 'package:doro_list/controllers/task_controller.dart';
import 'package:doro_list/models/task.dart';
import 'package:doro_list/services/session_live_activity.dart';
import 'package:doro_list/view_models/pomodoro_live_activity_coordinator.dart';
import 'support/memory_pomodoro_storage.dart';
import 'support/memory_productivity.dart';

Future<void> flushActivity() => Future<void>.delayed(Duration.zero);

class _Activity extends SessionLiveActivity {
  final states = <Map<String, Object?>?>[];
  VoidCallback? openFocus;
  TimerNotificationAction? onAction;
  bool disposed = false;
  bool fail = false;
  @override
  Future<void> initialize(VoidCallback callback,
      {TimerNotificationAction? onAction}) async {
    openFocus = callback;
    this.onAction = onAction;
  }

  @override
  Future<void> sync(Map<String, Object?>? state) async {
    if (fail) throw Exception('ActivityKit unavailable');
    states.add(state);
  }

  @override
  void dispose() {
    disposed = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DateTime now;
  late ActivityJournal journal;
  late TaskController tasks;
  late PomodoroController engine;
  late _Activity activity;
  late PomodoroLiveActivityCoordinator coordinator;
  var opened = false;

  setUp(() async {
    now = DateTime(2026, 11, 6, 10);
    opened = false;
    journal = ActivityJournal(storage: MemoryJson());
    tasks = TaskController(
        storage: MemoryTasks()
          ..values = [const Task(id: 'a', title: 'Estudar')],
        journal: journal);
    await tasks.load();
    engine = PomodoroController(
        journal: journal,
        tasks: tasks,
        settingsStorage: MemoryPomodoroStorage(),
        now: () => now);
    await engine.load();
    activity = _Activity();
    coordinator = PomodoroLiveActivityCoordinator(
        engine: engine, activity: activity, onOpenFocus: () => opened = true);
    await coordinator.initialize();
    await flushActivity();
  });
  tearDown(() {
    coordinator.dispose();
    engine.dispose();
    tasks.dispose();
    journal.dispose();
  });

  test(
      'syncs session changes, not countdown ticks; pause and resume retain timing',
      () async {
    expect(activity.states, [null]);
    engine.selectTask(tasks.pending.single);
    engine.start();
    await flushActivity();
    final started = activity.states.last!;
    expect(started['taskTitle'], 'Estudar');
    expect(started['remainingSeconds'], isNull);
    final count = activity.states.length;
    now = now.add(const Duration(seconds: 12));
    engine.tick();
    await flushActivity();
    expect(activity.states, hasLength(count));
    engine.pause();
    await flushActivity();
    expect(activity.states.last!['deadline'], isNull);
    expect(activity.states.last!['remainingSeconds'], 1488);
    now = now.add(const Duration(minutes: 1));
    engine.start();
    await flushActivity();
    expect(activity.states.last!['sessionId'], started['sessionId']);
    expect(activity.states.last!['deadline'],
        now.add(const Duration(seconds: 1488)).millisecondsSinceEpoch);
    engine.reset();
    await flushActivity();
    expect(activity.states.last, isNull);
  });

  test('unlinking task updates the activity and finishing ends it', () async {
    engine.selectTask(tasks.pending.single);
    engine.start();
    await flushActivity();
    final deadline = activity.states.last!['deadline'];
    await tasks.toggle('a', true);
    await flushActivity();
    expect(activity.states.last!['taskTitle'], isNull);
    expect(activity.states.last!['deadline'], deadline);
    now = engine.deadline!;
    engine.tick();
    await flushActivity();
    expect(activity.states.last, isNull);
  });

  test(
      'activity taps open focus and lifecycle sync recovers after a native error',
      () async {
    activity.openFocus!();
    expect(opened, isTrue);
    activity.fail = true;
    engine.start();
    await flushActivity();
    expect(engine.running, isTrue);
    activity.fail = false;
    coordinator.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await flushActivity();
    expect(activity.states.last!['sessionId'], engine.sessionId);
  });

  test('notification actions pause and resume only the matching session',
      () async {
    engine.start();
    await flushActivity();
    final id = engine.sessionId!;
    now = now.add(const Duration(seconds: 20));
    activity.onAction!('pause', id);
    await flushActivity();
    expect(engine.running, isFalse);
    expect(engine.remainingSeconds, 1480);
    activity.onAction!('pause', id);
    now = now.add(const Duration(minutes: 1));
    activity.onAction!('resume', 'old-session');
    expect(engine.running, isFalse);
    activity.onAction!('resume', id);
    await flushActivity();
    expect(engine.running, isTrue);
    expect(engine.sessionId, id);
    expect(engine.deadline, now.add(const Duration(seconds: 1480)));
    final deadline = engine.deadline;
    activity.onAction!('resume', id);
    expect(engine.deadline, deadline);
  });

  test('cold notification action waits for session recovery before pausing',
      () async {
    engine.start();
    await engine.persist();
    final id = engine.sessionId!;
    engine.loading = true;
    activity.onAction!('pause', id);
    expect(engine.running, isTrue);
    await engine.load();
    await flushActivity();
    expect(engine.sessionId, id);
    expect(engine.running, isFalse);
    expect(engine.stopped, isTrue);
    expect(activity.states.last!['deadline'], isNull);
  });

  test('an expired notification cannot start the next stage', () async {
    engine.start();
    final id = engine.sessionId!;
    now = engine.deadline!;
    activity.onAction!('resume', id);
    await flushActivity();
    expect(engine.running, isFalse);
    expect(engine.phaseLabel, 'Pausa curta');
    expect(engine.sessionId, isNull);
    expect(activity.states.last, isNull);
  });

  test('disposing leaves the OS countdown active and removes listeners',
      () async {
    engine.start();
    await flushActivity();
    final count = activity.states.length;
    coordinator.dispose();
    engine.pause();
    await flushActivity();
    expect(activity.disposed, isTrue);
    expect(activity.states, hasLength(count));
    expect(activity.states.last, isNotNull);
  });
}
