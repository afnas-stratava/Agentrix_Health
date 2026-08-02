import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agentrix_health/presentation/providers/account_provider.dart';
import 'package:agentrix_health/presentation/providers/app_stage_provider.dart';
import 'package:agentrix_health/presentation/screens/onboarding/account_screen.dart';

/// The account step is the app's only gate: no account, no app. These tests
/// pin both halves of that — that it cannot be walked past, and that it gets
/// out of the way the moment a session exists.

Future<void> _pump(WidgetTester tester, ProviderContainer container) async {
  addTearDown(container.dispose);
  // The screen is pumped on its own rather than driven through the whole flow,
  // so the stage has to be put where the switcher would have put it.
  container.read(appStageProvider.notifier).go(AppStage.account);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: AccountScreen())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('cannot be walked past without an account', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final container = ProviderContainer();
    await _pump(tester, container);

    // Apple's button is iOS/macOS only, and tests run on the host platform, so
    // only Google's is guaranteed. Both are gated by the same widget.
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // The disabled Continue says why, rather than being missing.
    expect(
      find.text('Choose a sign-in method above to continue.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(container.read(appStageProvider), AppStage.account);
  });

  testWidgets('collapses to a confirmation once signed in', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final container = ProviderContainer(
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
    await _pump(tester, container);

    expect(find.text('You’re signed in'), findsOneWidget);
    expect(find.text('someone@example.com'), findsOneWidget);
    expect(find.text('Continue with Google'), findsNothing);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(container.read(appStageProvider), AppStage.sex);
  });

  group('describeAuthError', () {
    test('translates the collision Firebase reports most often', () {
      final message = describeAuthError(
        FirebaseAuthException(code: 'account-exists-with-different-credential'),
      );
      expect(message, contains('different sign-in method'));
    });

    test('names the console step behind operation-not-allowed', () {
      final message = describeAuthError(
        FirebaseAuthException(code: 'operation-not-allowed'),
      );
      expect(message, contains('not enabled'));
    });

    test('falls back rather than leaking a raw exception', () {
      expect(describeAuthError(StateError('boom')), isNot(contains('boom')));
    });
  });
}
