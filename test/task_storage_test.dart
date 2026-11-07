import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:doro_list/models/task.dart';
import 'package:doro_list/services/task_storage.dart';

void main() {
  late Directory directory;
  late TaskStorage storage;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('doro_list_test_');
    storage = TaskStorage(directory: () async => directory);
  });
  tearDown(() async => directory.delete(recursive: true));

  test('reads missing files and migrates existing tasks without IDs', () async {
    expect(await storage.read(), isEmpty);
    await File('${directory.path}/todos.json').writeAsString(
      '[{"title":"  Estudar  ","ok":true}]',
    );
    final tasks = await storage.read();
    expect(tasks.single.title, 'Estudar');
    expect(tasks.single.completed, isTrue);
    await storage.save(tasks);
    expect((await storage.read()).single.id, tasks.single.id);
  });

  test('rapid writes persist the latest snapshot', () async {
    final tasks = <Task>[const Task(id: '1', title: 'Primeira')];
    final first = storage.save(tasks);
    tasks.add(const Task(id: '2', title: 'Segunda'));
    final second = storage.save(tasks);
    tasks.clear();
    await Future.wait([first, second]);
    expect((await storage.read()).map((task) => task.title),
        ['Primeira', 'Segunda']);
    expect(await File('${directory.path}/todos.json.tmp').exists(), isFalse);
  });

  test('invalid data is reported without overwriting the original', () async {
    final file = File('${directory.path}/todos.json');
    for (final content in ['broken', '[{"title":"","ok":false}]']) {
      await file.writeAsString(content);
      await expectLater(storage.read(), throwsFormatException);
      expect(await file.readAsString(), content);
    }
  });

  test('a failed save does not block later writes', () async {
    final file = File('${directory.path}/todos.json');
    await Directory('${file.path}.tmp').create();
    await expectLater(storage.save([]), throwsA(isA<FileSystemException>()));
    await Directory('${file.path}.tmp').delete();
    await storage.save([const Task(id: '1', title: 'Recuperada')]);
    expect((await storage.read()).single.title, 'Recuperada');
  });
}
