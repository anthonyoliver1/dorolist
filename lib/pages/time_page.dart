import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../components/adaptive.dart';

import 'package:doro_list/shared/time_input_formatter.dart';
import 'package:doro_list/components/progress.dart';
import '../models/pomodoro_settings.dart';
import '../services/pomodoro_settings_storage.dart';
import '../components/pomodoro_settings_sheet.dart';
import '../view_models/pomodoro_view_model.dart';
import '../view_models/tasks_view_model.dart';
import '../models/timer_snapshot.dart';

export '../models/timer_snapshot.dart' show TimeType;

class TimePage extends StatefulWidget {
  const TimePage(
      {super.key,
      this.now = DateTime.now,
      this.settingsStorage,
      this.controller,
      this.tasksController});

  final DateTime Function() now;
  final PomodoroSettingsStorage? settingsStorage;
  final PomodoroViewModel? controller;
  final TasksViewModel? tasksController;

  @override
  State<TimePage> createState() => _TimePageState();
}

class _TimePageState extends State<TimePage> {
  late final PomodoroViewModel _engine;
  late final TextEditingController _timeController;
  int _messageVersion = 0;

  bool get _isRunning => _engine.running;
  bool get _isStopped => _engine.stopped;
  bool get _isDefinedTime => _engine.remainingSeconds > 0;
  bool get _loadingSettings => _engine.loading;
  bool get _settingsLoadFailed => _engine.loadFailed;
  int get _completedSessions => _engine.completedSessions;
  PomodoroSettings get _settings => _engine.settings;
  TimeType get _timeType => _engine.phase;
  String get _totalTime => _engine.totalTimeText;
  String get _getTimeInUse => _engine.phaseLabel;

  @override
  void initState() {
    super.initState();
    _engine = widget.controller ??
        PomodoroViewModel(
            settingsStorage: widget.settingsStorage, now: widget.now);
    _timeController = TextEditingController(text: _engine.timeText);
    _messageVersion = _engine.messageVersion;
    _engine.addListener(_engineChanged);
    if (widget.controller == null) unawaited(_loadSettings());
  }

  void _engineChanged() {
    if (_messageVersion == _engine.messageVersion) return;
    _messageVersion = _engine.messageVersion;
    final message = _engine.message;
    if (message != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showAppMessage(context, message);
      });
    }
  }

  Future<void> _loadSettings() => _engine.load();

  Future<void> _openSettings() => showAdaptiveSheet<void>(
      context: context,
      builder: (_) => PomodoroSettingsSheet(
          settings: _settings, onSave: _engine.updateSettings));

  @override
  void dispose() {
    _engine.removeListener(_engineChanged);
    if (widget.controller == null) _engine.dispose();
    _timeController.dispose();
    super.dispose();
  }

  void _setPomodoroTime() => _engine.select(TimeType.pomodoro);
  void _setShortBreak() => _engine.select(TimeType.short);
  void _setLongBreak() => _engine.select(TimeType.long);
  void _startCountdown() => _engine.start();
  void _stopCountdown() => _engine.pause();
  void _resetTime() => _engine.reset();

  void _chooseTask() {
    final tasks = widget.tasksController;
    if (tasks == null) return;
    showAdaptiveSheet<void>(
        context: context,
        builder: (sheetContext) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: ListenableBuilder(
                  listenable: tasks,
                  builder: (context, _) => SingleChildScrollView(
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text('Tarefa para focar',
                                  style:
                                      Theme.of(context).textTheme.titleLarge),
                              AdaptiveButton.text(
                                  onPressed: () {
                                    _engine.selectTask(null);
                                    Navigator.pop(sheetContext);
                                  },
                                  child: const Text('Focar sem tarefa')),
                              if (tasks.pending.isEmpty)
                                const Text(
                                    'Adicione uma tarefa pendente na sua lista.'),
                              for (final task in tasks.pending)
                                AdaptiveButton.text(
                                    onPressed: () {
                                      _engine.selectTask(task);
                                      Navigator.pop(sheetContext);
                                    },
                                    child: Text(task.title)),
                            ]),
                      )),
            ));
  }

  String get _linkedTaskTitle =>
      _engine.linkedTaskTitle(widget.tasksController);

  Future<void> _openModalEditing(BuildContext context) async {
    _timeController.text = _totalTime;

    final seconds = await showAdaptiveSheet<int>(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, updateModal) {
          final seconds =
              PomodoroViewModel.parseCustomTime(_timeController.text);
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 16.0,
              right: 16.0,
              top: 16.0,
            ),
            child: Container(
              constraints: BoxConstraints(minHeight: 180.0),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AdaptiveTextField(
                      controller: _timeController,
                      onChanged: (_) => updateModal(() {}),
                      keyboardType: TextInputType.number,
                      inputFormatters: [TimeInputFormatter()],
                      decoration: InputDecoration(
                        labelText: "Definir tempo",
                        errorText: seconds != null
                            ? null
                            : "Use MM:SS, com segundos até 59 e tempo maior que zero",
                        labelStyle: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 2.0,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 30.0),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: AdaptiveButton(
                            onPressed: () {
                              FocusScope.of(context).unfocus();
                              Navigator.of(context).pop();
                            },
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              foregroundColor:
                                  Theme.of(context).colorScheme.onSurface,
                            ),
                            child: Text(
                              'Cancelar',
                            ),
                          ),
                        ),
                        SizedBox(width: 8.0),
                        Expanded(
                          child: AdaptiveButton(
                            onPressed: seconds != null
                                ? () {
                                    FocusScope.of(context).unfocus();
                                    Navigator.of(context).pop(seconds);
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              backgroundColor:
                                  Theme.of(context).colorScheme.primary,
                            ),
                            child: Text(
                              'Definir',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        });
      },
    );
    if (!mounted || seconds == null) return;
    _engine.select(TimeType.custom, seconds: seconds);
  }

  Widget _preset(String label, TimeType type, VoidCallback select) {
    final colors = Theme.of(context).colorScheme;
    final selected = _timeType == type;
    final activeBackground =
        usesCupertino(context) ? colors.primaryContainer : colors.primary;
    final activeForeground =
        usesCupertino(context) ? colors.onPrimaryContainer : colors.onPrimary;
    return Expanded(
      child: AdaptiveButton(
        onPressed: _isRunning ? null : select,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              selected ? activeBackground : colors.surfaceContainerLow,
          foregroundColor:
              selected ? activeForeground : colors.onSurfaceVariant,
          disabledBackgroundColor:
              selected ? activeBackground : colors.surfaceContainerLow,
          disabledForegroundColor:
              selected ? activeForeground : colors.onSurfaceVariant,
          side:
              BorderSide(color: selected ? colors.primary : Colors.transparent),
        ),
        child: Text(label,
            style: TextStyle(
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: Listenable.merge([
        _engine,
        if (widget.tasksController != null) widget.tasksController!
      ]),
      builder: (context, _) => _buildPage(context));

  Widget _buildPage(BuildContext context) {
    return AdaptivePage(
      title: 'Pomodoro',
      contentMaxWidth: 1040,
      trailing: AdaptiveIconButton(
        cupertinoSize: 24,
        tooltip: 'Configurar Pomodoro',
        icon: Icons.tune,
        cupertinoIcon: CupertinoIcons.slider_horizontal_3,
        onPressed: _isRunning || _loadingSettings || _settingsLoadFailed
            ? null
            : _openSettings,
      ),
      body: _loadingSettings
          ? const Center(child: AdaptiveLoading())
          : _settingsLoadFailed
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Não foi possível carregar as configurações.'),
                  AdaptiveButton.text(
                      onPressed: _loadSettings,
                      child: const Text('Tentar novamente')),
                ]))
              : SafeArea(child: _responsiveFocus(context)),
    );
  }

  List<Widget> _taskControls(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return [
      if (widget.tasksController != null)
        AdaptiveButton.text(
          onPressed: _engine.canChooseTask ? _chooseTask : null,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(
                usesCupertino(context)
                    ? CupertinoIcons.scope
                    : Icons.track_changes,
                size: 18),
            const SizedBox(width: 8),
            Flexible(
                child: Text(_linkedTaskTitle,
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
        ),
      if (_engine.error != null)
        Row(children: [
          Expanded(
              child:
                  Text(_engine.error!, style: TextStyle(color: colors.error))),
          AdaptiveButton.text(
              onPressed: _engine.retrySave,
              child: const Text('Tentar novamente')),
        ]),
    ];
  }

  Widget _clock() => CircularProgress(
      progress: _engine.remainingSeconds / 60,
      totalTime: _engine.totalSeconds / 60);

  List<Widget> _phaseDetails(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: colors.secondaryContainer,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(_getTimeInUse,
            style: TextStyle(
              color: colors.onSecondaryContainer,
              fontWeight: FontWeight.w600,
            )),
      ),
      const SizedBox(height: 12),
      Text(
          'Sessões de foco: $_completedSessions de ${_settings.sessionsBeforeLongBreak}',
          style: Theme.of(context).textTheme.bodyMedium),
    ];
  }

  List<Widget> _sessionControls(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return [
      const SizedBox(height: 20),
      Row(children: [
        _preset(
            'Definir tempo', TimeType.custom, () => _openModalEditing(context)),
        const SizedBox(width: 8),
        _preset('Pomodoro', TimeType.pomodoro, _setPomodoroTime),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        _preset('Pausa curta', TimeType.short, _setShortBreak),
        const SizedBox(width: 8),
        _preset('Pausa longa', TimeType.long, _setLongBreak),
      ]),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(
            child: AdaptiveButton(
          onPressed: _isDefinedTime
              ? (_isRunning ? _stopCountdown : _startCountdown)
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor:
                _isRunning ? colors.secondaryContainer : colors.primary,
            foregroundColor:
                _isRunning ? colors.onSecondaryContainer : colors.onPrimary,
          ),
          child: Text(_isRunning
              ? 'Parar'
              : _isStopped
                  ? 'Continuar'
                  : 'Iniciar'),
        )),
        if (_isStopped) ...[
          const SizedBox(width: 8),
          Expanded(
              child: AdaptiveButton(
            onPressed: _resetTime,
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.surfaceContainerHighest,
              foregroundColor: colors.onSurface,
            ),
            child: const Text('Reiniciar'),
          )),
        ],
      ]),
      const SizedBox(height: 16),
    ];
  }

  Widget _responsiveFocus(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth >= 840;
        final width = wide ? 1040.0 : 560.0;
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: width),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: LayoutBuilder(
                builder: (context, inner) => SingleChildScrollView(
                  key: const ValueKey('focus-scroll'),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: inner.maxHeight),
                    child: wide
                        ? Row(
                            key: const ValueKey('focus-wide-layout'),
                            children: [
                              Expanded(
                                  child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                      width: 280,
                                      height: 280,
                                      child: FittedBox(child: _clock())),
                                  const SizedBox(height: 24),
                                  ..._phaseDetails(context),
                                ],
                              )),
                              const SizedBox(width: 48),
                              Expanded(
                                  child: Column(
                                key: const ValueKey('focus-controls'),
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ..._taskControls(context),
                                  ..._sessionControls(context),
                                ],
                              )),
                            ],
                          )
                        : IntrinsicHeight(
                            child: Column(children: [
                            ..._taskControls(context),
                            Expanded(
                                child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 220),
                              child: Center(child: FittedBox(child: _clock())),
                            )),
                            ..._phaseDetails(context),
                            ..._sessionControls(context),
                          ])),
                  ),
                ),
              ),
            ),
          ),
        );
      });
}
