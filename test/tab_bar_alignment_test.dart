import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:agentrix_health/presentation/screens/main/main_shell.dart';

/// Pins the pill tab bar's geometry.
///
/// The slot used to be a Column of icon-then-label, which made the two a single
/// centred block — so the icon sat half the label's height above the bar's
/// middle (7.5px high on a 66px bar) and the three tabs whose labels are
/// invisible had a dead band of white beneath them. The icon is now centred and
/// the label hangs off the bottom edge, which is what these assertions hold.
void main() {
  const tabIcons = <String, IconData>{
    'today': Icons.home_outlined,
    'food': Icons.restaurant_outlined,
    'insights': Icons.insights_outlined,
    'labs': Icons.science_outlined,
  };

  Future<void> pumpShell(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Material(child: MainShell())),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('every tab icon is centred in the bar, not pushed up by its '
      'label', (tester) async {
    await pumpShell(tester);

    for (final entry in tabIcons.entries) {
      final icon = find.byIcon(entry.value);
      // The slot's own box is the full inner height of the bar, so the icon
      // being centred in it is the same statement as being centred in the bar.
      final slot = find
          .ancestor(of: icon, matching: find.byType(SizedBox))
          .first;

      expect(
        tester.getRect(icon).center.dy,
        moreOrLessEquals(tester.getRect(slot).center.dy, epsilon: 0.01),
        reason: '${entry.key} icon is off the bar centre line',
      );
    }
  });

  testWidgets('all four tab icons share one baseline', (tester) async {
    await pumpShell(tester);

    final centres = tabIcons.values
        .map((i) => tester.getRect(find.byIcon(i)).center.dy)
        .toSet();

    expect(
      centres,
      hasLength(1),
      reason: 'tab icons are on ${centres.length} different lines: $centres',
    );
  });

  testWidgets('the centre action is centred and lifted clear of the bar', (
    tester,
  ) async {
    await pumpShell(tester);

    final fab = tester.getRect(find.byIcon(Icons.add));
    final today = tester.getRect(find.byIcon(Icons.home_outlined));
    final labs = tester.getRect(find.byIcon(Icons.science_outlined));

    // The outermost pair straddle the bar's centre, so their midpoint is it.
    expect(
      fab.center.dx,
      moreOrLessEquals((today.center.dx + labs.center.dx) / 2, epsilon: 0.01),
    );

    // `top: -20` on RN's `fabWrapper`.
    expect(
      today.center.dy - fab.center.dy,
      moreOrLessEquals(20, epsilon: 0.01),
    );
  });

  testWidgets('slots either side of the centre action are evenly spaced', (
    tester,
  ) async {
    await pumpShell(tester);

    double cx(IconData i) => tester.getRect(find.byIcon(i)).center.dx;

    final outerLeft = cx(Icons.restaurant_outlined) - cx(Icons.home_outlined);
    final outerRight = cx(Icons.science_outlined) - cx(Icons.insights_outlined);
    final innerLeft = cx(Icons.add) - cx(Icons.restaurant_outlined);
    final innerRight = cx(Icons.insights_outlined) - cx(Icons.add);

    expect(outerLeft, moreOrLessEquals(outerRight, epsilon: 0.01));
    expect(innerLeft, moreOrLessEquals(innerRight, epsilon: 0.01));
  });
}
