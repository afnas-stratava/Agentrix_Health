import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agentrix_health/core/config/app_info.dart';
import 'package:agentrix_health/presentation/providers/account_provider.dart';
import 'package:agentrix_health/presentation/screens/main/about_screen.dart';
import 'package:agentrix_health/presentation/screens/main/profile_screen.dart';

/// The About rows are a submission requirement, not decoration: App Review
/// wants a reachable privacy policy linked from inside the app, and a way to
/// contact a human. These tests pin that they are actually present and that the
/// data disclosure says the thing that makes it worth having.

Future<void> _openSettings(WidgetTester tester) async {
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
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: ProfileScreen())),
    ),
  );
  // The Apple Health section drives the synthetic provider, which simulates
  // latency with timers. Drain them or the test ends with work outstanding.
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();

  // About sits near the bottom, well below the fold.
  await tester.drag(find.byType(ListView), const Offset(0, -4000));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('settings carries the four standard about rows', (tester) async {
    // Wider than a phone on purpose: the reference-range segmented control
    // higher up the screen sizes itself to its labels, and the fallback font
    // used when google_fonts cannot fetch overflows it at phone widths. An
    // artefact of the test environment, not of this section.
    await tester.binding.setSurfaceSize(const Size(760, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _openSettings(tester);

    expect(find.text('About ${AppInfo.appName}'), findsOneWidget);
    expect(find.text('Privacy policy'), findsOneWidget);
    expect(find.text('Terms of service'), findsOneWidget);
    expect(find.text('Contact us'), findsOneWidget);

    // The support address is shown rather than hidden behind the tap, so it can
    // be read (or dictated to someone) without a mail client configured.
    expect(find.text(AppInfo.supportEmail), findsOneWidget);
  });

  testWidgets('the version on show is the one in AppInfo', (tester) async {
    await tester.binding.setSurfaceSize(const Size(760, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _openSettings(tester);

    // Guards the footer against drifting from the About row, which is the
    // failure mode of having had the version written out twice by hand.
    expect(
      find.text('${AppInfo.appName} ${AppInfo.version} · Not a medical device'),
      findsOneWidget,
    );
  });

  group('About screen', () {
    Future<void> pumpAbout(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(760, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AboutScreen())),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('states plainly that it is not a medical device', (
      tester,
    ) async {
      await pumpAbout(tester);

      expect(find.text('NOT A MEDICAL DEVICE'), findsOneWidget);
      expect(
        find.textContaining('does not diagnose'),
        findsOneWidget,
      );
    });

    testWidgets('discloses every path that sends data off the device', (
      tester,
    ) async {
      await pumpAbout(tester);

      expect(find.text('WHAT LEAVES YOUR DEVICE'), findsOneWidget);

      // The disclosure exists for guideline 5.1.3: anything derived from
      // HealthKit that reaches a third party has to be declared somewhere the
      // user can find it. Naming Gemini is the substance of that — a vague
      // "we use cloud services" would not be.
      expect(find.textContaining('Gemini'), findsWidgets);
      expect(find.text('Lab reports you upload'), findsOneWidget);
      expect(find.text('Questions you ask the assistant'), findsOneWidget);
      expect(
        find.text('Your location, while searching for food'),
        findsOneWidget,
      );
    });

    testWidgets('offers the policy, the terms and a support address', (
      tester,
    ) async {
      await pumpAbout(tester);

      expect(find.text('Privacy policy'), findsOneWidget);
      expect(find.text('Terms of service'), findsOneWidget);
      expect(find.text('Contact support'), findsOneWidget);
      expect(find.text('Open-source licences'), findsOneWidget);
    });
  });
}
