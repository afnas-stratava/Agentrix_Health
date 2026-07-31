import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:agentrix_health/domain/entities/gender.dart';
import 'package:agentrix_health/presentation/providers/user_profile_provider.dart';
import 'package:agentrix_health/presentation/screens/main/profile_edit_screen.dart';

/// Guards the fields the profile editor used to have no UI for at all.
///
/// Name, gender and free-text restrictions each had a working setter on
/// `UserProfileNotifier` and zero call sites, so none of them could be changed
/// from anywhere in the app. Gender was the one that mattered beyond cosmetics:
/// it selects the Mifflin-St Jeor constant and the calorie floor in
/// `targets.dart`, so every profile was computed as `UserProfile.initial()`'s
/// default until it became editable.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<ProviderContainer> pumpEditor(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 3400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Material(child: ProfileEditScreen())),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('name typed into the field lands on the profile', (tester) async {
    final container = await pumpEditor(tester);

    expect(container.read(userProfileProvider).name, isEmpty);

    await tester.enterText(find.byType(TextFormField).first, 'Nazeem');
    // `setName` persists on a 500ms debounce; let it fire so the test does not
    // tear the tree down with a timer still in flight.
    await tester.pump(const Duration(milliseconds: 600));

    expect(container.read(userProfileProvider).name, 'Nazeem');
    // The Today header reads this rather than the raw field.
    expect(container.read(userProfileProvider).greetingName, 'Nazeem');
  });

  testWidgets('gender is selectable, not stuck on the default', (tester) async {
    final container = await pumpEditor(tester);

    expect(container.read(userProfileProvider).gender, Gender.female);

    await tester.tap(find.text('Male'));
    await tester.pumpAndSettle();

    expect(container.read(userProfileProvider).gender, Gender.male);
  });

  testWidgets('a free-text restriction can be added and removed', (
    tester,
  ) async {
    final container = await pumpEditor(tester);

    final field = find.widgetWithText(TextFormField, 'e.g. no raw fish');
    await tester.enterText(field, 'no raw fish');
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Add restriction'));
    await tester.pumpAndSettle();

    expect(container.read(userProfileProvider).customRestrictions, [
      'no raw fish',
    ]);

    // Tapping the note's chip clears it — the same gesture as every other chip.
    await tester.tap(find.text('no raw fish'));
    await tester.pumpAndSettle();

    expect(container.read(userProfileProvider).customRestrictions, isEmpty);
  });
}
