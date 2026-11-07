import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import '../models/task.dart';

class TaskStorage {
  TaskStorage({Future<Directory> Function()? directory})
      : _directory = directory ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _directory;
  Future<void> _pendingWrite = Future.value();

  Future<File> _file() async => File('${(await _directory()).path}/todos.json');

  Future<List<Task>> read() async {
    final file = await _file();
    if (!await file.exists()) return [];
    final content = await file.readAsString();
    if (content.trim().isEmpty) return [];
    final data = jsonDecode(content);
    if (data is! List) throw const FormatException('Lista inválida');
    final tasks = <Task>[];
    final ids = <String>{};
    for (var i = 0; i < data.length; i++) {
      final task = Task.fromJson(data[i], 'legacy-$i');
      if (!ids.add(task.id)) throw const FormatException('ID duplicado');
      tasks.add(task);
    }
    return tasks;
  }

  Future<void> save(List<Task> tasks) {
    // Capture each change now and serialize writes to prevent older data winning.
    final content = jsonEncode(tasks.map((task) => task.toJson()).toList());
    final write = _pendingWrite.then((_) async {
      final file = await _file();
      final temporary = File('${file.path}.tmp');
      await temporary.writeAsString(content, flush: true);
      await temporary.rename(file.path);
    });
    // Keep the queue usable after a failure; callers still receive the error.
    _pendingWrite =
        write.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return write;
  }
}
