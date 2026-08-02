import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agentrix_health/presentation/providers/account_provider.dart';
import 'package:agentrix_health/presentation/providers/app_stage_provider.dart';
import 'package:agentrix_health/presentation/providers/user_profile_provider.dart';
import 'package:agentrix_health/presentation/screens/main/profile_screen.dart';

/// Sign-out is the one control that can strand a user outside a mandatory
/// gate, so both halves are pinned: it asks first, and it does not leave the
/// previous account's profile behind for the next person to inherit.

Future<void> _openSettings(
  WidgetTester tester,
  ProviderContainer container,
) async {
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: ProfileScreen())),
    ),
  );
  // The Apple Health section kicks off the synthetic provider, which simulates
  // latency with timers. Drain them, or the test ends with work outstanding.
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();

  // Account is the last section, below the fold at this surface size.
  await tester.drag(find.byType(ListView), const Offset(0, -4000));
  await tester.pumpAndSettle();
}

ProviderContainer _signedIn() => ProviderContainer(
  overrides: [
    accountStatusProvider.overrideWithValue(
      const AccountStatus(
        kind: SessionKind.account,
        email: 'someone@example.com',
        providerIds: ['apple.com'],
      ),
    ),
  ],
);

void main() {
  testWidgets('settings shows the account and a way out of it', (tester) async {
    // Wider than a phone on purpose. The reference-range segmented control
    // further down the screen sizes itself to its labels, and the fallback font
    // used when google_fonts cannot fetch is wide enough to overflow it at
    // phone widths — an artefact of the test environment, not of this section.
    await tester.binding.setSurfaceSize(const Size(760, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final container = _signedIn();
    await _openSettings(tester, container);

    expect(find.text('someone@example.com'), findsOneWidget);
    expect(find.text('Signed in with Apple'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
  });

  testWidgets('sign out asks before it acts, and cancel is a no-op', (
    tester,
  ) async {
    // Wider than a phone on purpose. The reference-range segmented control
    // further down the screen sizes itself to its labels, and the fallback font
    // used when google_fonts cannot fetch is wide enough to overflow it at
    // phone widths — an artefact of the test environment, not of this section.
    await tester.binding.setSurfaceSize(const Size(760, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final container = _signedIn();
    await _openSettings(tester, container);

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(find.text('Sign out?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Still in the app, not bounced to the gate.
    expect(container.read(appStageProvider), isNot(AppStage.account));
  });

  test('a signed-out session does not carry the profile into the next one', () {
    // Firebase is unreachable in a unit test, so this exercises the piece that
    // matters and is testable: the reset the controller performs. Without it
    // the next anonymous uid — the one the next sign-in links onto — inherits
    // whatever the previous user had typed.
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(userProfileProvider.notifier).setName('Previous User');
    expect(container.read(userProfileProvider).name, 'Previous User');

    container.read(userProfileProvider.notifier).reset();

    expect(container.read(userProfileProvider).name, isEmpty);
  });
}
