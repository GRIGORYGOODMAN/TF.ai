import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tf_ai/main.dart';

void main() {
  testWidgets('renders empty start state', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const TfAiApp());
    await tester.pumpAndSettle();

    expect(find.text('New character'), findsOneWidget);
    expect(find.text('Message'), findsNothing);
    expect(find.byIcon(Icons.send), findsNothing);
  });

  testWidgets('creates a character from empty start state', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const TfAiApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('New character'));
    await tester.pumpAndSettle();

    expect(find.text('Create character'), findsOneWidget);
    expect(find.text('Memory'), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'Test character');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();

    expect(find.text('Test character'), findsOneWidget);
    expect(find.text('Message'), findsOneWidget);
    expect(find.byIcon(Icons.send), findsOneWidget);
  });

  testWidgets('creates a public character locally first', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const TfAiApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('New character'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Public test');
    await tester.tap(find.text('Public'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Create public'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(find.text('Public test'), findsAtLeastNWidgets(1));
    expect(find.text('Message'), findsOneWidget);
  });
}
