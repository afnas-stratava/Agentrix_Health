import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agentrix_health/app.dart';

void main() {
  testWidgets('Onboarding welcome screen leads into the goal-setup form', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const ProviderScope(child: AgentrixHealthApp()));

    expect(find.text('Agentrix Health'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);

    await tester.tap(find.text('Get started'));
    await tester.pump();

    expect(find.text('Tell us about you'), findsOneWidget);
  });
}
