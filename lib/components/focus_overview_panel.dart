import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../view_models/pomodoro_view_model.dart';
import 'adaptive.dart';

/// A companion to the task list, driven by the same timer as the Focus tab.
class FocusOverviewPanel extends StatelessWidget {
  const FocusOverviewPanel({super.key, required this.timer, this.onOpenFocus});

  final PomodoroViewModel timer;
  final VoidCallback? onOpenFocus;

  @override
  Widget build(BuildContext context) {
    final summary = timer.summary;
    return ListenableBuilder(
        listenable: Listenable.merge([timer, summary]),
        builder: (context, _) {
          final colors = Theme.of(context).colorScheme;
          final day = summary?.today;
          final unavailable = timer.loading || timer.loadFailed;
          return SingleChildScrollView(
            key: const ValueKey('focus-overview-panel'),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('SEU FOCO',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.6,
                        color: colors.onSurfaceVariant)),
                const SizedBox(height: 24),
                Icon(
                    usesCupertino(context)
                        ? CupertinoIcons.timer
                        : Icons.timer_outlined,
                    size: 28,
                    color: colors.primary),
                const SizedBox(height: 16),
                Text(timer.phaseLabel,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: colors.primary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                if (timer.loading)
                  const Center(child: AdaptiveLoading())
                else if (timer.loadFailed)
                  const Text('Não foi possível carregar a sessão.',
                      textAlign: TextAlign.center)
                else ...[
                  Text(timer.timeText,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 44,
                          fontWeight: FontWeight.w500,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: colors.onSurface)),
                  const SizedBox(height: 8),
                  Text(
                      timer.running
                          ? 'Em andamento'
                          : timer.stopped
                              ? 'Em pausa'
                              : 'Pronto para começar',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 13, color: colors.onSurfaceVariant)),
                ],
                const SizedBox(height: 24),
                Text(timer.taskTitle ?? 'Foco sem tarefa',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: colors.onSurface)),
                if (timer.error != null) ...[
                  const SizedBox(height: 12),
                  Text(timer.error!, style: TextStyle(color: colors.error)),
                ],
                const SizedBox(height: 20),
                AdaptiveButton(
                    onPressed: unavailable || timer.remainingSeconds <= 0
                        ? null
                        : timer.running
                            ? timer.pause
                            : timer.start,
                    child: Text(timer.running
                        ? 'Pausar'
                        : timer.stopped
                            ? 'Continuar'
                            : 'Iniciar')),
                if (timer.stopped) ...[
                  const SizedBox(height: 8),
                  AdaptiveButton.text(
                      onPressed: timer.reset, child: const Text('Reiniciar')),
                ],
                if (onOpenFocus != null)
                  AdaptiveButton.text(
                      onPressed: onOpenFocus,
                      child: Text(timer.canChooseTask && timer.taskId == null
                          ? 'Escolher tarefa e ajustar foco'
                          : 'Abrir Foco')),
                const SizedBox(height: 24),
                Divider(color: colors.outlineVariant, thickness: 0.5),
                const SizedBox(height: 24),
                Text('SEU DIA',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.6,
                        color: colors.onSurfaceVariant)),
                const SizedBox(height: 16),
                if (summary != null && day != null && summary.loaded) ...[
                  _metric(context, '${day.completed}', 'Tarefas concluídas'),
                  _metric(context, '${day.seconds ~/ 60} min', 'Tempo de foco'),
                  _metric(
                      context, '${day.sessions.length}', 'Sessões concluídas'),
                  if (summary.error != null)
                    Text(summary.error!, style: TextStyle(color: colors.error)),
                ] else if (summary?.error != null)
                  Text(summary!.error!, style: TextStyle(color: colors.error))
                else if (summary != null)
                  const Center(child: AdaptiveLoading())
                else
                  const Text('Seu resumo estará disponível na aba Resumo.'),
              ],
            ),
          );
        });
  }

  Widget _metric(BuildContext context, String value, String label) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant))),
        const SizedBox(width: 12),
        Text(value,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary)),
      ]));
}
