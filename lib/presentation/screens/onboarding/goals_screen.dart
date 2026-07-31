import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/choice.dart' as choice;
import '../../../domain/entities/health_goal.dart';
import '../../../domain/entities/profile/diet_pattern.dart';
import '../../providers/app_stage_provider.dart';
import '../../providers/user_profile_provider.dart';
import 'onboarding_scaffold.dart';

/// The goal, and anything being managed. Mirrors `app/onboarding/goals.tsx`.
///
/// The goal sets the calorie offset and the protein floor; conditions tighten
/// the carbohydrate share and the added-sugar ceiling. Both feed the restaurant
/// ranker too, which is why they are asked once here rather than buried in
/// settings.
class GoalsScreen extends ConsumerStatefulWidget {
  const GoalsScreen({super.key});

  @override
  ConsumerState<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends ConsumerState<GoalsScreen> {
  HealthGoal? _goal;
  double? _targetWeight;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(userProfileProvider);
    _goal = profile.goal;
    _targetWeight = profile.targetWeightKg;
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider);
    final goal = _goal ?? profile.goal;
    final wantsTarget =
        goal == HealthGoal.loseWeight || goal == HealthGoal.buildMuscle;

    // Start a realistic distance from where they are rather than at an
    // arbitrary round number.
    final weight = profile.weightKg;
    final fallbackTarget = weight == null
        ? 70.0
        : ((goal == HealthGoal.loseWeight ? weight - 5 : weight + 3) * 2)
                  .round() /
              2;

    return OnboardingScaffold(
      stepIndex: 3,
      stepCount: 6,
      title: 'What are you working towards?',
      intro:
          'This sets your calorie offset and how much protein we hold you '
          'to. You can change it any time.',
      onContinue: () {
        final notifier = ref.read(userProfileProvider.notifier);
        notifier.setGoal(goal);
        if (wantsTarget) {
          notifier.setTargetWeight(_targetWeight ?? fallbackTarget);
        }
        ref.read(appStageProvider.notifier).next();
      },
      children: [
        for (final option in HealthGoal.values)
          choice.ChoiceRow(
            label: option.label,
            hint: option.hint,
            selected: goal == option,
            onTap: () => setState(() => _goal = option),
          ),

        if (wantsTarget) ...[
          const OnboardingLabel('Target weight'),
          choice.Stepper(
            label: 'Goal weight',
            unit: 'kg',
            value: _targetWeight,
            min: 35,
            max: 200,
            step: 0.5,
            fallback: fallbackTarget,
            onChanged: (value) => setState(() => _targetWeight = value),
          ),
        ],

        const OnboardingLabel(
          'Anything you are managing?',
          detail:
              'Optional. If you pick something here we tighten the relevant '
              'targets — carbohydrate share for glucose, sugar and sodium '
              'ceilings — and factor it into food recommendations. We do not '
              'treat it as a diagnosis.',
        ),
        choice.ChipGroup(
          children: [
            for (final condition in Condition.values)
              choice.ChoiceChip(
                label: condition.label,
                selected: profile.conditions.contains(condition),
                onTap: () => ref
                    .read(userProfileProvider.notifier)
                    .toggleCondition(condition),
              ),
          ],
        ),
      ],
    );
  }
}
