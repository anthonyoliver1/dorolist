import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'adaptive.dart';

class ThemePreference extends InheritedWidget {
  const ThemePreference({
    super.key,
    required this.mode,
    required this.onChanged,
    required super.child,
  });

  final ThemeMode mode;
  final Future<void> Function(ThemeMode) onChanged;

  static ThemePreference? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ThemePreference>();

  @override
  bool updateShouldNotify(ThemePreference oldWidget) =>
      mode != oldWidget.mode || onChanged != oldWidget.onChanged;
}

class ThemeOptionsButton extends StatelessWidget {
  const ThemeOptionsButton({super.key});

  static const _labels = {
    ThemeMode.system: 'Sistema',
    ThemeMode.light: 'Claro',
    ThemeMode.dark: 'Escuro',
  };

  @override
  Widget build(BuildContext context) {
    final preference = ThemePreference.maybeOf(context);
    if (preference == null) return const SizedBox.shrink();

    return AdaptiveIconButton(
      tooltip: 'Tema',
      icon: Icons.brightness_6_outlined,
      cupertinoIcon: CupertinoIcons.circle_lefthalf_fill,
      cupertinoSize: 24,
      onPressed: () async {
        final mode = await showAdaptiveSheet<ThemeMode>(
          context: context,
          builder: (sheetContext) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Tema',
                    textAlign: TextAlign.center,
                    style: Theme.of(sheetContext).textTheme.titleLarge),
                const SizedBox(height: 8),
                for (final option in _labels.entries)
                  Semantics(
                    selected: option.key == preference.mode,
                    child: AdaptiveButton.text(
                      onPressed: () => Navigator.pop(sheetContext, option.key),
                      child: Row(
                        children: [
                          Expanded(child: Text(option.value)),
                          if (option.key == preference.mode)
                            const Icon(Icons.check, size: 20),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
        if (mode == null || !context.mounted) return;
        try {
          await preference.onChanged(mode);
        } catch (_) {
          if (!context.mounted) return;
          showAppMessage(context, 'Não foi possível salvar o tema.');
        }
      },
    );
  }
}
