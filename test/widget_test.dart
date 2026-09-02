// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:plantcare_ai/constants/constants.dart';
import 'package:plantcare_ai/main.dart';

void main() {
  test('uses a green plant-care brand palette', () {
    expect(themeColor, const Color(0xFF2E7D32));
    expect(accentColor, const Color(0xFF66BB6A));
  });

  testWidgets('shows the PlantCare AI home screen', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('PlantCare AI'), findsOneWidget);
    expect(find.text('เลือกรูปภาพ'), findsOneWidget);
    expect(find.text('เปิดกล้อง'), findsOneWidget);
    expect(find.text('เริ่มตรวจสุขภาพพืช'), findsOneWidget);
    expect(find.byIcon(Icons.eco_rounded), findsAtLeastNWidgets(1));
  });
}
