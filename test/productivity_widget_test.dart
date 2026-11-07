import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doro_list/controllers/activity_journal.dart';
import 'package:doro_list/controllers/task_controller.dart';
import 'package:doro_list/controllers/pomodoro_controller.dart';
import 'package:doro_list/models/task.dart';
import 'package:doro_list/models/activity.dart';
import 'package:doro_list/pages/home_page.dart';
import 'package:doro_list/pages/summary_page.dart';
import 'package:doro_list/components/navigation_bottom_bar.dart';
import 'package:doro_list/services/task_backup.dart';
import 'package:doro_list/theme/app_theme.dart';
import 'support/memory_productivity.dart';
import 'support/memory_pomodoro_storage.dart';

class _Backup extends TaskBackup {
  List<Task>? imported;
  List<Task>? exported;
  @override
  Future<List<Task>?> pickImport() async => imported;
  @override
  Future<bool> export(List<Task> tasks) async {
    exported = List.of(tasks);
    return true;
  }
}

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('Task heading and compact timer work on $platform',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var now = DateTime.now();
      final journal = ActivityJournal(storage: MemoryJson());
      final tasks = TaskController(storage: MemoryTasks(), journal: journal);
      final timer = PomodoroController(
          settingsStorage: MemoryPomodoroStorage(),
          journal: journal,
          tasks: tasks,
          now: () => now);
      addTearDown(timer.dispose);
      addTearDown(tasks.dispose);
      addTearDown(journal.dispose);
      await tasks.load();
      await timer.load();
      await tasks.add('Preparar apresentação');
      var openedFocus = false;
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.lightTheme.copyWith(platform: platform),
          home: MyHomePage(
              controller: tasks,
              pomodoro: timer,
              onOpenFocus: () => openedFocus = true)));
      await tester.pumpAndSettle();
      expect(find.text('1 tarefa pendente'), findsOneWidget);
      expect(find.text('Tarefas'), findsOneWidget);
      expect(find.text('Hoje'), findsNothing);
      expect(find.text('0 min de foco'), findsNothing);
      expect(find.byKey(const ValueKey('active-focus-strip')), findsNothing);
      timer.selectTask(tasks.tasks.single);
      timer.start();
      await tester.pump();
      now = now.add(const Duration(seconds: 12));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('24:48'), findsOneWidget);
      await tester.tap(find.byTooltip('Pausar foco'));
      await tester.pump();
      expect(find.text('Pomodoro em pausa'), findsOneWidget);
      await tester.tap(find.text('24:48'));
      expect(openedFocus, isTrue);
      await tester.tap(find.byTooltip('Continuar foco'));
      await tester.pump();
      expect(timer.running, isTrue);
      timer.reset();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('active-focus-strip')), findsNothing);
      await tasks.toggle(tasks.tasks.single.id, true);
      await tester.pumpAndSettle();
      expect(find.text('0 tarefas pendentes'), findsOneWidget);
      expect(find.text('1 concluída hoje'), findsNothing);
      // The header scrolls with the list, leaving room for the keyboard.
      tester.view.physicalSize = const Size(320, 568);
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'filters, drag ordering and the focus action use the selected task',
      (tester) async {
    final storage = MemoryTasks()
      ..values = [
        const Task(id: 'a', title: 'Primeira'),
        const Task(id: 'b', title: 'Segunda'),
        const Task(id: 'c', title: 'Terceira'),
        const Task(id: 'd', title: 'Feita', completed: true),
      ];
    final tasks = TaskController(storage: storage);
    addTearDown(tasks.dispose);
    await tasks.load();
    Task? selected;
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: MyHomePage(
            controller: tasks, onFocusTask: (task) => selected = task)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Concluídas'));
    await tester.pumpAndSettle();
    expect(find.text('Feita'), findsOneWidget);
    expect(find.text('Primeira'), findsNothing);
    await tester.tap(find.text('Pendentes'));
    await tester.pumpAndSettle();
    expect(find.text('Feita'), findsNothing);
    final handle = find.byKey(const ValueKey('reorder-a'));
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 20));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 130));
    await tester.pump(const Duration(milliseconds: 500));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tasks.pending.map((task) => task.id), ['b', 'a', 'c']);
    expect(storage.values.map((task) => task.id), ['b', 'a', 'c', 'd']);
    await tester.tap(find.byTooltip('Focar em Segunda'));
    expect(selected!.id, 'b');
  });

  testWidgets(
      'import requires confirmation, merges tasks and export includes current order',
      (tester) async {
    final tasks = TaskController(
        storage: MemoryTasks()
          ..values = [const Task(id: 'a', title: 'Original')]);
    addTearDown(tasks.dispose);
    await tasks.load();
    final backup = _Backup()
      ..imported = [
        const Task(id: 'a', title: 'Alterada'),
        const Task(id: 'b', title: 'Importada')
      ];
    await tester.pumpWidget(
        MaterialApp(home: MyHomePage(controller: tasks, backup: backup)));
    await tester.pumpAndSettle();
    Future<void> option(String label) async {
      await tester.tap(find.byTooltip('Mais opções'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    await option('Importar tarefas');
    expect(find.text('Importar tarefas?'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(tasks.tasks, hasLength(1));
    await option('Importar tarefas');
    await tester.tap(find.text('Importar'));
    await tester.pumpAndSettle();
    expect(tasks.tasks.map((task) => task.title), ['Original', 'Importada']);
    await option('Exportar tarefas');
    expect(backup.exported!.map((task) => task.id), ['a', 'b']);
  });

  testWidgets(
      'summary shows daily metrics and clearing completed tasks preserves them',
      (tester) async {
    final today = DateTime.now();
    final journal = ActivityJournal(storage: MemoryJson());
    final tasks = TaskController(storage: MemoryTasks(), journal: journal);
    addTearDown(tasks.dispose);
    addTearDown(journal.dispose);
    await tasks.load();
    await tasks.add('Concluir');
    final id = tasks.tasks.single.id;
    await tasks.toggle(id, true);
    journal.recordFocus(FocusRecord(
        id: 'focus', endedAt: today, seconds: 1500, taskTitle: 'Concluir'));
    await journal.persist();
    await tester.pumpWidget(MaterialApp(
        home: NavigationBottomBar(pages: [
      MyHomePage(controller: tasks),
      const SizedBox(),
      SummaryPage(journal: journal),
    ])));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Resumo do dia'), findsNothing);
    await tester.tap(find.text('Resumo'));
    await tester.pumpAndSettle();
    expect(find.text('1 tarefa concluída'), findsOneWidget);
    expect(find.text('25 min de foco'), findsOneWidget);
    expect(find.text('1 sessão de foco concluída'), findsOneWidget);
    expect(find.text('25 min'), findsOneWidget);
    await tester.tap(find.text('Tarefas').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Mais opções'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Limpar concluídas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(tasks.tasks, hasLength(1));
    await tester.tap(find.byTooltip('Mais opções'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Limpar concluídas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Limpar'));
    await tester.pumpAndSettle();
    expect(tasks.tasks, isEmpty);
    expect(journal.tasksOn(today), 1);
    expect(journal.secondsOn(today), 1500);
  });
  testWidgets('iOS filters and backup confirmation use Cupertino controls',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final tasks = TaskController(
        storage: MemoryTasks()
          ..values = [
            const Task(id: 'a', title: 'Pendente'),
            const Task(id: 'b', title: 'Feita', completed: true),
          ]);
    addTearDown(tasks.dispose);
    await tasks.load();
    final backup = _Backup()..imported = [const Task(id: 'c', title: 'Nova')];
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme.copyWith(platform: TargetPlatform.iOS),
        home: MyHomePage(controller: tasks, backup: backup)));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoSlidingSegmentedControl<TaskFilter>),
        findsOneWidget);
    await tester.tap(find.text('Concluídas'));
    await tester.pumpAndSettle();
    expect(find.text('Pendente'), findsNothing);
    expect(find.text('Feita'), findsOneWidget);
    await tester.tap(find.byTooltip('Mais opções'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Importar tarefas'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    await tester.tap(find.text('Importar'));
    await tester.pumpAndSettle();
    expect(tasks.tasks.map((task) => task.id), ['a', 'c', 'b']);
  });
}
