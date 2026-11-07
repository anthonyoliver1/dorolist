import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'adaptive.dart';
import '../models/pomodoro_settings.dart';
import '../view_models/pomodoro_settings_view_model.dart';

class PomodoroSettingsSheet extends StatefulWidget {
  const PomodoroSettingsSheet(
      {super.key, required this.settings, required this.onSave});

  final PomodoroSettings settings;
  final Future<void> Function(PomodoroSettings) onSave;

  @override
  State<PomodoroSettingsSheet> createState() => _PomodoroSettingsSheetState();
}

class _PomodoroSettingsSheetState extends State<PomodoroSettingsSheet> {
  late final _viewModel =
      PomodoroSettingsViewModel(widget.settings, widget.onSave);

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (await _viewModel.save() && mounted) Navigator.of(context).pop();
  }

  Widget _selector(int index, String label, int maximum,
      {bool minutes = true}) {
    final step = minutes ? 5 : 1;
    if (usesCupertino(context)) {
      String labelFor(int value) => minutes
          ? '$value min'
          : '$value ${value == 1 ? 'sessão' : 'sessões'}';
      return CupertinoListTile(
        title: Text(label),
        additionalInfo: Text(labelFor(_viewModel.valueAt(index))),
        trailing: const CupertinoListTileChevron(),
        onTap: _viewModel.saving
            ? null
            : () async {
                final selected = await showCupertinoValuePicker(
                  context: context,
                  title: label,
                  values: [
                    for (var value = step; value <= maximum; value += step)
                      value
                  ],
                  value: _viewModel.valueAt(index),
                  label: labelFor,
                );
                if (mounted && selected != null) {
                  _viewModel.select(index, selected);
                }
              },
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<int>(
        key: ValueKey('pomodoro-setting-$index-${_viewModel.valueAt(index)}'),
        initialValue: _viewModel.valueAt(index),
        isExpanded: true,
        menuMaxHeight: 280,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: [
          for (var value = step; value <= maximum; value += step)
            DropdownMenuItem(
                value: value,
                child: Text(minutes
                    ? '$value min'
                    : '$value ${value == 1 ? 'sessão' : 'sessões'}')),
        ],
        onChanged: _viewModel.saving
            ? null
            : (value) {
                if (value != null) {
                  _viewModel.select(index, value);
                }
              },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) => PopScope(
          canPop: !_viewModel.saving,
          child: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                  20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Configurar Pomodoro',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  const Text(
                      'Ajuste o ritmo de foco e descanso. Salvar inicia um novo ciclo.'),
                  const SizedBox(height: 24),
                  _selector(0, 'Tempo de foco', 180),
                  _selector(1, 'Pausa curta', 60),
                  _selector(2, 'Pausa longa', 90),
                  _selector(3, 'Sessões antes da pausa longa', 30,
                      minutes: false),
                  if (usesCupertino(context))
                    CupertinoListTile(
                      title: const Text('Iniciar automaticamente'),
                      subtitle: const Text('Avançar para a próxima etapa.'),
                      trailing: CupertinoSwitch(
                        value: _viewModel.autoStart,
                        activeTrackColor: Theme.of(context).colorScheme.primary,
                        onChanged:
                            _viewModel.saving ? null : _viewModel.setAutoStart,
                      ),
                    )
                  else
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title:
                          const Text('Iniciar próxima etapa automaticamente'),
                      subtitle: const Text(
                          'Se desativado, a próxima etapa aguarda o botão Iniciar.'),
                      value: _viewModel.autoStart,
                      onChanged:
                          _viewModel.saving ? null : _viewModel.setAutoStart,
                    ),
                  if (_viewModel.error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_viewModel.error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                    ),
                  AdaptiveButton.text(
                      onPressed:
                          _viewModel.saving ? null : _viewModel.restoreDefaults,
                      child: const Text('Restaurar padrão (25 / 5 / 15 / 4)')),
                  const SizedBox(height: 8),
                  AdaptiveButton(
                      onPressed: _viewModel.saving ? null : _save,
                      child: Text(_viewModel.saving
                          ? 'Salvando…'
                          : 'Salvar configurações')),
                ],
              ),
            ),
          ),
        ),
      );
}
