import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doro_list/controllers/activity_journal.dart';
import 'package:doro_list/controllers/pomodoro_controller.dart';
import 'package:doro_list/controllers/task_controller.dart';
import 'package:doro_list/models/activity.dart';
import 'package:doro_list/models/pomodoro_settings.dart';
import 'package:doro_list/models/task.dart';
import 'package:doro_list/models/timer_snapshot.dart';
import 'package:doro_list/services/task_backup.dart';
import 'support/memory_pomodoro_storage.dart';
import 'support/memory_productivity.dart';

Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final remove in [false, true]) {
    for (final state in ['ready', 'running', 'paused']) {
      test(
          '${remove ? 'removing' : 'completing'} a linked task detaches it while $state',
          () async {
        var now = DateTime(2026, 11, 6, 10);
        final disk = MemoryJson();
        final journal = ActivityJournal(storage: disk);
        final storage = MemoryTasks()
          ..values = [const Task(id: 'a', title: 'Estudar')];
        final tasks = TaskController(storage: storage, journal: journal);
        final alerts = RecordingAlerts();
        final engine = PomodoroController(
            journal: journal,
            tasks: tasks,
            alerts: alerts,
            settingsStorage: MemoryPomodoroStorage(),
            now: () => now);
        addTearDown(engine.dispose);
        addTearDown(tasks.dispose);
        addTearDown(journal.dispose);
        await tasks.load();
        await engine.load();
        engine.selectTask(tasks.pending.single);
        journal.recordFocus(FocusRecord(
            id: 'previous',
            endedAt: now,
            seconds: 1500,
            taskId: 'a',
            taskTitle: 'Estudar'));
        if (state != 'ready') {
          engine.start();
          now = now.add(const Duration(minutes: 2));
          engine.tick();
          if (state == 'paused') engine.pause();
        }
        await flush();
        final before = engine.snapshot;
        final original = tasks.tasks.single;
        if (remove) {
          await tasks.remove('a');
        } else {
          await tasks.toggle('a', true);
        }
        await flush();
        expect(engine.taskId, isNull);
        expect(engine.taskTitle, isNull);
        expect(engine.running, state == 'running');
        expect(engine.remainingSeconds, before.remainingSeconds);
        expect(engine.deadline, before.deadline);
        expect(engine.sessionId, before.sessionId);
        expect(disk.data!['timer']['taskId'], isNull);
        expect(disk.data!['timer']['taskTitle'], isNull);
        expect(journal.sessions.single.taskTitle, 'Estudar');
        if (state == 'running') {
          expect(alerts.lastBody, 'Hora de descansar.');
          expect(alerts.lastDeadline, before.deadline);
        }
        if (remove) {
          await tasks.restore(original, 0);
        } else {
          await tasks.toggle('a', false);
        }
        expect(engine.taskId, isNull);
        if (state == 'running') {
          now = before.deadline!;
          engine.tick();
          await engine.persist();
          expect(journal.sessions.last.taskId, isNull);
          expect(journal.sessions.last.taskTitle, isNull);
        }
      });
    }
  }

  test('restored task links wait for tasks to load before validating',
      () async {
    final journal = ActivityJournal(storage: MemoryJson());
    await journal.load();
    journal.timer = const TimerSnapshot(
        phase: TimeType.pomodoro,
        totalSeconds: 1500,
        remainingSeconds: 1500,
        completedSessions: 0,
        taskId: 'a',
        taskTitle: 'Estudar');
    final tasks = TaskController(
        storage: MemoryTasks()
          ..values = [const Task(id: 'a', title: 'Estudar')],
        journal: journal);
    final engine = PomodoroController(
        journal: journal,
        tasks: tasks,
        settingsStorage: MemoryPomodoroStorage());
    addTearDown(engine.dispose);
    addTearDown(tasks.dispose);
    addTearDown(journal.dispose);
    await engine.load();
    expect(engine.taskId, 'a');
    await tasks.load();
    expect(engine.taskId, 'a');
    await tasks.remove('a');
    expect(engine.taskId, isNull);
  });

  test('lifecycle changes preserve the saved timer until recovery succeeds',
      () async {
    final now = DateTime(2026, 11, 6, 10);
    final disk = MemoryJson();
    final journal = ActivityJournal(storage: disk);
    addTearDown(journal.dispose);
    await journal.load();
    journal.timer = TimerSnapshot(
        phase: TimeType.pomodoro,
        totalSeconds: 3000,
        remainingSeconds: 2400,
        completedSessions: 2,
        sessionId: 'saved',
        taskId: 'task',
        taskTitle: 'Estudar',
        startedAt: now.subtract(const Duration(minutes: 10)),
        deadline: now.add(const Duration(minutes: 40)));
    await journal.persist();
    final saved = jsonEncode(disk.data);
    final settings = MemoryPomodoroStorage()..failRead = true;
    final engine = PomodoroController(
        journal: journal, settingsStorage: settings, now: () => now);
    addTearDown(engine.dispose);

    Future<void> background() async {
      engine.didChangeAppLifecycleState(AppLifecycleState.inactive);
      engine.didChangeAppLifecycleState(AppLifecycleState.paused);
      await flush();
    }

    await background();
    expect(jsonEncode(disk.data), saved);
    await engine.load();
    expect(engine.loadFailed, isTrue);
    await background();
    expect(jsonEncode(disk.data), saved);
    expect(engine.error, isNull);

    settings.failRead = false;
    await engine.load();
    expect(engine.running, isTrue);
    expect(engine.sessionId, 'saved');
    expect(engine.timeText, '40:00');
    engine.pause();
    await background();
    final recovered = ActivityJournal(storage: disk);
    addTearDown(recovered.dispose);
    await recovered.load();
    expect(recovered.timer!.sessionId, 'saved');
    expect(recovered.timer!.taskId, 'task');
    expect(recovered.timer!.remainingSeconds, 2400);
    expect(recovered.timer!.deadline, isNull);
    expect(recovered.timer!.stopped, isTrue);
  });

  for (final phase in TimeType.values) {
    test('restoring expired ${phase.name} cancels its pending alert', () async {
      final now = DateTime(2026, 11, 6, 10);
      final journal = ActivityJournal(storage: MemoryJson());
      addTearDown(journal.dispose);
      await journal.load();
      journal.timer = TimerSnapshot(
          phase: phase,
          totalSeconds: 1500,
          remainingSeconds: 1500,
          completedSessions: 0,
          sessionId: 'expired',
          startedAt: now.subtract(const Duration(minutes: 30)),
          deadline: now.subtract(const Duration(minutes: 5)));
      final alerts = RecordingAlerts();
      final settings = MemoryPomodoroStorage()
        ..settings = const PomodoroSettings(autoStart: true);
      final engine = PomodoroController(
          journal: journal,
          settingsStorage: settings,
          alerts: alerts,
          now: () => now);
      addTearDown(engine.dispose);
      await engine.load();
      await flush();
      expect(alerts.cancelled, ['expired']);
      expect(alerts.finished, isEmpty);
      expect(alerts.scheduled, isEmpty);
      expect(engine.running, isFalse);
    });
  }

  test('restores an active timer from its deadline after the app closes',
      () async {
    var now = DateTime(2026, 11, 5, 10);
    final disk = MemoryJson();
    final first = PomodoroController(
        journal: ActivityJournal(storage: disk),
        settingsStorage: MemoryPomodoroStorage(),
        now: () => now);
    await first.load();
    first.start();
    await first.persist();
    first.dispose();
    now = now.add(const Duration(minutes: 10));
    final restored = PomodoroController(
        journal: ActivityJournal(storage: disk),
        settingsStorage: MemoryPomodoroStorage(),
        now: () => now);
    addTearDown(restored.dispose);
    await restored.load();
    expect(restored.running, isTrue);
    expect(restored.timeText, '15:00');
    expect(restored.deadline!.isAtSameMomentAs(DateTime(2026, 11, 5, 10, 25)),
        isTrue);
  });

  test(
      'restored expired focus counts once on the deadline day and prepares a pause',
      () async {
    var now = DateTime(2026, 11, 5, 23, 50);
    final disk = MemoryJson();
    final first = PomodoroController(
        journal: ActivityJournal(storage: disk),
        settingsStorage: MemoryPomodoroStorage(),
        now: () => now);
    await first.load();
    first.selectTask(const Task(id: 'task', title: 'Estudar'));
    first.start();
    await first.persist();
    first.dispose();
    now = DateTime(2026, 11, 6, 9);
    final journal = ActivityJournal(storage: disk);
    final restored = PomodoroController(
        journal: journal,
        settingsStorage: MemoryPomodoroStorage(),
        now: () => now);
    await restored.load();
    await restored.persist();
    expect(restored.phase, TimeType.short);
    expect(restored.running, isFalse);
    expect(journal.sessionsOn(now), hasLength(1));
    expect(journal.secondsOn(now), 1500);
    expect(journal.sessions.single.taskTitle, 'Estudar');
    expect(journal.sessions.single.endedAt.toLocal().hour, 0);
    restored.dispose();
    final replay = ActivityJournal(storage: disk);
    final third = PomodoroController(
        journal: replay,
        settingsStorage: MemoryPomodoroStorage(),
        now: () => now);
    addTearDown(third.dispose);
    await third.load();
    third.tick();
    expect(replay.sessions, hasLength(1));
    expect(third.completedSessions, 1);
  });

  test(
      'paused timers restore remaining time without consuming the closed interval',
      () async {
    var now = DateTime(2026, 11, 5, 10);
    final disk = MemoryJson();
    final first = PomodoroController(
        journal: ActivityJournal(storage: disk),
        settingsStorage: MemoryPomodoroStorage(),
        now: () => now);
    await first.load();
    first.start();
    now = now.add(const Duration(minutes: 5));
    first.pause();
    await first.persist();
    first.dispose();
    now = now.add(const Duration(hours: 2));
    final restored = PomodoroController(
        journal: ActivityJournal(storage: disk),
        settingsStorage: MemoryPomodoroStorage(),
        now: () => now);
    addTearDown(restored.dispose);
    await restored.load();
    expect(restored.timeText, '20:00');
    expect(restored.stopped, isTrue);
    restored.start();
    expect(restored.deadline, now.add(const Duration(minutes: 20)));
  });

  test(
      'start schedules an alert, pause cancels it, resume reschedules and reset cancels',
      () async {
    var now = DateTime(2026, 11, 5, 10);
    final alerts = RecordingAlerts();
    final engine = PomodoroController(
        settingsStorage: MemoryPomodoroStorage(),
        alerts: alerts,
        now: () => now);
    addTearDown(engine.dispose);
    await engine.load();
    engine.start();
    await flush();
    final id = engine.sessionId!;
    expect(alerts.scheduled, [id]);
    now = now.add(const Duration(minutes: 1));
    engine.pause();
    await flush();
    expect(alerts.cancelled, [id]);
    now = now.add(const Duration(minutes: 5));
    engine.start();
    await flush();
    expect(alerts.scheduled, [id, id]);
    expect(alerts.lastDeadline, now.add(const Duration(minutes: 24)));
    engine.reset();
    await flush();
    expect(alerts.cancelled, [id, id]);
    expect(engine.running, isFalse);
  });

  test(
      'task focus and task completion update daily metrics and clearing keeps history',
      () async {
    var now = DateTime(2026, 11, 5, 10);
    final journal = ActivityJournal(storage: MemoryJson());
    final storage = MemoryTasks()
      ..values = [const Task(id: 'a', title: 'Estudar')];
    final tasks =
        TaskController(storage: storage, journal: journal, now: () => now);
    addTearDown(tasks.dispose);
    await tasks.load();
    final alerts = RecordingAlerts();
    final settings = MemoryPomodoroStorage()
      ..settings = const PomodoroSettings(focusMinutes: 1);
    final engine = PomodoroController(
        journal: journal,
        tasks: tasks,
        settingsStorage: settings,
        alerts: alerts,
        now: () => now);
    addTearDown(engine.dispose);
    await engine.load();
    engine.selectTask(tasks.pending.single);
    engine.start();
    await flush();
    expect(engine.selectTask(null), isFalse);
    now = now.add(const Duration(minutes: 1));
    engine.tick();
    await engine.persist();
    await flush();
    expect(journal.sessions.single.taskId, 'a');
    expect(journal.secondsOn(now), 60);
    expect(alerts.finished, hasLength(1));
    await tasks.toggle('a', true);
    expect(journal.tasksOn(now), 1);
    await tasks.toggle('a', false);
    expect(journal.tasksOn(now), 0);
    await tasks.toggle('a', true);
    await tasks.clearCompleted();
    expect(tasks.tasks, isEmpty);
    expect(journal.tasksOn(now), 1);
    expect(journal.sessionsOn(now), hasLength(1));
  });

  test(
      'filters and manual order persist and imported IDs do not replace existing tasks',
      () async {
    final storage = MemoryTasks()
      ..values = [
        const Task(id: 'a', title: 'A'),
        const Task(id: 'b', title: 'B'),
        const Task(id: 'c', title: 'C'),
        const Task(id: 'd', title: 'D', completed: true),
      ];
    final tasks = TaskController(storage: storage);
    addTearDown(tasks.dispose);
    await tasks.load();
    await tasks.reorder(TaskFilter.pending, 0, 2);
    expect(storage.values.map((task) => task.id), ['b', 'c', 'a', 'd']);
    expect(tasks.filtered(TaskFilter.completed).single.id, 'd');
    final count = await tasks.importTasks([
      const Task(id: 'a', title: 'Wrong replacement'),
      const Task(id: 'e', title: 'E')
    ]);
    expect(count, 1);
    expect(tasks.tasks.firstWhere((task) => task.id == 'a').title, 'A');
    expect(await tasks.importTasks([const Task(id: 'e', title: 'E')]), 0);
  });

  test(
      'backups round trip metadata and reject invalid schemas, duplicates and oversized content',
      () {
    final backup = TaskBackup();
    final task = Task(
        id: 'a',
        title: 'Teste',
        completed: true,
        completedAt: DateTime.utc(2026, 11, 5));
    final encoded = backup.encode([task], DateTime.utc(2026));
    expect(backup.decode(encoded).single.toJson(), task.toJson());
    expect(
        () =>
            backup.decode(utf8.encode('{"app":"other","schema":1,"tasks":[]}')),
        throwsFormatException);
    expect(() => backup.decode(utf8.encode('[{"title":"","ok":false}]')),
        throwsFormatException);
    expect(() => backup.decode(backup.encode([task, task], DateTime.utc(2026))),
        throwsFormatException);
    expect(() => backup.decode(List.filled(TaskBackup.maxBytes + 1, 32)),
        throwsFormatException);
  });

  test('corrupt journal is never overwritten and save failures can be retried',
      () async {
    final disk = MemoryJson()..data = {'schema': 999};
    final journal = ActivityJournal(storage: disk);
    await expectLater(journal.load(), throwsFormatException);
    await expectLater(journal.persist(), throwsStateError);
    expect(disk.writes, 0);
    disk.data = null;
    await journal.load();
    final engine = PomodoroController(
        journal: journal, settingsStorage: MemoryPomodoroStorage());
    addTearDown(engine.dispose);
    await engine.load();
    disk.failSave = true;
    engine.start();
    await flush();
    expect(engine.error, isNotNull);
    disk.failSave = false;
    await engine.retrySave();
    expect(engine.error, isNull);
    expect(disk.data!['timer']['deadline'], isNotNull);
  });

  test('day summaries use local dates and completed focus only', () async {
    final journal = ActivityJournal(storage: MemoryJson());
    await journal.load();
    final today = DateTime(2026, 11, 5, 10);
    journal.recordFocus(FocusRecord(id: 'a', endedAt: today, seconds: 1500));
    journal.recordFocus(FocusRecord(id: 'a', endedAt: today, seconds: 1500));
    journal.recordFocus(FocusRecord(
        id: 'b',
        endedAt: today.subtract(const Duration(days: 1)),
        seconds: 1500));
    expect(journal.sessionsOn(today), hasLength(1));
    expect(journal.secondsOn(today), 1500);
    expect(dayKey(today), '2026-11-05');
  });
}
