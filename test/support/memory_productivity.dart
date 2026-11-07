import 'dart:convert';
import 'package:doro_list/services/json_storage.dart';
import 'package:doro_list/services/task_storage.dart';
import 'package:doro_list/services/session_alerts.dart';
import 'package:doro_list/models/task.dart';

class MemoryJson extends JsonStorage {
  MemoryJson() : super('test.json');
  Map<String, dynamic>? data;
  bool failSave = false;
  int writes = 0;
  @override
  Future<Map<String, dynamic>?> read() async =>
      data == null ? null : jsonDecode(jsonEncode(data));
  @override
  Future<void> save(Map<String, dynamic> value) async {
    if (failSave) throw Exception('Disk full');
    writes++;
    data = jsonDecode(jsonEncode(value));
  }
}

class MemoryTasks extends TaskStorage {
  List<Task> values = [];
  @override
  Future<List<Task>> read() async => List.of(values);
  @override
  Future<void> save(List<Task> tasks) async {
    values = List.of(tasks);
  }
}

class RecordingAlerts extends SessionAlerts {
  final List<String> scheduled = [];
  final List<String> cancelled = [];
  final List<String> finished = [];
  DateTime? lastDeadline;
  String? lastBody;
  @override
  Future<String?> schedule(
      {required String sessionId,
      required DateTime deadline,
      required String title,
      required String body,
      bool requestPermissions = true}) async {
    scheduled.add(sessionId);
    lastDeadline = deadline;
    lastBody = body;
    return null;
  }

  @override
  Future<void> cancel(String sessionId) async {
    cancelled.add(sessionId);
  }

  @override
  Future<void> completed(
      {required String sessionId,
      required String title,
      required String body,
      required bool foreground}) async {
    finished.add(sessionId);
  }
}
