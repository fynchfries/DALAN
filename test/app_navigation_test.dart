import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dalan/app/app.dart';
import 'package:dalan/shared/services/workspace_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('onboarding reaches the five-destination app shell', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: const DalanApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Find your next step.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'Kai');
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Start exploring'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start exploring'));
    await tester.pumpAndSettle();

    expect(find.text('Discover'), findsWidgets);
    expect(find.text('Career'), findsOneWidget);
    expect(find.text('Planner'), findsOneWidget);
    expect(find.text('Skills'), findsOneWidget);
    expect(find.text('Network'), findsOneWidget);

    await tester.tap(find.text('Career').last);
    await tester.pumpAndSettle();
    expect(find.text('Explore what could be next.'), findsOneWidget);
  });
}
