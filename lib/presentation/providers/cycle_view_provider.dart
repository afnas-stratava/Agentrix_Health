import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/gender.dart';
import 'user_profile_provider.dart';

/// Which demo view (female cycle tracker vs. male wellness score) the Cycle
/// tab shows. Seeded from the onboarding gender, then freely toggled via the
/// screen's own F/M demo switch.
class CycleViewNotifier extends Notifier<Gender> {
  @override
  Gender build() => ref.read(userProfileProvider).gender;

  void setFemale() => state = Gender.female;
  void setMale() => state = Gender.male;

  void reset() => state = ref.read(userProfileProvider).gender;
}

final cycleViewProvider = NotifierProvider<CycleViewNotifier, Gender>(
  CycleViewNotifier.new,
);
