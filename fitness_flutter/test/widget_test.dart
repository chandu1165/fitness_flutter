import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fitness_flutter/main.dart';

void main() {
  testWidgets('app boots and renders a MaterialApp', (WidgetTester tester) async {
    await tester.pumpWidget(const FitnessSystemApp());

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
