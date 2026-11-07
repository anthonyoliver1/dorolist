import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../components/adaptive.dart';
import '../components/theme_options.dart';
import '../repositories/activity_journal.dart';
import '../models/activity.dart';
import '../view_models/summary_view_model.dart';
import 'about_page.dart';

class SummaryPage extends StatelessWidget {
  const SummaryPage(
      {super.key,
      required ActivityJournal journal,
      DateTime Function() now = DateTime.now})
      : _viewModel = null,
        _journal = journal,
        _now = now;

  const SummaryPage.withViewModel(
      {super.key, required SummaryViewModel viewModel})
      : _viewModel = viewModel,
        _journal = null,
        _now = DateTime.now;

  final ActivityJournal? _journal;
  final DateTime Function() _now;
  final SummaryViewModel? _viewModel;

  @override
  Widget build(BuildContext context) {
    final viewModel = _viewModel ?? SummaryViewModel(_journal!, now: _now);
    return ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) {
          final day = viewModel.today;
          final colors = Theme.of(context).colorScheme;
          final completed = day.completed;
          final records = day.sessions;
          final seconds = day.seconds;
          final overview = <Widget>[
            Text(SummaryViewModel.dateLabel(day.date),
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13)),
            const SizedBox(height: 8),
            Text('Hoje',
                style: TextStyle(
                    fontFamily: 'Georgia',
                    fontFamilyFallback: const ['serif'],
                    fontSize: 44,
                    height: 1.15,
                    letterSpacing: -1.5,
                    fontWeight: FontWeight.w400,
                    color: colors.onSurface)),
            const SizedBox(height: 16),
            Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                      '$completed ${completed == 1 ? 'tarefa concluída' : 'tarefas concluídas'}',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colors.primary)),
                  Text('·', style: TextStyle(color: colors.outline)),
                  Text('${SummaryViewModel.duration(seconds)} de foco',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colors.secondary)),
                ]),
            const SizedBox(height: 8),
            Text(
                '${records.length} ${records.length == 1 ? 'sessão de foco concluída' : 'sessões de foco concluídas'}',
                style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant)),
            if (viewModel.error != null) ...[
              Text(viewModel.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
              AdaptiveButton.text(
                  onPressed: viewModel.retrySave,
                  child: const Text('Tentar salvar novamente')),
            ],
          ];
          final history = <Widget>[
            Text('SESSÕES CONCLUÍDAS HOJE',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.6,
                    color: colors.onSurfaceVariant)),
            const SizedBox(height: 12),
            if (records.isEmpty)
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text('Suas sessões de foco aparecerão aqui.',
                      style: TextStyle(color: colors.onSurfaceVariant))),
            for (final record in records) _session(context, record),
          ];
          return AdaptivePage(
              title: 'Resumo do dia',
              contentMaxWidth: 1120,
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                const ThemeOptionsButton(),
                AdaptiveIconButton(
                    cupertinoSize: 24,
                    tooltip: 'Sobre o app',
                    icon: Icons.info_outline,
                    cupertinoIcon: CupertinoIcons.info,
                    onPressed: () {
                      FocusScope.of(context).unfocus();
                      Navigator.of(context).push(
                          adaptiveRoute(context, (_) => const AboutPage()));
                    }),
              ]),
              body: !viewModel.loaded
                  ? SafeArea(
                      child: Center(
                          child: viewModel.error == null
                              ? const AdaptiveLoading()
                              : Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(viewModel.error!,
                                            textAlign: TextAlign.center),
                                        AdaptiveButton.text(
                                            onPressed: viewModel.retryLoad,
                                            child:
                                                const Text('Tentar novamente')),
                                      ]))))
                  : SafeArea(
                      child: LayoutBuilder(builder: (context, constraints) {
                      const padding = EdgeInsets.fromLTRB(24, 24, 24, 32);
                      if (constraints.maxWidth >= 840) {
                        return Row(
                          key: const ValueKey('summary-wide-layout'),
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                                width: 360,
                                child: ListView(
                                    key: const ValueKey('summary-overview'),
                                    padding: padding,
                                    children: overview)),
                            VerticalDivider(
                                width: 1,
                                thickness: 0.5,
                                color: colors.outlineVariant),
                            Expanded(
                                child: ListView(
                                    key: const ValueKey('summary-history'),
                                    padding: padding,
                                    children: history)),
                          ],
                        );
                      }
                      return Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 760),
                              child: ListView(padding: padding, children: [
                                ...overview,
                                const SizedBox(height: 28),
                                Divider(
                                    height: 1,
                                    color: colors.outlineVariant,
                                    thickness: 0.5),
                                const SizedBox(height: 24),
                                ...history,
                              ])));
                    })));
        });
  }

  Widget _session(BuildContext context, FocusRecord record) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(color: colors.outlineVariant, width: 0.5))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
                usesCupertino(context)
                    ? CupertinoIcons.timer
                    : Icons.timer_outlined,
                size: 20,
                color: colors.primary)),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(record.taskTitle ?? 'Foco sem tarefa',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 16, color: colors.onSurface)),
          const SizedBox(height: 4),
          Text(SummaryViewModel.duration(record.seconds),
              style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant)),
        ])),
        const SizedBox(width: 12),
        Text(SummaryViewModel.sessionTime(record),
            style: TextStyle(
                fontSize: 13,
                color: colors.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()])),
      ]),
    );
  }
}
