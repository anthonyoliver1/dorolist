import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import '../models/task.dart';

class TaskBackup {
  static const maxBytes = 5 * 1024 * 1024;

  Uint8List encode(List<Task> tasks, DateTime now) {
    final bytes = Uint8List.fromList(
        utf8.encode(const JsonEncoder.withIndent('  ').convert({
      'app': 'doro_list',
      'schema': 1,
      'exportedAt': now.toUtc().toIso8601String(),
      'tasks': tasks.map((task) => task.toJson()).toList(),
    })));
    if (bytes.length > maxBytes) {
      throw const FormatException('O backup deve ter até 5 MB.');
    }
    return bytes;
  }

  List<Task> decode(List<int> bytes) {
    if (bytes.length > maxBytes) {
      throw const FormatException('O backup deve ter até 5 MB.');
    }
    final Object? data;
    try {
      data = jsonDecode(utf8.decode(bytes));
    } catch (_) {
      throw const FormatException('O arquivo não contém um JSON válido.');
    }
    final Object? values;
    if (data is List) {
      values = data;
    } else if (data is Map &&
        data['app'] == 'doro_list' &&
        data['schema'] == 1) {
      values = data['tasks'];
    } else {
      throw const FormatException('Escolha um backup do Doro List.');
    }
    if (values is! List) {
      throw const FormatException('Lista de tarefas inválida.');
    }
    final tasks = <Task>[];
    final ids = <String>{};
    for (var i = 0; i < values.length; i++) {
      // A deterministic fallback avoids duplicating old backups when imported twice.
      final task = Task.fromJson(values[i], 'legacy-$i');
      if (!ids.add(task.id)) {
        throw const FormatException('O backup contém IDs duplicados.');
      }
      tasks.add(task);
    }
    return tasks;
  }

  Future<bool> export(List<Task> tasks) async {
    final date = DateTime.now();
    final uri = await FilePicker.saveFile(
        dialogTitle: 'Exportar tarefas',
        fileName: 'doro-list-${date.toIso8601String().substring(0, 10)}.json',
        bytes: encode(tasks, date),
        mimeType: 'application/json');
    return uri != null;
  }

  Future<List<Task>?> pickImport() async {
    final file = await FilePicker.pickFile(
        dialogTitle: 'Importar tarefas',
        type: FileType.custom,
        allowedExtensions: ['json']);
    if (file == null) return null;
    final length = await file.length();
    if (length != null && length > maxBytes) {
      throw const FormatException('O backup deve ter até 5 MB.');
    }
    final bytes = BytesBuilder();
    await for (final chunk in file.readAsByteStream()) {
      if (bytes.length + chunk.length > maxBytes) {
        throw const FormatException('O backup deve ter até 5 MB.');
      }
      bytes.add(chunk);
    }
    return decode(bytes.takeBytes());
  }
}
