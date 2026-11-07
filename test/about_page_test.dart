import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:doro_list/pages/about_page.dart';
import 'package:doro_list/pages/home_page.dart';
import 'package:doro_list/pages/summary_page.dart';
import 'package:doro_list/controllers/activity_journal.dart';
import 'package:doro_list/components/navigation_bottom_bar.dart';
import 'support/memory_productivity.dart';
import 'package:doro_list/models/task.dart';
import 'package:doro_list/services/task_storage.dart';

class _EmptyStorage extends TaskStorage {
  @override
  Future<List<Task>> read() async => [];
}

void main() {
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'Doro List',
      packageName: 'com.example.doro_list',
      version: '2.3.4',
      buildNumber: '42',
      buildSignature: '',
    );
  });

  testWidgets(
      'summary opens About with installed version and developer credits',
      (tester) async {
    final journal = ActivityJournal(storage: MemoryJson());
    addTearDown(journal.dispose);
    await journal.load();
    await tester.pumpWidget(MaterialApp(
        home: NavigationBottomBar(pages: [
      MyHomePage(storage: _EmptyStorage()),
      const SizedBox(),
      SummaryPage(journal: journal),
    ])));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Sobre o app'), findsNothing);
    await tester.tap(find.text('Resumo'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Sobre o app'));
    await tester.pumpAndSettle();
    expect(find.text('Doro List'), findsOneWidget);
    expect(find.text('Versão 2.3.4'), findsOneWidget);
    expect(find.text('Desenvolvido por'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Anthony Oliveira'), findsOneWidget);
    expect(AboutPage.portfolioUrl.toString(),
        'https://by-anthony-oliveira.vercel.app/');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Resumo do dia'), findsOneWidget);
  });

  testWidgets('failed portfolio launch shows feedback without closing About',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AboutPage()));
    await tester.pumpAndSettle();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/url_launcher'),
      (_) async => false,
    );
    addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
              const MethodChannel('plugins.flutter.io/url_launcher'),
              null,
            ));
    await tester.tap(find.text('Anthony Oliveira'));
    await tester.pumpAndSettle();
    expect(find.text('Não foi possível abrir o portfólio. Tente novamente.'),
        findsOneWidget);
    expect(find.text('Sobre o app'), findsOneWidget);
  });
}
