import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agentrix_health/app.dart';

/// Smoke test: the app boots to onboarding and renders.
///
/// The step-by-step behaviour lives in `onboarding_flow_test.dart`; this only
/// guards against the app failing to come up at all, which is the one failure
/// no other test would catch.
void main() {
  testWidgets('boots to the onboarding welcome screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const ProviderScope(child: AgentrixHealthApp()));
    await tester.pumpAndSettle();

    // The headline is a RichText (two colours in one sentence), which the
    // default text finder skips.
    expect(
      find.textContaining('Your labs.', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Get started'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
