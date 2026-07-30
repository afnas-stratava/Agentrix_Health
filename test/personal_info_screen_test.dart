import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agentrix_health/app.dart';
import 'package:agentrix_health/core/widgets/selectable_chip.dart';

/// Covers onboarding step 1 (`PersonalInfoScreen`): the form fits every phone
/// width the app ships to, and the Continue gate matches the hint shown next
/// to it — a disabled CTA whose hint disagrees with it is worse than no hint.
/// Scrolls a control into view before tapping it — the form is taller than
/// any test surface, so a bare tap() would miss whatever is below the fold.
Future<void> tapItem(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

/// The rank badge inside a cuisine chip, or null when it isn't selected.
String? rankOf(WidgetTester tester, String label) {
  final chip = find.ancestor(
    of: find.text(label),
    matching: find.byType(SelectableChip),
  );
  final badges = find.descendant(of: chip, matching: find.byType(Text));
  final texts = tester
      .widgetList<Text>(badges)
      .map((t) => t.data)
      .where((d) => d != label)
      .toList();
  return texts.isEmpty ? null : texts.first;
}

Future<void> _openForm(WidgetTester tester) async {
  await tester.pumpWidget(const ProviderScope(child: AgentrixHealthApp()));
  await tester.tap(find.text('Get started'));
  await tester.pumpAndSettle();
}

void main() {
  for (final size in const [Size(430, 960), Size(360, 640), Size(320, 568)]) {
    testWidgets('renders without overflow at $size', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      // Disposed at the end of the body: the framework verifies handles
      // before tear-downs run.
      final semantics = tester.ensureSemantics();
      await _openForm(tester);

      expect(find.text('Tell us about you'), findsOneWidget);
      // The step track is visual only; its meaning lives in semantics.
      expect(find.bySemanticsLabel('Step 1 of 3'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Scroll the whole body to surface any overflow further down.
      await tester.drag(
        find.byType(SingleChildScrollView).last,
        const Offset(0, -900),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      semantics.dispose();
    });
  }

  testWidgets('continue gating + age validation', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _openForm(tester);

    expect(find.text('Add your name and age to continue.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'Sam');
    await tester.pumpAndSettle();
    expect(find.text('Add your age to continue.'), findsOneWidget);

    // Digits-only + range guard.
    await tester.enterText(find.byType(TextFormField).at(1), '9ab9');
    await tester.pumpAndSettle();
    expect(find.text('99'), findsOneWidget); // formatter strips the letters
    expect(find.text('Add your age to continue.'), findsNothing);

    await tester.enterText(find.byType(TextFormField).at(1), '999');
    await tester.pumpAndSettle();
    expect(find.text("That age doesn't look right."), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(1), '34');
    await tester.pumpAndSettle();
    expect(find.text('Add your age to continue.'), findsNothing);
    expect(find.text("That age doesn't look right."), findsNothing);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Tell us about you'), findsNothing);
  });

  testWidgets('custom restriction add button', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _openForm(tester);

    final field = find.widgetWithText(Column, 'Something else to avoid');
    await tester.scrollUntilVisible(
      field.first,
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).last, 'shellfish');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.text('shellfish'), findsOneWidget);
    // Restriction count badge next to the ALLERGIES micro-label.
    expect(find.text('1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cuisines rank in the order they were tapped', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _openForm(tester);

    // The footer only reports optional progress once the required pair is in.
    await tester.enterText(find.byType(TextFormField).first, 'Sam');
    await tester.enterText(find.byType(TextFormField).at(1), '34');
    await tester.pumpAndSettle();

    await tapItem(tester, 'Mexican');
    await tapItem(tester, 'Indian');

    // Mexican was first, so it keeps rank 1 even though Indian is listed
    // before it — the badges track tap order, not enum order.
    expect(rankOf(tester, 'Mexican'), '1');
    expect(rankOf(tester, 'Indian'), '2');
    expect(find.text('2 cuisines selected.'), findsOneWidget);

    // Deselecting the first pick promotes the other.
    await tapItem(tester, 'Mexican');
    expect(rankOf(tester, 'Indian'), '1');
    expect(find.text('1 cuisine selected.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('goal rows stay selectable', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _openForm(tester);

    await tapItem(tester, 'Build muscle');
    expect(tester.takeException(), isNull);
  });
}
