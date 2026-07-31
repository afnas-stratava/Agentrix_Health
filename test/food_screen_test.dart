import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:agentrix_health/core/widgets/surface_card.dart';
import 'package:agentrix_health/presentation/providers/user_profile_provider.dart';
import 'package:agentrix_health/presentation/screens/main/food_log_screen.dart';
import 'package:agentrix_health/presentation/widgets/nutrition/macro_summary.dart';

/// Guards the Food tab against regressing to the pre-port layout.
///
/// It once had a dark "EATEN TODAY" hero with four macro columns and a single
/// wide button. RN's `app/(tabs)/food.tsx` is a calorie ring beside five macro
/// bars, a glass-grid water tracker, and a two-button row — these assertions
/// pin the parts that actually differ between the two.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpFood(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // Targets need height, weight and age — without them the screen correctly
    // shows the "tell us about you" prompt instead of the layout under test.
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(userProfileProvider.notifier)
      ..setAge('34')
      ..setBodyComposition(heightCm: 178, weightKg: 78);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Material(child: FoodLogScreen())),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('header is "Today / Food" with a cheat-day pill', (tester) async {
    await pumpFood(tester);

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('Cheat day'), findsOneWidget);

    // The old layout's title.
    expect(find.text('Food log'), findsNothing);
  });

  testWidgets('leads with a calorie ring, not a dark macro-column hero', (
    tester,
  ) async {
    await pumpFood(tester);

    expect(find.byType(CalorieRing), findsOneWidget);
    expect(find.text('KCAL LEFT'), findsOneWidget);
    expect(find.text('EATEN TODAY'), findsNothing);
  });

  testWidgets('shows five macro bars including added sugar', (tester) async {
    await pumpFood(tester);

    for (final label in const [
      'Protein',
      'Carbs',
      'Fat',
      'Fibre',
      'Added sugar',
    ]) {
      expect(find.text(label), findsOneWidget, reason: '$label bar missing');
    }
    expect(find.byType(MacroBar), findsNWidgets(5));
  });

  testWidgets('water is a glass grid with two quick-add buttons', (
    tester,
  ) async {
    await pumpFood(tester);

    expect(find.byType(WaterTracker), findsOneWidget);
    expect(find.text('Water'), findsOneWidget);
    expect(find.text('+250 ml'), findsOneWidget);
    expect(find.text('+500 ml'), findsOneWidget);
  });

  testWidgets('offers both Log a meal and Eat out', (tester) async {
    await pumpFood(tester);

    expect(find.text('Log a meal'), findsOneWidget);
    expect(find.text('Eat out'), findsOneWidget);
  });

  testWidgets('meals section is present and uses the shared card', (
    tester,
  ) async {
    await pumpFood(tester);

    expect(find.text("Today's meals".toUpperCase()), findsOneWidget);
    expect(find.byType(SurfaceCard), findsWidgets);
  });
}
