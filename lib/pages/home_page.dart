import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../components/adaptive.dart';
import '../components/focus_overview_panel.dart';
import '../view_models/tasks_view_model.dart';
import '../view_models/pomodoro_view_model.dart';
import '../models/task.dart';
import '../services/task_storage.dart';
import '../services/task_backup.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage(
      {super.key,
      this.storage,
      this.controller,
      this.onFocusTask,
      this.pomodoro,
      this.onOpenFocus,
      this.backup});
  final PomodoroViewModel? pomodoro;
  final VoidCallback? onOpenFocus;
  final TaskStorage? storage;
  final TasksViewModel? controller;
  final ValueChanged<Task>? onFocusTask;
  final TaskBackup? backup;
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _newTask = TextEditingController();
  final _editor = TextEditingController();
  final _focus = FocusNode();
  late final TasksViewModel _tasks;

  @override
  void initState() {
    super.initState();
    _tasks = widget.controller ?? TasksViewModel(storage: widget.storage);
    if (widget.controller == null) unawaited(_tasks.load());
  }

  @override
  void dispose() {
    _newTask.dispose();
    _editor.dispose();
    _focus.dispose();
    if (widget.controller == null) _tasks.dispose();
    super.dispose();
  }

  Future<void> _save(Future<void> Function() operation) async {
    try {
      await operation();
    } catch (_) {
      if (!mounted) return;
      showAppMessage(context, 'Não foi possível salvar os itens.',
          actionLabel: 'Tentar novamente', onAction: () => _save(_tasks.save));
    }
  }

  void _add() {
    final title = _newTask.text;
    if (!TasksViewModel.hasTitle(title)) {
      showAppMessage(context, 'Insira o nome do seu item antes de adicionar!');
      return;
    }
    _newTask.clear();
    _save(() => _tasks.add(title));
  }

  void _edit(Task task) {
    _editor.text = task.title;
    showAdaptiveSheet<void>(
        context: context,
        builder: (sheetContext) => Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16,
                  MediaQuery.viewInsetsOf(sheetContext).bottom + 20),
              child: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                AdaptiveTextField(
                    controller: _editor,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                        labelText: 'Editar item',
                        border: OutlineInputBorder())),
                const SizedBox(height: 24),
                Row(children: [
                  Expanded(
                      child: AdaptiveButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              foregroundColor:
                                  Theme.of(context).colorScheme.onSurface),
                          child: const Text('Cancelar'))),
                  const SizedBox(width: 8),
                  Expanded(
                      child: AdaptiveButton(
                          onPressed: () {
                            final title = _editor.text;
                            if (!TasksViewModel.hasTitle(title)) {
                              showAppMessage(context,
                                  'O nome do item não pode ficar vazio.');
                              return;
                            }
                            _save(() => _tasks.edit(task.id, title));
                            Navigator.pop(sheetContext);
                          },
                          child: const Text('Editar'))),
                ]),
              ])),
            ));
  }

  void _remove(Task task) {
    final position = _tasks.positionOf(task);
    _save(() => _tasks.remove(task.id));
    showAppMessage(context, 'Item ${task.title} removido!',
        actionLabel: 'Desfazer',
        onAction: () => _save(() => _tasks.restore(task, position)));
  }

  Future<void> _clearCompleted() async {
    final confirmed = await showAdaptiveConfirmation(context,
        title: 'Limpar tarefas concluídas?',
        message:
            'As tarefas concluídas serão removidas da lista. O resumo do dia será preservado.',
        confirmLabel: 'Limpar',
        destructive: true);
    if (confirmed && mounted) _save(_tasks.clearCompleted);
  }

  Future<void> _export() async {
    final message = await _tasks.exportBackup(backup: widget.backup);
    if (mounted && message != null) showAppMessage(context, message);
  }

  Future<void> _import() async {
    final preview = await _tasks.prepareImport(backup: widget.backup);
    if (!mounted || preview == null) return;
    final message = preview.message;
    if (message != null) {
      showAppMessage(context, message);
      return;
    }
    final imported = preview.tasks;
    if (imported == null) return;
    final confirmed = await showAdaptiveConfirmation(context,
        title: 'Importar tarefas?',
        message:
            '${preview.count} tarefas serão adicionadas. Suas tarefas atuais serão mantidas.',
        confirmLabel: 'Importar');
    if (!confirmed || !mounted) return;
    final result = await _tasks.confirmImport(imported);
    if (mounted && result != null) showAppMessage(context, result);
  }

  void _options() {
    showAdaptiveSheet<void>(
        context: context,
        builder: (sheetContext) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Sua lista',
                        style: Theme.of(context).textTheme.titleLarge),
                    AdaptiveButton.text(
                        onPressed: !_tasks.canBackUp
                            ? null
                            : () {
                                Navigator.pop(sheetContext);
                                _export();
                              },
                        child: const Text('Exportar tarefas')),
                    AdaptiveButton.text(
                        onPressed: !_tasks.canBackUp
                            ? null
                            : () {
                                Navigator.pop(sheetContext);
                                _import();
                              },
                        child: const Text('Importar tarefas')),
                    AdaptiveButton.text(
                        onPressed: _tasks.hasCompleted
                            ? () {
                                Navigator.pop(sheetContext);
                                _clearCompleted();
                              }
                            : null,
                        child: const Text('Limpar concluídas')),
                  ]),
            ));
  }

  Widget _filters() {
    const labels = {
      TaskFilter.all: 'Todas',
      TaskFilter.pending: 'Pendentes',
      TaskFilter.completed: 'Concluídas'
    };
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
        child: usesCupertino(context)
            ? SizedBox(
                width: double.infinity,
                child: CupertinoSlidingSegmentedControl<TaskFilter>(
                    groupValue: _tasks.filter,
                    children:
                        labels.map((key, value) => MapEntry(key, Text(value))),
                    onValueChanged: (value) {
                      if (value != null) {
                        _tasks.selectFilter(value);
                      }
                    }))
            : SegmentedButton<TaskFilter>(
                segments: labels.entries
                    .map((entry) => ButtonSegment(
                        value: entry.key, label: Text(entry.value)))
                    .toList(),
                selected: {_tasks.filter},
                onSelectionChanged: (value) =>
                    _tasks.selectFilter(value.single)));
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: Listenable.merge([
        _tasks,
        if (widget.pomodoro != null) widget.pomodoro!,
      ]),
      builder: (context, _) {
        final visible = _tasks.visibleTasks;
        return GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: AdaptivePage(
              title: 'Minhas Tarefas',
              contentMaxWidth: widget.pomodoro == null ? 760 : 1120,
              trailing: AdaptiveIconButton(
                  cupertinoSize: 24,
                  tooltip: 'Mais opções',
                  icon: Icons.more_vert,
                  cupertinoIcon: CupertinoIcons.ellipsis_circle,
                  onPressed: _options),
              body: _tasks.loading
                  ? const Center(child: AdaptiveLoading())
                  : _tasks.loadFailed
                      ? Center(
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                          const Text(
                              'Não foi possível carregar os itens. Seus dados foram preservados.'),
                          AdaptiveButton.text(
                              onPressed: _tasks.load,
                              child: const Text('Tentar novamente')),
                        ]))
                      : SafeArea(
                          child: LayoutBuilder(builder: (context, constraints) {
                          final timer = widget.pomodoro;
                          if (timer != null && constraints.maxWidth >= 840) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                    child: _taskList(visible,
                                        showFocusStrip: false)),
                                VerticalDivider(
                                    width: 1,
                                    thickness: 0.5,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outlineVariant),
                                SizedBox(
                                    width: 320,
                                    child: FocusOverviewPanel(
                                        timer: timer,
                                        onOpenFocus: widget.onOpenFocus)),
                              ],
                            );
                          }
                          return Align(
                              alignment: Alignment.topCenter,
                              child: ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 760),
                                  child: _taskList(visible)));
                        })),
            ));
      });

  Widget _taskList(List<Task> visible, {bool showFocusStrip = true}) =>
      Column(children: [
        if (_tasks.backupBusy)
          const Padding(padding: EdgeInsets.all(8), child: AdaptiveLoading()),
        Expanded(
            child: ReorderableListView.builder(
          header: _heading(),
          footer: visible.isEmpty
              ? Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                  child: Text(switch (_tasks.filter) {
                    TaskFilter.all =>
                      'Uma coisa de cada vez.\nAdicione sua primeira tarefa.',
                    TaskFilter.pending =>
                      'Tudo em dia. Nenhuma tarefa pendente.',
                    TaskFilter.completed =>
                      'Suas tarefas concluídas aparecerão aqui.',
                  }),
                )
              : null,
          buildDefaultDragHandles: false,
          padding: const EdgeInsets.only(top: 0, bottom: 24),
          itemCount: visible.length,
          onReorderItem: (oldIndex, newIndex) =>
              _save(() => _tasks.reorder(_tasks.filter, oldIndex, newIndex)),
          itemBuilder: (context, index) => _item(visible[index], index),
          proxyDecorator: (child, index, animation) => usesCupertino(context)
              ? DecoratedBox(
                  decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerLow),
                  child: child)
              : Material(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  child: child),
        )),
        if (showFocusStrip && (widget.pomodoro?.hasActiveSession ?? false))
          _focusStrip(),
      ]);

  Widget _heading() {
    final colors = Theme.of(context).colorScheme;
    final count = _tasks.pending.length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Tarefas',
              style: TextStyle(
                  fontFamily: 'Georgia',
                  fontFamilyFallback: const ['serif'],
                  fontSize: 44,
                  height: 1.15,
                  letterSpacing: -1.5,
                  color: colors.onSurface)),
          const SizedBox(height: 12),
          Text('$count ${count == 1 ? 'tarefa pendente' : 'tarefas pendentes'}',
              style: TextStyle(
                  color: colors.primary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(
                child: AdaptiveTextField(
                    controller: _newTask,
                    focusNode: _focus,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                        labelText: 'Nova tarefa',
                        hintText: 'O que você quer fazer?',
                        border: UnderlineInputBorder()))),
            const SizedBox(width: 12),
            Semantics(
                label: 'Adicionar tarefa',
                button: true,
                child: AdaptiveButton(
                    onPressed: _add,
                    child: Icon(usesCupertino(context)
                        ? CupertinoIcons.add
                        : Icons.add))),
          ]),
        ]),
      ),
      _filters(),
      Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: Text('SUAS TAREFAS',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.6,
                  color: colors.onSurfaceVariant))),
    ]);
  }

  Widget _focusStrip() {
    final timer = widget.pomodoro!;
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('active-focus-strip'),
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      decoration: BoxDecoration(
          color: colors.primaryContainer,
          borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Expanded(
            child: AdaptiveButton.text(
          onPressed: widget.onOpenFocus,
          child: Row(children: [
            Icon(
                usesCupertino(context)
                    ? CupertinoIcons.timer
                    : Icons.timer_outlined,
                color: colors.primary,
                size: 22),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                  Text(
                      timer.running
                          ? timer.phaseLabel
                          : '${timer.phaseLabel} em pausa',
                      style: TextStyle(
                          fontSize: 12, color: colors.onPrimaryContainer)),
                  Text(timer.taskTitle ?? 'Um momento de foco',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: colors.onPrimaryContainer)),
                ])),
            const SizedBox(width: 8),
            Text(timer.timeText,
                style: TextStyle(
                    fontSize: 20,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    fontWeight: FontWeight.w500,
                    color: colors.onPrimaryContainer)),
          ]),
        )),
        AdaptiveIconButton(
            tooltip: timer.running ? 'Pausar foco' : 'Continuar foco',
            icon: timer.running ? Icons.pause : Icons.play_arrow,
            cupertinoIcon: timer.running
                ? CupertinoIcons.pause_fill
                : CupertinoIcons.play_fill,
            onPressed: timer.running ? timer.pause : timer.start),
      ]),
    );
  }

  Widget _item(Task task, int index) {
    final colors = Theme.of(context).colorScheme;
    final text = Text(task.title,
        style: TextStyle(
            fontSize: 16,
            decoration: task.completed ? TextDecoration.lineThrough : null,
            color:
                task.completed ? colors.onSurfaceVariant : colors.onSurface));
    return Container(
      key: ValueKey(task.id),
      margin: const EdgeInsets.symmetric(horizontal: 24),
      constraints: const BoxConstraints(minHeight: 72),
      decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(color: colors.outlineVariant, width: 0.5))),
      child: Row(children: [
        Expanded(
            child: Slidable(
          key: ValueKey('slide-${task.id}'),
          startActionPane: ActionPane(
              motion: const DrawerMotion(),
              extentRatio: 0.35,
              children: [
                AdaptiveSlideAction(
                    onPressed: (_) => _edit(task),
                    backgroundColor: colors.primaryContainer,
                    foregroundColor: colors.onPrimaryContainer,
                    icon: Icons.edit,
                    label: 'Editar'),
              ]),
          endActionPane: ActionPane(
              motion: const DrawerMotion(),
              extentRatio: 0.35,
              children: [
                AdaptiveSlideAction(
                    onPressed: (_) => _remove(task),
                    backgroundColor: colors.errorContainer,
                    foregroundColor: colors.onErrorContainer,
                    icon: Icons.delete,
                    label: 'Remover'),
              ]),
          child: usesCupertino(context)
              ? CupertinoListTile(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  title: text,
                  leading: CupertinoCheckbox(
                      value: task.completed,
                      activeColor: colors.primary,
                      checkColor: colors.onPrimary,
                      onChanged: (value) =>
                          _save(() => _tasks.toggle(task.id, value ?? false))),
                  onTap: () =>
                      _save(() => _tasks.toggle(task.id, !task.completed)))
              : CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: text,
                  value: task.completed,
                  onChanged: (value) =>
                      _save(() => _tasks.toggle(task.id, value ?? false))),
        )),
        if (widget.onFocusTask != null && !task.completed)
          AdaptiveIconButton(
              tooltip: 'Focar em ${task.title}',
              icon: Icons.play_circle_outline,
              cupertinoIcon: CupertinoIcons.play_circle,
              onPressed: () => widget.onFocusTask!(task)),
        ReorderableDragStartListener(
            key: ValueKey('reorder-${task.id}'),
            index: index,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              child: Icon(
                  usesCupertino(context)
                      ? CupertinoIcons.line_horizontal_3
                      : Icons.drag_handle,
                  semanticLabel: 'Reordenar ${task.title}',
                  color: colors.onSurfaceVariant),
            )),
      ]),
    );
  }
}
