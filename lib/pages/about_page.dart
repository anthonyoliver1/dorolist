import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../components/adaptive.dart';
import '../view_models/about_view_model.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  static Uri get portfolioUrl => AboutViewModel.portfolioUrl;

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  final _viewModel = AboutViewModel();

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _openPortfolio() async {
    final opened = await _viewModel.openPortfolio();
    if (opened || !mounted) return;
    showAppMessage(
        context, 'Não foi possível abrir o portfólio. Tente novamente.');
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return AdaptivePage(
      title: 'Sobre o app',
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset('assets/icon/doro-focus-rounded.png',
                        width: 96, height: 96, excludeFromSemantics: true),
                  ),
                  const SizedBox(height: 24),
                  Text('Doro List',
                      style: text.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colors.onSurface)),
                  const SizedBox(height: 8),
                  Text('Seu tempo, uma tarefa de cada vez.',
                      textAlign: TextAlign.center,
                      style: text.bodyLarge
                          ?.copyWith(color: colors.onSurfaceVariant)),
                  const SizedBox(height: 16),
                  ListenableBuilder(
                      listenable: _viewModel,
                      builder: (context, _) => FutureBuilder<String>(
                            future: _viewModel.version,
                            builder: (context, snapshot) {
                              if (snapshot.hasError) {
                                return AdaptiveButton.text(
                                  onPressed: _viewModel.retryVersion,
                                  child: const Text(
                                      'Tentar carregar a versão novamente'),
                                );
                              }
                              final version = snapshot.data;
                              if (version == null) {
                                return Text('Carregando versão…',
                                    style: text.bodySmall);
                              }
                              return Text(
                                version,
                                style: text.bodySmall
                                    ?.copyWith(color: colors.onSurfaceVariant),
                              );
                            },
                          )),
                  const SizedBox(height: 48),
                  Text('Desenvolvido por', style: text.bodyMedium),
                  const SizedBox(height: 4),
                  Semantics(
                    link: true,
                    child: Tooltip(
                      message: 'Abrir portfólio de Anthony Oliveira',
                      child: AdaptiveButton.text(
                        onPressed: _openPortfolio,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Anthony Oliveira'),
                            SizedBox(width: 8),
                            Icon(
                                usesCupertino(context)
                                    ? CupertinoIcons.arrow_up_right_square
                                    : Icons.open_in_new,
                                size: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
