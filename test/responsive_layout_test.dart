import 'package:doro_list/components/navigation_bottom_bar.dart';
import 'package:doro_list/models/activity.dart';
import 'package:doro_list/controllers/activity_journal.dart';
import 'package:doro_list/controllers/pomodoro_controller.dart';
import 'package:doro_list/controllers/task_controller.dart';
import 'package:doro_list/pages/home_page.dart';
import 'package:doro_list/pages/summary_page.dart';
import 'package:doro_list/pages/time_page.dart';
import 'package:doro_list/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/memory_pomodoro_storage.dart';
import 'support/memory_productivity.dart';

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets(
        'content adapts to wide, narrow and rotated screens on $platform',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetPadding);
      final journal = ActivityJournal(storage: MemoryJson());
      final tasks = TaskController(storage: MemoryTasks(), journal: journal);
      final timer = PomodoroController(
          settingsStorage: MemoryPomodoroStorage(), journal: journal);
      addTearDown(journal.dispose);
      addTearDown(tasks.dispose);
      addTearDown(timer.dispose);
      await tasks.load();
      await timer.load();
      await tasks.add('Preparar relatório');
      await tasks.toggle(tasks.tasks.single.id, true);
      journal.recordFocus(
          FocusRecord(id: 'today', endedAt: timer.now(), seconds: 1500));
      await journal.persist();
      for (final size in [
        const Size(950, 669),
        const Size(669, 950),
        const Size(390, 844),
        const Size(844, 390),
      ]) {
        tester.view.physicalSize = size;
        final rightInset = size.width > size.height ? 60.0 : 0.0;
        tester.view.padding =
            FakeViewPadding(top: 24, right: rightInset, bottom: 34);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(MaterialApp(
            theme: AppTheme.lightTheme.copyWith(platform: platform),
            home: NavigationBottomBar(pages: [
              MyHomePage(controller: tasks, pomodoro: timer),
              TimePage(controller: timer, tasksController: tasks),
              SummaryPage(journal: journal),
            ])));
        await tester.pumpAndSettle();
        final list = tester.getRect(find.byType(ReorderableListView));
        expect(list.width, lessThanOrEqualTo(760));
        final wide = size.width - rightInset >= 840;
        final panel = find.byKey(const ValueKey('focus-overview-panel'));
        if (wide) {
          expect(panel, findsOneWidget);
          final panelRect = tester.getRect(panel);
          expect(list.right, lessThanOrEqualTo(panelRect.left));
          expect(panelRect.right, lessThanOrEqualTo(size.width - rightInset));
          final panelStart =
              find.descendant(of: panel, matching: find.text('Iniciar'));
          await tester.tap(panelStart);
          await tester.pump();
          expect(timer.running, isTrue);
          await tester
              .tap(find.descendant(of: panel, matching: find.text('Pausar')));
          await tester.pumpAndSettle();
          expect(timer.stopped, isTrue);
          await tester.ensureVisible(
              find.descendant(of: panel, matching: find.text('25 min')));
          expect(find.descendant(of: panel, matching: find.text('25 min')),
              findsOneWidget);
          // Resizing hides the sidebar while preserving the paused session.
          tester.view.physicalSize = const Size(390, 844);
          await tester.pumpAndSettle();
          expect(panel, findsNothing);
          expect(
              find.byKey(const ValueKey('active-focus-strip')), findsOneWidget);
          expect(timer.stopped, isTrue);
          await tester.tap(find.byTooltip('Continuar foco'));
          await tester.pump();
          expect(timer.running, isTrue);
          timer.reset();
          tester.view.physicalSize = size;
          await tester.pumpAndSettle();
          expect(panel, findsOneWidget);
        } else {
          expect(panel, findsNothing);
          expect(list.center.dx, closeTo((size.width - rightInset) / 2, 1));
        }
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('Resumo').last);
        await tester.pumpAndSettle();
        final summaryWide = find.byKey(const ValueKey('summary-wide-layout'));
        expect(summaryWide, wide ? findsOneWidget : findsNothing);
        if (wide) {
          final overview =
              tester.getRect(find.byKey(const ValueKey('summary-overview')));
          final history =
              tester.getRect(find.byKey(const ValueKey('summary-history')));
          expect(overview.right, lessThanOrEqualTo(history.left));
          expect(history.right, lessThanOrEqualTo(size.width - rightInset));
          expect(find.text('25 min de foco'), findsOneWidget);
          expect(find.text('25 min'), findsOneWidget);
        } else {
          expect(tester.getSize(find.byType(ListView).hitTestable()).width,
              lessThanOrEqualTo(760));
        }
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('Foco').last);
        await tester.pumpAndSettle();
        final scroll = find.byKey(const ValueKey('focus-scroll'));
        expect(find.byKey(const ValueKey('focus-wide-layout')),
            wide ? findsOneWidget : findsNothing);
        expect(
            tester.getSize(scroll).width, lessThanOrEqualTo(wide ? 1040 : 560));
        if (wide) {
          final clock = tester.getRect(find.text('25:00'));
          final controls =
              tester.getRect(find.byKey(const ValueKey('focus-controls')));
          expect(clock.right, lessThan(controls.left));
          await tester.tap(find.text('Vincular tarefa'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Focar sem tarefa'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Pausa curta'));
          await tester.pumpAndSettle();
          expect(find.text('05:00'), findsOneWidget);
          await tester.tap(find.text('Pomodoro').last);
          await tester.pumpAndSettle();
        }
        await tester.ensureVisible(find.text('Iniciar'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Iniciar'));
        await tester.pump();
        expect(timer.running, isTrue);
        if (wide) {
          tester.view.physicalSize = const Size(390, 844);
          await tester.pump();
          expect(find.byKey(const ValueKey('focus-wide-layout')), findsNothing);
          expect(timer.running, isTrue);
          await tester.ensureVisible(find.text('Parar'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Parar'));
          await tester.pumpAndSettle();
          expect(timer.stopped, isTrue);
          tester.view.physicalSize = size;
          await tester.pumpAndSettle();
          expect(
              find.byKey(const ValueKey('focus-wide-layout')), findsOneWidget);
          expect(find.text('Continuar'), findsOneWidget);
        }
        timer.reset();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
}
