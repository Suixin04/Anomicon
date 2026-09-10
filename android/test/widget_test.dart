import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anomicon/src/anomicon_app.dart';

void main() {
  testWidgets('renders Harmony-style bottom navigation', (WidgetTester tester) async {
    var selectedTab = HomeTab.explore;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: Material(
              color: Colors.transparent,
              child: GlassBottomBar(
                selectedTab: selectedTab,
                onSelectTab: (tab) => selectedTab = tab,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('探索'), findsOneWidget);
    expect(find.text('图鉴'), findsOneWidget);
    expect(find.text('故事'), findsOneWidget);
    expect(find.text('终端'), findsOneWidget);

    await tester.tap(find.text('图鉴'));
    await tester.pump();

    expect(selectedTab, HomeTab.catalog);
  });
}
