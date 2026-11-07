import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doro_list/models/task.dart';
import 'package:doro_list/pages/home_page.dart';
import 'package:doro_list/pages/time_page.dart';
import 'package:doro_list/services/task_storage.dart';
import 'support/memory_pomodoro_storage.dart';

class MemoryStorage extends TaskStorage {
  List<Task> tasks = [];
  bool failRead = false;
  bool failSave = false;
  int writes = 0;
  @override
  Future<List<Task>> read() async {
    if (failRead) throw const FormatException('Invalid data');
    return List.of(tasks);
  }

  @override
  Future<void> save(List<Task> value) async {
    if (failSave) throw Exception('Write failed');
    writes++;
    tasks = List.of(value);
  }
}

void main() {
  testWidgets('tasks reject whitespace, save and toggle completion',
      (tester) async {
    final storage = MemoryStorage();
    await tester.pumpWidget(MaterialApp(home: MyHomePage(storage: storage)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(storage.tasks, isEmpty);
    await tester.enterText(find.byType(TextField), '  Estudar Flutter  ');
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(storage.tasks.single.title, 'Estudar Flutter');
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    expect(storage.tasks.single.completed, isTrue);
  });

  testWidgets('edit validates titles and deletion can be undone',
      (tester) async {
    final storage = MemoryStorage()
      ..tasks = [const Task(id: '1', title: 'Original')];
    await tester.pumpWidget(MaterialApp(home: MyHomePage(storage: storage)));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CheckboxListTile), const Offset(400, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    final editor = find.descendant(
        of: find.byType(BottomSheet), matching: find.byType(TextField));
    await tester.enterText(editor, '   ');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Editar'));
    await tester.pumpAndSettle();
    expect(storage.tasks.single.title, 'Original');
    expect(find.byType(BottomSheet), findsOneWidget);
    await tester.enterText(editor, '  Atualizada  ');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Editar'));
    await tester.pumpAndSettle();
    expect(storage.tasks.single.title, 'Atualizada');
    await tester.drag(find.byType(CheckboxListTile), const Offset(-600, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remover'));
    await tester.pumpAndSettle();
    expect(storage.tasks, isEmpty);
    await tester.tap(find.text('Desfazer'));
    await tester.pumpAndSettle();
    expect(storage.tasks.single.id, '1');
    expect(storage.tasks.single.title, 'Atualizada');
  });

  testWidgets('load errors prevent accidental overwrites and allow retry',
      (tester) async {
    final storage = MemoryStorage()..failRead = true;
    await tester.pumpWidget(MaterialApp(home: MyHomePage(storage: storage)));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(storage.writes, 0);
    storage.failRead = false;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('failed saves show a retry action that saves current data',
      (tester) async {
    final storage = MemoryStorage()..failSave = true;
    await tester.pumpWidget(MaterialApp(home: MyHomePage(storage: storage)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Persistir');
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.text('Não foi possível salvar os itens.'), findsOneWidget);
    storage.failSave = false;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(storage.tasks.single.title, 'Persistir');
  });

  testWidgets('short break resets to five minutes and finishes on time',
      (tester) async {
    var now = DateTime(2026);
    await tester.pumpWidget(MaterialApp(
        home: TimePage(
            now: () => now, settingsStorage: MemoryPomodoroStorage())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pausa curta'));
    await tester.pump();
    await tester.tap(find.text('Iniciar'));
    now = now.add(const Duration(seconds: 10));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('04:50'), findsOneWidget);
    await tester.tap(find.text('Parar'));
    await tester.pump();
    now = now.add(const Duration(minutes: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('04:50'), findsOneWidget);
    await tester.tap(find.text('Reiniciar'));
    await tester.pump();
    expect(find.text('05:00'), findsOneWidget);
    await tester.tap(find.text('Iniciar'));
    now = now.add(const Duration(minutes: 5));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('25:00'), findsOneWidget);
    expect(find.text('Iniciar'), findsOneWidget);
  });

  testWidgets(
      'resume catches up elapsed time and pause preserves remaining time',
      (tester) async {
    var now = DateTime(2026);
    await tester.pumpWidget(MaterialApp(
        home: TimePage(
            now: () => now, settingsStorage: MemoryPomodoroStorage())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pausa longa'));
    await tester.pump();
    await tester.tap(find.text('Iniciar'));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = now.add(const Duration(minutes: 3));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('12:00'), findsOneWidget);
    await tester.tap(find.text('Parar'));
    await tester.pump();
    now = now.add(const Duration(minutes: 2));
    await tester.tap(find.text('Continuar'));
    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('11:59'), findsOneWidget);
    await tester.tap(find.text('Parar'));
    await tester.pump();
    await tester.tap(find.text('Reiniciar'));
    await tester.pump();
    expect(find.text('15:00'), findsOneWidget);
  });

  testWidgets('custom time validates seconds and updates progress total',
      (tester) async {
    await tester.pumpWidget(
        MaterialApp(home: TimePage(settingsStorage: MemoryPomodoroStorage())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Definir tempo'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '0199');
    await tester.pump();
    expect(
        tester
            .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, 'Definir'))
            .onPressed,
        isNull);
    await tester.enterText(find.byType(TextField), '0000');
    await tester.pump();
    expect(
        tester
            .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, 'Definir'))
            .onPressed,
        isNull);
    await tester.enterText(find.byType(TextField), '0130');
    await tester.pump();
    await tester.tap(find.text('Definir'));
    await tester.pumpAndSettle();
    expect(find.text('01:30'), findsOneWidget);
    expect(
        tester
            .widget<CircularProgressIndicator>(
                find.byType(CircularProgressIndicator))
            .value,
        1);
  });
}
