import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/util/units.dart';
import '../../../core/widgets/choice.dart' as choice;
import '../../../domain/entities/profile/diet_pattern.dart';
import '../../../domain/entities/user_profile.dart';
import '../../providers/app_stage_provider.dart';
import '../../providers/user_profile_provider.dart';
import 'onboarding_scaffold.dart';

/// Height, weight, age and activity level. Mirrors `app/onboarding/body.tsx`.
///
/// These four are the entire input to the Mifflin–St Jeor equation, which is
/// what every calorie and macro target downstream is built on. Without them the
/// brief can still describe recovery and blood work, but it cannot prescribe a
/// number — so this screen exists purely to unlock that, and Continue stays
/// disabled until it can.
class BodyScreen extends ConsumerStatefulWidget {
  const BodyScreen({super.key});

  @override
  ConsumerState<BodyScreen> createState() => _BodyScreenState();
}

class _BodyScreenState extends ConsumerState<BodyScreen> {
  double? _heightCm;
  double? _weightKg;
  double? _age;
  ActivityLevel? _activity;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(userProfileProvider);
    _heightCm = profile.heightCm;
    _weightKg = profile.weightKg;
    _age = profile.ageYears?.toDouble();
    _activity = profile.activityLevel;
  }

  /// The profile at [initState] time is whatever [UserProfileNotifier] had
  /// synchronously — which is always the blank default, because the real
  /// value comes from Firestore via `hydrate()` a moment later. Without this,
  /// a returning user who already saved these numbers sees blank fields every
  /// time until they happen to still be in memory from earlier in the session.
  void _adoptFetchedProfile(UserProfile profile) {
    if (_heightCm != null || _weightKg != null || _age != null) return;
    setState(() {
      _heightCm = profile.heightCm;
      _weightKg = profile.weightKg;
      _age = profile.ageYears?.toDouble();
      _activity = profile.activityLevel;
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<UserProfile>(
      userProfileProvider,
      (previous, next) => _adoptFetchedProfile(next),
    );

    final canContinue = _heightCm != null && _weightKg != null && _age != null;
    final activity = _activity ?? ActivityLevel.moderate;

    return OnboardingScaffold(
      stepIndex: 2,
      stepCount: 6,
      title: 'A few numbers about you',
      intro:
          'These four figures are what your calorie, protein and hydration '
          'targets are calculated from. They\'re saved to your account.',
      canContinue: canContinue,
      blockedHint:
          'Set all three to continue — without them we cannot compute '
          'a target.',
      onContinue: () {
        final notifier = ref.read(userProfileProvider.notifier);
        notifier.setBodyComposition(heightCm: _heightCm, weightKg: _weightKg);
        notifier.setAge('${_age!.round()}');
        notifier.setActivityLevel(activity);
        ref.read(appStageProvider.notifier).next();
      },
      children: [
        choice.Stepper(
          label: 'Height',
          unit: '',
          value: _heightCm == null ? null : cmToInches(_heightCm!).roundToDouble(),
          min: 47, // 3'11"
          max: 87, // 7'3"
          fallback: 67, // 5'7"
          formatValue: formatFeetInches,
          onChanged: (value) => setState(() => _heightCm = inchesToCm(value)),
        ),
        choice.Stepper(
          label: 'Weight',
          unit: 'lb',
          value: _weightKg == null ? null : kgToLb(_weightKg!).roundToDouble(),
          min: 75,
          max: 440,
          fallback: 154,
          onChanged: (value) => setState(() => _weightKg = lbToKg(value)),
        ),
        choice.Stepper(
          label: 'Age',
          unit: 'years',
          value: _age,
          min: 16,
          max: 100,
          fallback: 32,
          onChanged: (value) => setState(() => _age = value),
        ),

        const OnboardingLabel(
          'How active are you?',
          detail:
              'Only used until your watch has a week of data — after that '
              'we use what you actually burn instead of this estimate.',
        ),

        for (final level in ActivityLevel.values)
          choice.ChoiceRow(
            label: level.label,
            hint: level.hint,
            selected: activity == level,
            onTap: () => setState(() => _activity = level),
          ),
      ],
    );
  }
}
