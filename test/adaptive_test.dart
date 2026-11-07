import 'package:doro_list/controllers/activity_journal.dart';
import 'package:doro_list/pages/summary_page.dart';
import 'support/memory_productivity.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:doro_list/components/adaptive.dart';
import 'package:doro_list/components/navigation_bottom_bar.dart';
import 'package:doro_list/pages/home_page.dart';
import 'package:doro_list/pages/time_page.dart';
import 'package:doro_list/models/task.dart';
import 'package:doro_list/services/task_storage.dart';
import 'package:doro_list/theme/app_theme.dart';
import 'support/memory_pomodoro_storage.dart';

class _MemoryTasks extends TaskStorage {
  List<Task> tasks = [];
  @override
  Future<List<Task>> read() async => List.of(tasks);
  @override
  Future<void> save(List<Task> value) async {
    tasks = List.of(value);
  }
}

Widget _app(Widget home, TargetPlatform platform, {bool dark = false}) =>
    MaterialApp(
      theme: (dark ? AppTheme.darkTheme : AppTheme.lightTheme)
          .copyWith(platform: platform),
      home: home,
    );

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('tab content stays above system navigation on $platform',
        (tester) async {
      _phone(tester);
      tester.view.viewPadding = const FakeViewPadding(bottom: 34);
      tester.view.padding = const FakeViewPadding(bottom: 34);
      addTearDown(tester.view.resetViewPadding);
      addTearDown(tester.view.resetPadding);
      await tester.pumpWidget(_app(
          NavigationBottomBar(pages: const [
            SizedBox(),
            SizedBox(),
            SizedBox(),
          ]),
          platform));
      await tester.pumpAndSettle();
      final safeBottom = tester.view.physicalSize.height - 34;
      for (final label in ['Tarefas', 'Foco', 'Resumo']) {
        expect(tester.getBottomLeft(find.text(label)).dy,
            lessThanOrEqualTo(safeBottom));
      }
      final icon = find.byIcon(platform == TargetPlatform.iOS
          ? CupertinoIcons.checkmark_square_fill
          : Icons.fact_check);
      expect(tester.getBottomLeft(icon).dy,
          lessThan(tester.getTopLeft(find.text('Tarefas')).dy));
      // The compact layout brings the icon closer to the safe bottom edge.
      expect(safeBottom - tester.getCenter(icon).dy,
          lessThan(platform == TargetPlatform.iOS ? 32 : 45));
      await tester.tap(find.text('Resumo'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('iOS tabs use Cupertino and retain a running timer across tabs',
      (tester) async {
    _phone(tester);
    var now = DateTime(2026);
    await tester.pumpWidget(_app(
        NavigationBottomBar(pages: [
          MyHomePage(storage: _MemoryTasks()),
          TimePage(now: () => now, settingsStorage: MemoryPomodoroStorage()),
          const Center(child: Text('Resumo de teste')),
        ]),
        TargetPlatform.iOS));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoTabBar), findsOneWidget);
    expect(find.byType(CupertinoNavigationBar), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    await tester.tap(find.text('Foco'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Iniciar'));
    await tester.pump();
    await tester.tap(find.text('Resumo'));
    await tester.pumpAndSettle();
    expect(find.text('Resumo de teste'), findsOneWidget);
    await tester.tap(find.text('Tarefas').last);
    await tester.pumpAndSettle();
    now = now.add(const Duration(seconds: 10));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Foco'));
    await tester.pumpAndSettle();
    expect(find.text('24:50'), findsOneWidget);
    expect(find.text('Parar'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Android retains Material tabs, fields and buttons',
      (tester) async {
    await tester.pumpWidget(_app(
        NavigationBottomBar(pages: [
          MyHomePage(storage: _MemoryTasks()),
          const SizedBox(),
          const Center(child: Text('Resumo de teste')),
        ]),
        TargetPlatform.android));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byType(ElevatedButton), findsOneWidget);
    expect(find.byType(CupertinoTabBar), findsNothing);
  });

  testWidgets('iOS tasks use Cupertino fields, checkboxes and undo feedback',
      (tester) async {
    _phone(tester);
    final storage = _MemoryTasks();
    await tester
        .pumpWidget(_app(MyHomePage(storage: storage), TargetPlatform.iOS));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoTextField), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    await tester.enterText(find.byType(CupertinoTextField), 'Estudar');
    await tester.tap(find.byIcon(CupertinoIcons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CupertinoCheckbox));
    await tester.pumpAndSettle();
    expect(storage.tasks.single.completed, isTrue);
    await tester.drag(find.byType(CupertinoListTile), const Offset(-400, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remover'));
    await tester.pumpAndSettle();
    expect(storage.tasks, isEmpty);
    expect(find.byType(SnackBar), findsNothing);
    await tester.tap(find.text('Desfazer'));
    await tester.pumpAndSettle();
    expect(storage.tasks.single.title, 'Estudar');
    expect(storage.tasks.single.completed, isTrue);
  });

  testWidgets(
      'iOS settings use wheel pickers and switch, save 50 minutes and 30 sessions',
      (tester) async {
    _phone(tester);
    final storage = MemoryPomodoroStorage();
    await tester.pumpWidget(_app(
        TimePage(settingsStorage: storage), TargetPlatform.iOS,
        dark: true));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Configurar Pomodoro'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoSwitch), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<int>), findsNothing);
    await tester.tap(find.text('Tempo de foco'));
    await tester.pumpAndSettle();
    var picker = tester.widget<CupertinoPicker>(find.byType(CupertinoPicker));
    picker.scrollController!.jumpToItem(9); // 50 min
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('25 min'), findsOneWidget);
    await tester.tap(find.text('Tempo de foco'));
    await tester.pumpAndSettle();
    picker = tester.widget<CupertinoPicker>(find.byType(CupertinoPicker));
    picker.scrollController!.jumpToItem(9);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Concluir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sessões antes da pausa longa'));
    await tester.pumpAndSettle();
    picker = tester.widget<CupertinoPicker>(find.byType(CupertinoPicker));
    picker.scrollController!.jumpToItem(29);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Concluir'));
    await tester.pumpAndSettle();
    final save = find.text('Salvar configurações');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('50:00'), findsOneWidget);
    expect(storage.settings.sessionsBeforeLongBreak, 30);
    expect(storage.settings.focusMinutes, 50);
  });

  testWidgets(
      'iOS About uses Cupertino navigation and supports back navigation',
      (tester) async {
    PackageInfo.setMockInitialValues(
        appName: 'Doro List',
        packageName: 'doro',
        version: '1.2.3',
        buildNumber: '1',
        buildSignature: '');
    final journal = ActivityJournal(storage: MemoryJson());
    addTearDown(journal.dispose);
    await journal.load();
    await tester.pumpWidget(_app(
        NavigationBottomBar(pages: [
          MyHomePage(storage: _MemoryTasks()),
          const SizedBox(),
          SummaryPage(journal: journal),
        ]),
        TargetPlatform.iOS));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Sobre o app'), findsNothing);
    await tester.tap(find.text('Resumo'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Sobre o app'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoNavigationBar), findsOneWidget);
    expect(find.text('Versão 1.2.3'), findsOneWidget);
    expect(find.widgetWithText(CupertinoButton, 'Anthony Oliveira'),
        findsOneWidget);
    await tester.tap(find.byType(CupertinoNavigationBarBackButton));
    await tester.pumpAndSettle();
    expect(find.text('Resumo do dia'), findsOneWidget);
  });

  testWidgets(
      'iOS messages close after five seconds and newer messages replace older ones',
      (tester) async {
    await tester.pumpWidget(_app(
        Builder(
            builder: (context) => AdaptivePage(
                  title: 'Mensagens',
                  body: Center(
                      child: CupertinoButton(
                          onPressed: () {
                            showAppMessage(context, 'Primeira');
                            showAppMessage(context, 'Segunda');
                          },
                          child: const Text('Mostrar'))),
                )),
        TargetPlatform.iOS));
    await tester.tap(find.text('Mostrar'));
    await tester.pump();
    expect(find.text('Primeira'), findsNothing);
    expect(find.text('Segunda'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(find.text('Segunda'), findsNothing);
  });
  testWidgets(
      'iOS edits tasks with Cupertino controls and rejects blank titles',
      (tester) async {
    _phone(tester);
    final storage = _MemoryTasks()
      ..tasks = [const Task(id: '1', title: 'Original')];
    await tester
        .pumpWidget(_app(MyHomePage(storage: storage), TargetPlatform.iOS));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CupertinoListTile), const Offset(250, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    final editor = find.byType(CupertinoTextField).last;
    await tester.enterText(editor, '   ');
    await tester.tap(find.widgetWithText(CupertinoButton, 'Editar').last);
    await tester.pumpAndSettle();
    expect(storage.tasks.single.title, 'Original');
    await tester.tap(find.byIcon(CupertinoIcons.xmark));
    await tester.pumpAndSettle();
    await tester.enterText(editor, 'Atualizada');
    await tester.tap(find.widgetWithText(CupertinoButton, 'Editar').last);
    await tester.pumpAndSettle();
    expect(storage.tasks.single.title, 'Atualizada');
    expect(find.byType(CupertinoTextField), findsOneWidget);
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets(
        'custom time closes the modal without popping the focus tab on $platform',
        (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(
          NavigationBottomBar(pages: [
            const SizedBox(),
            TimePage(settingsStorage: MemoryPomodoroStorage()),
            const SizedBox(),
          ]),
          platform));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Foco'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Definir tempo'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byType(
              platform == TargetPlatform.iOS ? CupertinoTextField : TextField),
          '0130');
      await tester.pump();
      await tester.tap(find.text('Definir'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('01:30'), findsOneWidget);
      expect(find.text('Tempo customizado'), findsOneWidget);
      expect(
          find.widgetWithText(
              platform == TargetPlatform.iOS ? CupertinoButton : ElevatedButton,
              'Definir'),
          findsNothing);
      expect(find.byType(NavigationBottomBar), findsOneWidget);
      await tester.tap(find.text('Iniciar'));
      await tester.pump();
      expect(find.text('Parar'), findsOneWidget);
      await tester.tap(find.text('Parar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Definir tempo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('01:30'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('iOS custom timer validates input and applies the chosen time',
      (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(
        TimePage(settingsStorage: MemoryPomodoroStorage()),
        TargetPlatform.iOS));
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.tap(find.text('Definir tempo'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(CupertinoTextField), '0099');
    await tester.pump();
    final confirm = find.widgetWithText(CupertinoButton, 'Definir');
    expect(tester.widget<CupertinoButton>(confirm).onPressed, isNull);
    await tester.enterText(find.byType(CupertinoTextField), '0130');
    await tester.pump();
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(find.text('01:30'), findsOneWidget);
    expect(find.byType(CupertinoTextField), findsNothing);
  });
  testWidgets(
      'iOS preset colors override the global button theme and keep the active outline',
      (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(
        TimePage(settingsStorage: MemoryPomodoroStorage()),
        TargetPlatform.iOS));
    await tester.pumpAndSettle();
    final colors = AppTheme.lightTheme.colorScheme;
    CupertinoButton button(String label) => tester
        .widget<CupertinoButton>(find.widgetWithText(CupertinoButton, label));
    expect(button('Pomodoro').color, colors.primaryContainer);
    expect(button('Pausa curta').color, colors.surfaceContainerLow);
    expect(button('Iniciar').color, colors.primary);
    await tester.tap(find.text('Pausa curta'));
    await tester.pumpAndSettle();
    expect(button('Pausa curta').color, colors.primaryContainer);
    expect(button('Pomodoro').color, colors.surfaceContainerLow);
    final outline = tester.widget<DecoratedBox>(find
        .ancestor(
          of: find.widgetWithText(CupertinoButton, 'Pausa curta'),
          matching: find.byWidgetPredicate((widget) =>
              widget is DecoratedBox &&
              widget.position == DecorationPosition.foreground),
        )
        .first);
    expect(((outline.decoration as BoxDecoration).border as Border).top.color,
        colors.primary);
    await tester.tap(find.text('Iniciar'));
    await tester.pump();
    expect(button('Pausa curta').onPressed, isNull);
    expect(button('Pausa curta').disabledColor, colors.primaryContainer);
    await tester.pumpWidget(const SizedBox());
  });
}
