import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doro_list/models/pomodoro_settings.dart';
import 'package:doro_list/services/pomodoro_settings_storage.dart';
import 'package:doro_list/pages/time_page.dart';
import 'support/memory_pomodoro_storage.dart';

void main() {
  test('settings defaults, round trip and invalid data preservation', () async {
    final directory = await Directory.systemTemp.createTemp('pomodoro_test_');
    addTearDown(() => directory.delete(recursive: true));
    final storage = PomodoroSettingsStorage(directory: () async => directory);
    expect((await storage.read()).focusMinutes, 25);
    const settings = PomodoroSettings(
        focusMinutes: 50,
        shortBreakMinutes: 10,
        longBreakMinutes: 30,
        sessionsBeforeLongBreak: 30,
        autoStart: true);
    await storage.save(settings);
    expect((await storage.read()).toJson(), settings.toJson());
    final file = File('${directory.path}/pomodoro_settings.json');
    await file.writeAsString('{"focusMinutes":0}');
    await expectLater(storage.read(), throwsFormatException);
    expect(await file.readAsString(), '{"focusMinutes":0}');
  });

  testWidgets('focus cycles prepare short and long breaks without starting',
      (tester) async {
    var now = DateTime(2026);
    final storage = MemoryPomodoroStorage()
      ..settings = const PomodoroSettings(
          focusMinutes: 1,
          shortBreakMinutes: 2,
          longBreakMinutes: 3,
          sessionsBeforeLongBreak: 2);
    await tester.pumpWidget(
        MaterialApp(home: TimePage(now: () => now, settingsStorage: storage)));
    await tester.pumpAndSettle();
    expect(find.text('01:00'), findsOneWidget);
    Future<void> finish(int minutes) async {
      await tester.tap(find.text('Iniciar'));
      now = now.add(Duration(minutes: minutes));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
    }

    await finish(1);
    expect(find.text('02:00'), findsOneWidget);
    expect(find.text('Sessões de foco: 1 de 2'), findsOneWidget);
    expect(find.text('Iniciar'), findsOneWidget);
    // An idle break must not consume time or create additional completed sessions.
    now = now.add(const Duration(minutes: 10));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('02:00'), findsOneWidget);
    await finish(2);
    expect(find.text('01:00'), findsOneWidget);
    await finish(1);
    expect(find.text('03:00'), findsOneWidget);
    expect(find.text('Sessões de foco: 2 de 2'), findsOneWidget);
    await finish(3);
    expect(find.text('01:00'), findsOneWidget);
    expect(find.text('Sessões de foco: 0 de 2'), findsOneWidget);
  });

  testWidgets('automatic progression starts next stage only when enabled',
      (tester) async {
    var now = DateTime(2026);
    final storage = MemoryPomodoroStorage()
      ..settings = const PomodoroSettings(
          focusMinutes: 1, shortBreakMinutes: 2, autoStart: true);
    await tester.pumpWidget(
        MaterialApp(home: TimePage(now: () => now, settingsStorage: storage)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Iniciar'));
    now = now.add(const Duration(minutes: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('02:00'), findsOneWidget);
    expect(find.text('Parar'), findsOneWidget);
    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('01:59'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'selectors offer five-minute steps and 30 sessions and persist changes',
      (tester) async {
    final storage = MemoryPomodoroStorage();
    Future<void> openPage() async {
      await tester
          .pumpWidget(MaterialApp(home: TimePage(settingsStorage: storage)));
      await tester.pumpAndSettle();
    }

    await openPage();
    await tester.tap(find.byTooltip('Configurar Pomodoro'));
    await tester.pumpAndSettle();
    final focus = find.byType(DropdownButtonFormField<int>).at(0);
    final sessions = find.byType(DropdownButtonFormField<int>).at(3);
    final save = find.text('Salvar configurações');
    final durationFields = tester
        .widgetList<DropdownButton<int>>(find.byType(DropdownButton<int>))
        .take(3);
    for (final field in durationFields) {
      final values = field.items!.map((item) => item.value!).toList();
      expect(values.first, 5);
      expect(values.every((value) => value % 5 == 0), isTrue);
    }
    final sessionField = tester
        .widget<DropdownButton<int>>(find.byType(DropdownButton<int>).at(3));
    expect(sessionField.items!.first.value, 1);
    expect(sessionField.items!.last.value, 30);
    await tester.tap(focus);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('50 min'), 100,
        scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('50 min').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('50 min').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(sessions);
    await tester.tap(sessions);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('30 sessões'), 200,
        scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('30 sessões').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('30 sessões').last);
    await tester.pumpAndSettle();
    storage.failSave = true;
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(
        find.text('Não foi possível salvar. Tente novamente.'), findsOneWidget);
    expect(storage.settings.focusMinutes, 25);
    storage.failSave = false;
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('50:00'), findsOneWidget);
    expect(find.text('Sessões de foco: 0 de 30'), findsOneWidget);
    expect(storage.settings.sessionsBeforeLongBreak, 30);
    expect(storage.settings.autoStart, isFalse);
    await tester.pumpWidget(const SizedBox());
    await openPage();
    expect(find.text('50:00'), findsOneWidget);
  });

  testWidgets('failed load can be retried without overwriting preferences',
      (tester) async {
    final storage = MemoryPomodoroStorage()..failRead = true;
    await tester
        .pumpWidget(MaterialApp(home: TimePage(settingsStorage: storage)));
    await tester.pumpAndSettle();
    expect(find.text('Não foi possível carregar as configurações.'),
        findsOneWidget);
    expect(find.text('Iniciar'), findsNothing);
    storage.failRead = false;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('25:00'), findsOneWidget);
  });
}
