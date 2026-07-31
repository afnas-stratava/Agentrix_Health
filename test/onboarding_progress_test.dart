import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agentrix_health/presentation/screens/onboarding/onboarding_scaffold.dart';

void main() {
  testWidgets('shows onboarding progress text', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: OnboardingScaffold(
              title: 'Test step',
              stepIndex: 2,
              stepCount: 6,
              children: [],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Step 2 of 6'), findsOneWidget);
  });
}
