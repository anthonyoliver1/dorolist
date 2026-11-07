import 'package:doro_list/components/adaptive.dart';
import 'package:doro_list/components/navigation_bottom_bar.dart';
import 'package:doro_list/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets(
        'page, tabs and keyboard consume system insets once on $platform',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(950, 669);
      const insets = FakeViewPadding(top: 24, left: 60, right: 20, bottom: 34);
      tester.view.padding = insets;
      tester.view.viewPadding = insets;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);
      addTearDown(tester.view.resetViewInsets);
      const probe = ValueKey('safe-body');
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.lightTheme.copyWith(platform: platform),
          home: NavigationBottomBar(pages: const [
            AdaptivePage(
                title: 'Área segura',
                contentMaxWidth: 1120,
                body: SizedBox.expand(key: probe)),
            SizedBox(),
            SizedBox(),
          ])));
      await tester.pumpAndSettle();
      final body = tester.getRect(find.byKey(probe));
      expect(body.left, 60);
      expect(body.right, 930);
      expect(body.top, platform == TargetPlatform.iOS ? 68 : 80);
      final bar = tester.getRect(find.byType(
          platform == TargetPlatform.iOS ? CupertinoTabBar : NavigationBar));
      // The content ends at the app bar, with no second home-indicator gap.
      expect(body.bottom, closeTo(bar.top, 0.1));
      if (platform == TargetPlatform.iOS) {
        expect(bar.left, 60);
        expect(bar.right, 930);
      }
      for (final label in ['Tarefas', 'Foco', 'Resumo']) {
        final rect = tester.getRect(find.text(label));
        expect(rect.left, greaterThanOrEqualTo(60));
        expect(rect.right, lessThanOrEqualTo(930));
        expect(rect.bottom, lessThanOrEqualTo(635));
      }
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      tester.view.padding = const FakeViewPadding(top: 24, left: 60, right: 20);
      await tester.pumpAndSettle();
      final keyboardBody = tester.getRect(find.byKey(probe));
      expect(keyboardBody.bottom, closeTo(669 - 280, 0.1));
      expect(keyboardBody.left, 60);
      expect(tester.takeException(), isNull);
    });

    testWidgets('modal controls respect side and bottom insets on $platform',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(950, 669);
      const insets = FakeViewPadding(top: 24, left: 60, right: 20, bottom: 34);
      tester.view.padding = insets;
      tester.view.viewPadding = insets;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.lightTheme.copyWith(platform: platform),
          home: AdaptivePage(
              title: 'Modal',
              body: Builder(
                  builder: (context) => Center(
                      child: AdaptiveButton(
                          onPressed: () => showAdaptiveSheet<void>(
                              context: context,
                              builder: (_) => const SizedBox(
                                  key: ValueKey('sheet-controls'),
                                  width: double.infinity,
                                  height: 100)),
                          child: const Text('Abrir')))))));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      final controls =
          tester.getRect(find.byKey(const ValueKey('sheet-controls')));
      expect(controls.left, greaterThanOrEqualTo(60));
      expect(controls.right, lessThanOrEqualTo(930));
      expect(controls.bottom, closeTo(669 - 34, 0.1));
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('iOS notice avoids lateral cutouts and the keyboard',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(950, 669);
    tester.view.padding =
        const FakeViewPadding(left: 60, right: 20, bottom: 34);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme.copyWith(platform: TargetPlatform.iOS),
        home: AdaptivePage(
            title: 'Mensagem',
            body: Builder(
                builder: (context) => Center(
                    child: AdaptiveButton(
                        onPressed: () => showAppMessage(context, 'Salvo'),
                        child: const Text('Mostrar')))))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mostrar'));
    await tester.pump();
    final notice = find.byType(CupertinoPopupSurface);
    expect(tester.getRect(notice).left, 76);
    expect(tester.getRect(notice).right, 914);
    expect(tester.getRect(notice).bottom, lessThan(669 - 34));
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    tester.view.padding = const FakeViewPadding(left: 60, right: 20);
    await tester.pumpAndSettle();
    expect(tester.getRect(notice).bottom, closeTo(669 - 280 - 12, 0.1));
    await tester.tap(find.byIcon(CupertinoIcons.xmark));
    await tester.pumpAndSettle();
    expect(notice, findsNothing);
  });
}
