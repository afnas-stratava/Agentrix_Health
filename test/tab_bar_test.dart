import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agentrix_health/presentation/screens/main/main_shell.dart';

/// The selected tab used to render its label conditionally, which made the icon
/// jump the moment you tapped and left the selected slot taller than its
/// neighbours. These two properties are what stop that regressing: every label
/// is always laid out, and selecting a tab moves nothing.
void main() {
  Future<void> pumpShell(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const ProviderScope(
        // Mirrors `_ResponsiveRoot` in `app.dart`, which is where the shell gets
        // its Material in production.
        child: MaterialApp(
          home: Material(type: MaterialType.transparency, child: MainShell()),
        ),
      ),
    );
    // Long enough for the 180ms selection transition to land.
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('every tab label is laid out, selected or not', (tester) async {
    await pumpShell(tester);

    for (final label in const ['TODAY', 'FOOD', 'INSIGHTS', 'RECORDS']) {
      expect(find.text(label), findsOneWidget, reason: '$label must be present');
    }
  });

  testWidgets('selecting a tab does not move the bar', (tester) async {
    await pumpShell(tester);

    Offset centreOf(IconData icon) => tester.getCenter(find.byIcon(icon));

    final insightsBefore = centreOf(Icons.insights_outlined);
    final todayBefore = centreOf(Icons.home_outlined);

    await tester.tap(find.byIcon(Icons.insights_outlined));
    await tester.pump(const Duration(milliseconds: 400));

    expect(centreOf(Icons.insights_outlined), insightsBefore);
    expect(centreOf(Icons.home_outlined), todayBefore);
  });

  testWidgets('the four icons share one baseline', (tester) async {
    await pumpShell(tester);

    final ys = <double>[
      for (final icon in const [
        Icons.home_outlined,
        Icons.restaurant_outlined,
        Icons.insights_outlined,
        Icons.science_outlined,
      ])
        tester.getCenter(find.byIcon(icon)).dy,
    ];

    // The active slot must not sit higher or lower than the inactive ones.
    expect(ys.every((y) => (y - ys.first).abs() < 0.01), isTrue, reason: '$ys');
  });
}
