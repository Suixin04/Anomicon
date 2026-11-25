import 'dart:io';

import 'package:anomicon/src/anomicon_app.dart';
import 'package:anomicon/src/local_store.dart';
import 'package:anomicon/src/models.dart';
import 'package:anomicon/src/repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<LocalStore> openApp(WidgetTester tester, Size surface) async {
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    final store = await LocalStore.create();
    await store.saveSettings(const AppSettings(hapticEnabled: false));
    await tester.pumpWidget(
      AnomiconApp(repository: _FixtureRepository(), localStore: store),
    );
    await tester.pumpAndSettle();
    return store;
  }

  Finder terminalDestination(Type navigation) =>
      find.descendant(of: find.byType(navigation), matching: find.text('终端'));

  Future<void> openSettings(WidgetTester tester, Type navigation) async {
    await tester.tap(terminalDestination(navigation));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
  }

  ColorScheme settingsColors(WidgetTester tester) =>
      Theme.of(tester.element(find.byType(SettingsScreen))).colorScheme;

  double contrast(Color foreground, Color background) {
    final a = foreground.computeLuminance();
    final b = background.computeLuminance();
    return a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05);
  }

  testWidgets('settings apply and persist light, dark and system themes', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final store = await openApp(tester, const Size(400, 800));
    await openSettings(tester, NavigationBar);
    expect(settingsColors(tester).brightness, Brightness.dark);

    await tester.tap(find.text('浅色'));
    await tester.pumpAndSettle();
    final light = settingsColors(tester);
    expect(light.brightness, Brightness.light);
    expect(store.loadSettings().themeMode, ThemeModePreference.light);
    expect(
      contrast(light.onSurfaceVariant, light.surfaceContainer),
      greaterThanOrEqualTo(4.5),
    );

    await tester.tap(find.text('深色'));
    await tester.pumpAndSettle();
    final dark = settingsColors(tester);
    expect(dark.brightness, Brightness.dark);
    expect(dark.surface, isNot(light.surface));
    expect(
      contrast(dark.onSurfaceVariant, dark.surfaceContainer),
      greaterThanOrEqualTo(4.5),
    );
    expect(store.loadSettings().themeMode, ThemeModePreference.dark);

    await tester.tap(find.text('跟随系统'));
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pumpAndSettle();
    expect(settingsColors(tester).brightness, Brightness.light);
    expect(store.loadSettings().themeMode, ThemeModePreference.system);
  });

  testWidgets('wide detail and compact back share the same route stack', (
    tester,
  ) async {
    await openApp(tester, const Size(1000, 800));
    await openSettings(tester, NavigationRail);
    expect(find.byType(TerminalScreen), findsOneWidget);
    expect(find.byType(SettingsScreen), findsOneWidget);
    final primary = tester.getRect(find.byType(TerminalScreen));
    final details = tester.getRect(find.byType(SettingsScreen));
    expect(primary.right, lessThanOrEqualTo(details.left));

    await tester.ensureVisible(find.text('三维档案馆'));
    await tester.tap(find.text('三维档案馆'));
    await tester.pumpAndSettle();
    expect(find.byType(ArchiveGalleryScreen), findsOneWidget);

    await tester.binding.setSurfaceSize(const Size(440, 800));
    await tester.pumpAndSettle();
    expect(find.byType(ArchiveGalleryScreen), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(TerminalScreen), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsNothing);
    expect(find.byType(TerminalScreen), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      HomeTab.terminal.index,
    );
  });
}

class _FixtureRepository extends Fake implements AnomiconRepository {
  @override
  Future<ExploreHomeData> loadExplore({DateTime? date}) async =>
      const ExploreHomeData();

  @override
  Future<File?> installedArchiveAsset(ArchiveAsset asset) async => null;
}
