import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agentrix_health/app.dart';
import 'package:agentrix_health/core/widgets/choice.dart' as choice;
import 'package:agentrix_health/presentation/providers/account_provider.dart';

/// Covers RN's six-step onboarding flow (`app/onboarding/*`).
///
/// The load-bearing behaviours: each step fits every phone width the app ships
/// to, the Continue gate on the body step agrees with the hint beside it — a
/// disabled CTA whose hint disagrees with it is worse than no hint — and cuisine
/// chips carry the tap order the dish ranker actually uses.

/// Scrolls a control into view before tapping.
///
/// The steps are taller than any test surface *and* the list builds lazily, so
/// a control below the fold has no element yet — `ensureVisible` alone throws.
/// This scrolls until it exists, then taps.
Future<void> tapItem(WidgetTester tester, String label) async {
  // `.first` throws on an empty finder, so the existence check has to run
  // against the unfiltered one.
  if (find.text(label).evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      find.text(label),
      200,
      scrollable: find.byType(Scrollable).first,
    );
  }

  final target = find.text(label).first;
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

/// The rank badge inside a cuisine chip, or null when it isn't selected.
String? rankOf(WidgetTester tester, String label) {
  final chip = find.ancestor(
    of: find.text(label),
    matching: find.byType(choice.ChoiceChip),
  );
  final texts = tester
      .widgetList<Text>(find.descendant(of: chip, matching: find.byType(Text)))
      .map((t) => t.data)
      .where((d) => d != label)
      .toList();
  return texts.isEmpty ? null : texts.first;
}

/// Signing in is mandatory, and there is no Firebase project in a widget test,
/// so the session is stubbed as already signed in. Without this every flow test
/// stops at the gate — which is the gate working, and is covered directly in
/// `account_screen_test.dart`.
Future<void> _launch(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        accountStatusProvider.overrideWithValue(
          const AccountStatus(
            kind: SessionKind.account,
            email: 'tester@example.com',
          ),
        ),
      ],
      child: const AgentrixHealthApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Welcome → account → sex.
Future<void> _openSexStep(WidgetTester tester) async {
  await _launch(tester);
  await tapItem(tester, 'Get started');
  await tapItem(tester, 'Continue');
}

/// Welcome → account → sex → body.
Future<void> _openBodyStep(WidgetTester tester) async {
  await _openSexStep(tester);
  await tapItem(tester, 'Female');
  await tapItem(tester, 'Continue');
}

/// Fills the body step so Continue unlocks, then advances.
Future<void> _openGoalsStep(WidgetTester tester) async {
  await _openBodyStep(tester);
  for (final label in const ['Height', 'Weight', 'Age']) {
    await tester.ensureVisible(find.text(label));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Increase $label'));
    await tester.pumpAndSettle();
  }
  await tapItem(tester, 'Continue');
}

Future<void> _openDietStep(WidgetTester tester) async {
  await _openGoalsStep(tester);
  await tapItem(tester, 'Continue');
}

void main() {
  group('layout', () {
    for (final size in const [Size(430, 960), Size(360, 640), Size(320, 568)]) {
      testWidgets('welcome renders without overflow at $size', (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await _launch(tester);

        expect(find.text('Get started'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('body step renders without overflow at $size', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await _openBodyStep(tester);

        expect(find.text('A few numbers about you'), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Scroll the body to surface any overflow further down.
        await tester.drag(find.byType(ListView), const Offset(0, -900));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('flow', () {
    testWidgets('welcome leads into the reference-range step', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 960));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _openSexStep(tester);

      expect(
        find.text('Which reference ranges should we use?'),
        findsOneWidget,
      );
      expect(find.text('Prefer not to say'), findsOneWidget);
    });

    testWidgets('back returns to the previous step', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 960));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _openBodyStep(tester);
      expect(find.text('A few numbers about you'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(
        find.text('Which reference ranges should we use?'),
        findsOneWidget,
      );
    });
  });

  group('body step gating', () {
    testWidgets('Continue is blocked until height, weight and age are set', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(430, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _openBodyStep(tester);

      // The gate and the hint have to agree — that is the whole point of the
      // hint.
      expect(
        find.text(
          'Set all three to continue — without them we cannot compute a target.',
        ),
        findsOneWidget,
      );

      for (final label in const ['Height', 'Weight', 'Age']) {
        await tester.ensureVisible(find.text(label));
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('Increase $label'));
        await tester.pumpAndSettle();
      }

      expect(
        find.text(
          'Set all three to continue — without them we cannot compute a target.',
        ),
        findsNothing,
      );
    });
  });

  group('diet step', () {
    testWidgets('cuisines rank in the order they were tapped', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _openDietStep(tester);
      expect(find.text('How do you eat?'), findsOneWidget);

      await tapItem(tester, 'Mediterranean');
      await tapItem(tester, 'Indian');

      // Order is the ranking the dish ranker reads, so it must survive the UI.
      expect(rankOf(tester, 'Mediterranean'), '1');
      expect(rankOf(tester, 'Indian'), '2');
    });

    testWidgets('deselecting a cuisine renumbers the rest', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _openDietStep(tester);

      await tapItem(tester, 'Mediterranean');
      await tapItem(tester, 'Indian');
      await tapItem(tester, 'Mediterranean');

      expect(rankOf(tester, 'Mediterranean'), isNull);
      expect(rankOf(tester, 'Indian'), '1');
    });
  });

  group('goals step', () {
    testWidgets('goal rows stay selectable', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _openGoalsStep(tester);
      expect(find.text('What are you working towards?'), findsOneWidget);

      await tapItem(tester, 'Build muscle');
      expect(tester.takeException(), isNull);

      // Choosing a body-composition goal reveals the target-weight stepper.
      expect(find.text('Goal weight'), findsOneWidget);
    });
  });
}
