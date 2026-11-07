import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:doro_list/components/navigation_bottom_bar.dart';
import 'components/theme_options.dart';
import 'view_models/theme_view_model.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    final license =
        await rootBundle.loadString('assets/fonts/Inter/LICENSE.txt');
    yield LicenseEntryWithLineBreaks(['Inter'], license);
  });
  final theme = ThemeViewModel();
  await theme.load();
  runApp(MyApp(theme: theme));
}

class MyApp extends StatefulWidget {
  const MyApp(
      {super.key, this.initialThemeMode = ThemeMode.system, this.theme});

  final ThemeMode initialThemeMode;
  final ThemeViewModel? theme;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final ThemeViewModel _theme =
      widget.theme ?? ThemeViewModel(mode: widget.initialThemeMode);

  @override
  void dispose() {
    _theme.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _theme,
        builder: (context, _) => ThemePreference(
          mode: _theme.mode,
          onChanged: _theme.select,
          child: MaterialApp(
            title: 'Doro List',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: _theme.mode,
            home: const NavigationBottomBar(),
            debugShowCheckedModeBanner: false,
          ),
        ),
      );
}
