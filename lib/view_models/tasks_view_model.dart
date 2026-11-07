import 'package:flutter/foundation.dart';
import '../models/task.dart';
import '../models/activity.dart';
import '../services/task_storage.dart';
import '../services/task_backup.dart';
import '../repositories/activity_journal.dart';

enum TaskFilter { all, pending, completed }

class TasksViewModel extends ChangeNotifier {
  TasksViewModel({TaskStorage? storage, this.journal, this.now = DateTime.now})
      : _storage = storage ?? TaskStorage();
  final TaskStorage _storage;
  final _backup = TaskBackup();
  final ActivityJournal? journal;
  final DateTime Function() now;
  List<Task> _tasks = [];
  bool loading = true;
  bool loadFailed = false;
  String? saveError;
  int _counter = 0;
  TaskFilter _filter = TaskFilter.all;
  bool _backupBusy = false;

  TaskFilter get filter => _filter;
  bool get backupBusy => _backupBusy;
  bool get canBackUp => !loading && !loadFailed && !_backupBusy;
  bool get hasCompleted => _tasks.any((task) => task.completed);
  List<Task> get visibleTasks => filtered(_filter);

  void selectFilter(TaskFilter filter) {
    if (_filter == filter) return;
    _filter = filter;
    _emit();
  }

  static bool hasTitle(String title) => title.trim().isNotEmpty;

  int positionOf(Task task) =>
      _tasks.indexWhere((current) => current.id == task.id);

  List<Task> get tasks => List.unmodifiable(_tasks);
  List<Task> get pending => _tasks.where((task) => !task.completed).toList();

  Future<void> load() async {
    loading = true;
    loadFailed = false;
    _emit();
    try {
      await journal?.load();
      _tasks = await _storage.read();
      _partition();
    } catch (_) {
      loadFailed = true;
    }
    loading = false;
    _emit();
  }

  List<Task> filtered(TaskFilter filter) => _tasks
      .where((task) => switch (filter) {
            TaskFilter.all => true,
            TaskFilter.pending => !task.completed,
            TaskFilter.completed => task.completed,
          })
      .toList();

  void _partition() {
    _tasks = [
      ..._tasks.where((t) => !t.completed),
      ..._tasks.where((t) => t.completed)
    ];
  }

  Future<void> save() async {
    try {
      await _storage.save(_tasks);
      await journal?.persist();
      saveError = null;
    } catch (_) {
      saveError = 'Não foi possível salvar os itens.';
      rethrow;
    } finally {
      _emit();
    }
  }

  Future<void> add(String title) async {
    title = title.trim();
    if (title.isEmpty) throw const FormatException('Informe o nome da tarefa.');
    if (_filter == TaskFilter.completed) _filter = TaskFilter.pending;
    _tasks.add(Task(
        id: '${now().microsecondsSinceEpoch}-${_counter++}', title: title));
    _partition();
    _emit();
    await save();
  }

  Future<void> edit(String id, String title) async {
    title = title.trim();
    if (title.isEmpty) {
      throw const FormatException('O nome do item não pode ficar vazio.');
    }
    final index = _tasks.indexWhere((task) => task.id == id);
    if (index < 0) return;
    _tasks[index] = _tasks[index].copyWith(title: title);
    _emit();
    await save();
  }

  Future<void> toggle(String id, bool completed) async {
    final index = _tasks.indexWhere((task) => task.id == id);
    if (index < 0 || _tasks[index].completed == completed) return;
    final task = _tasks[index];
    if (completed) {
      journal?.taskCompleted(id, now());
    } else if (task.completedAt != null &&
        dayKey(task.completedAt!) == dayKey(now())) {
      journal?.taskReopened(id, now());
    }
    _tasks[index] = task.copyWith(
        completed: completed,
        completedAt: completed ? now() : null,
        clearCompletedAt: !completed);
    _partition();
    _emit();
    await save();
  }

  Future<void> remove(String id) async {
    _tasks.removeWhere((task) => task.id == id);
    _emit();
    await save();
  }

  Future<void> restore(Task task, int position) async {
    if (_tasks.any((current) => current.id == task.id)) return;
    _tasks.insert(position.clamp(0, _tasks.length), task);
    _partition();
    _emit();
    await save();
  }

  Future<void> clearCompleted() async {
    _tasks.removeWhere((task) => task.completed);
    _emit();
    await save();
  }

  Future<void> reorder(TaskFilter filter, int oldIndex, int newIndex) async {
    final visible = filtered(filter);
    final moved = visible.removeAt(oldIndex);
    visible.insert(newIndex, moved);
    final ids = visible.map((task) => task.id).toSet();
    var i = 0;
    _tasks = [
      for (final task in _tasks) ids.contains(task.id) ? visible[i++] : task
    ];
    _partition();
    _emit();
    await save();
  }

  Future<int> importTasks(List<Task> imported) async {
    final ids = _tasks.map((task) => task.id).toSet();
    final additions = imported.where((task) => ids.add(task.id)).toList();
    _tasks.addAll(additions);
    _partition();
    _emit();
    await save();
    return additions.length;
  }

  Future<String?> exportBackup({TaskBackup? backup}) => _runBackup(() async {
        return await (backup ?? _backup).export(tasks)
            ? 'Backup de tarefas exportado.'
            : null;
      }, 'exportar');

  Future<({List<Task>? tasks, int count, String? message})?> prepareImport(
      {TaskBackup? backup}) async {
    List<Task>? imported;
    var count = 0;
    final message = await _runBackup(() async {
      imported = await (backup ?? _backup).pickImport();
      final selected = imported;
      if (selected == null) return null;
      final ids = _tasks.map((task) => task.id).toSet();
      count = selected.where((task) => !ids.contains(task.id)).length;
      return count == 0
          ? 'Este backup não tem novas tarefas para importar.'
          : null;
    }, 'importar');
    if (imported == null && message == null) return null;
    return (tasks: imported, count: count, message: message);
  }

  Future<String?> confirmImport(List<Task> imported) => _runBackup(
      () async => '${await importTasks(imported)} tarefas importadas.',
      'importar');

  Future<String?> _runBackup(
      Future<String?> Function() operation, String action) async {
    if (!canBackUp) return null;
    _backupBusy = true;
    _emit();
    try {
      return await operation();
    } on FormatException catch (error) {
      return error.message;
    } catch (_) {
      return 'Não foi possível $action o backup. Tente novamente.';
    } finally {
      _backupBusy = false;
      _emit();
    }
  }

  bool _disposed = false;
  void _emit() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
