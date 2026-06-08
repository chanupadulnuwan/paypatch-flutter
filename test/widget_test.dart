import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paypatch/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('PayPatchApp smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const PayPatchApp());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });
}
