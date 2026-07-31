import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/fade_in.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../../core/widgets/screen_back_button.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/surface_card.dart';
import '../../../domain/entities/nutrition/meal_entry.dart';
import '../../../domain/entities/nutrition/nutrition_targets.dart';
import '../../../features/nutrition/patterns.dart';
import '../../providers/main_tab_provider.dart';
import '../../providers/nutrition_providers.dart';
import '../../widgets/nutrition/macro_summary.dart';
import 'dining_screen.dart';
import 'log_meal_screen.dart';
import 'main_shell.dart';

/// Mirrors `app/(tabs)/food.tsx`.
///
/// Today at the top, the week's patterns underneath. Ordered that way because
/// logging is a today-shaped activity and analysis is a week-shaped one — putting
/// the weekly chart first would push the primary action below the fold on every
/// launch.
class FoodLogScreen extends ConsumerWidget {
  const FoodLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final targets = ref.watch(nutritionTargetsProvider);

    // Targets need height, weight and age. Without them every number on this
    // screen would be invented, so the screen asks for them instead of guessing.
    if (targets == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space6),
          child: EmptyState(
            icon: Icons.restaurant_outlined,
            title: 'Tell us a little about you first',
            body: 'Calorie and macro targets need your height, weight and age. '
                'It takes about thirty seconds.',
            actionLabel: 'Complete your profile',
            onAction: () =>
                ref.read(mainTabProvider.notifier).select(MainTab.settings),
          ),
        ),
      );
    }

    final meals = ref.watch(todayMealsProvider);
    final consumed = ref.watch(consumedTodayProvider);
    final water = ref.watch(hydrationTodayProvider);
    final week = ref.watch(weeklyNutritionProvider);
    final isCheatDay = ref.watch(cheatDayProvider);
    final remaining = targets.calories - consumed.calories;

    return ListView(
      padding: EdgeInsets.only(
        top: AppSpacing.space1,
        bottom: MainShell.bottomInsetFor(context),
      ),
      children: [
        // HEADER
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const ScreenBackButton(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today',
                      style: AppTextStyles.cardMeta.copyWith(
                        fontSize: 11,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Food',
                      style: AppTextStyles.h3.copyWith(fontSize: 25),
                    ),
                  ],
                ),
              ),
              _CheatDayToggle(
                active: isCheatDay,
                onTap: () => ref.read(cheatDayProvider.notifier).toggle(),
              ),
            ],
          ),
        ),

        // TODAY'S BUDGET
        _Section(
          delay: 40,
          child: SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  spacing: AppSpacing.space4,
                  children: [
                    CalorieRing(
                      consumed: consumed.calories,
                      target: targets.calories,
                      // The component defaults to 152; Food asks for 132 so the
                      // macro bars beside it keep their full width.
                      size: 132,
                    ),
                    Expanded(
                      child: MacroBars(
                        consumed: consumed,
                        targets: targets.macros,
                        sugarCeilingG: targets.addedSugarCeilingG,
                      ),
                    ),
                  ],
                ),
                Container(
                  margin: const EdgeInsets.only(top: AppSpacing.space3),
                  padding: const EdgeInsets.only(top: AppSpacing.space3),
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: AppColors.hairline),
                    ),
                  ),
                  child: Text(
                    '${targets.energyBasis == EnergyBasis.measured ? 'Target built from what your watch measured you burn this week.' : 'Target estimated from your profile — it sharpens once your watch has a week of data.'}'
                    '${targets.isCheatDay ? ' Cheat day is on: +15% calories.' : ''}',
                    style: AppTextStyles.cardMeta.copyWith(
                      fontSize: 11,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // WATER
        _Section(
          delay: 100,
          child: SurfaceCard(
            child: WaterTracker(
              ml: water,
              targetMl: targets.waterMl,
              onAdd: (amount) =>
                  ref.read(mealLogProvider.notifier).addWater(amount),
            ),
          ),
        ),

        // LOG ACTIONS
        _Section(
          delay: 160,
          child: Row(
            spacing: AppSpacing.space3,
            children: [
              Expanded(
                child: AppButton(
                  label: 'Log a meal',
                  leading: const Icon(Icons.add, size: 16),
                  onPressed: () => MainShell.push(context, const LogMealScreen()),
                ),
              ),
              Expanded(
                child: AppButton(
                  label: 'Eat out',
                  variant: AppButtonVariant.secondary,
                  leading: const Icon(Icons.place_outlined, size: 15),
                  onPressed: () =>
                      MainShell.push(context, const DiningScreen()),
                ),
              ),
            ],
          ),
        ),

        // TODAY'S MEALS
        _Section(
          delay: 220,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(
                title: "Today's meals",
                count: meals.length,
                actionLabel: remaining > 0 ? '$remaining kcal left' : null,
              ),
              if (meals.isEmpty)
                SurfaceCard(
                  child: EmptyState(
                    icon: Icons.restaurant_outlined,
                    tone: EmptyStateTone.onCard,
                    title: 'Nothing logged yet',
                    body: 'Photograph your plate or pick from the food list — it '
                        'takes a couple of taps and it is what makes the weekly '
                        'patterns work.',
                    actionLabel: 'Log your first meal',
                    onAction: () => MainShell.push(context, const LogMealScreen()),
                  ),
                )
              else
                SurfaceCard(
                  padded: false,
                  child: Column(
                    children: [
                      for (final meal in meals)
                        _MealRow(meal: meal, isLast: meal == meals.last),
                    ],
                  ),
                ),
            ],
          ),
        ),

        // WEEKLY PATTERNS
        _Section(
          delay: 280,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(title: 'This week', count: week.patterns.length),
              if (week.isSparse)
                SurfaceCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: AppSpacing.space3,
                    children: [
                      const Icon(
                        Icons.trending_up,
                        size: 18,
                        color: AppColors.faint,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${week.loggedDays} of 7 days logged',
                              style: AppTextStyles.cardTitle.copyWith(
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Pattern analysis needs at least three days '
                              'before it says anything — three clean days and '
                              'four heavy ones average out to “fine”, which is '
                              'exactly the conclusion worth avoiding.',
                              style: AppTextStyles.cardBody.copyWith(
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else if (week.patterns.isEmpty)
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nothing to flag this week',
                        style: AppTextStyles.cardTitle.copyWith(fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Across ${week.loggedDays} logged days, no macro, '
                        'sugar, sodium or timing pattern crossed a threshold '
                        'worth mentioning.',
                        style: AppTextStyles.cardBody.copyWith(height: 1.45),
                      ),
                    ],
                  ),
                )
              else
                SurfaceCard(
                  padded: false,
                  child: Column(
                    children: [
                      for (final pattern in week.patterns)
                        _PatternRow(
                          pattern: pattern,
                          isLast: pattern == week.patterns.last,
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        // WEEK AVERAGES
        if (!week.isSparse)
          _Section(
            delay: 340,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionHeader(
                  title: 'Daily average',
                  actionLabel: '${week.loggedDays} logged days',
                ),
                SurfaceCard(child: _AverageGrid(week: week)),
              ],
            ),
          ),

        // DINING CTA
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.space5,
            AppSpacing.space6,
            AppSpacing.space5,
            0,
          ),
          child: PressableScale(
            scaleTo: 0.99,
            semanticLabel: 'See restaurant recommendations',
            onTap: () => MainShell.push(context, const DiningScreen()),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.space4,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.hairline),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                spacing: AppSpacing.space2 + 2,
                children: [
                  const Icon(
                    Icons.place_outlined,
                    size: 17,
                    color: AppColors.brand,
                  ),
                  Expanded(
                    child: Text(
                      remaining > 200
                          ? 'Eating out? $remaining kcal left today'
                          : 'Find somewhere to eat nearby',
                      style: AppTextStyles.cardTitle.copyWith(fontSize: 13),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: AppColors.faint,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.child, this.delay = 0});

  final Widget child;
  final int delay;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space5,
        AppSpacing.space4,
        AppSpacing.space5,
        0,
      ),
      child: FadeIn(delay: Duration(milliseconds: delay), child: child),
    );
  }
}

/// Cheat day is an explicit choice, never inferred — so it is a switch with a
/// visible on state rather than something the app decides for the user.
class _CheatDayToggle extends StatelessWidget {
  const _CheatDayToggle({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: active,
      label: 'Cheat day',
      hint: 'Raises your calorie target by 15% and stops down-ranking '
          'indulgent food',
      child: PressableScale(
        scaleTo: 0.97,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space3,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: active ? AppColors.limeSoft : AppColors.surface,
            border: Border.all(
              color: active ? AppColors.limeStrong : AppColors.hairline,
            ),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: [
              Icon(
                Icons.cake_outlined,
                size: 14,
                color: active ? AppColors.ink : AppColors.faint,
              ),
              Text(
                'Cheat day',
                style: AppTextStyles.cardMeta.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: active ? AppColors.ink : AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MealRow extends ConsumerWidget {
  const _MealRow({required this.meal, required this.isLast});

  final MealEntry meal;
  final bool isLast;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final macros = meal.macros;

    return Semantics(
      label: '${meal.slot.label}: ${meal.summary}',
      hint: 'Long press to remove',
      child: InkWell(
        onLongPress: () => _confirmRemove(context, ref),
        child: Container(
          decoration: BoxDecoration(
            border: isLast
                ? null
                : const Border(bottom: BorderSide(color: AppColors.hairline)),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space4,
            vertical: 14,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: AppSpacing.space3,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      spacing: AppSpacing.space2,
                      children: [
                        Text(
                          meal.slot.label.toUpperCase(),
                          style: AppTextStyles.tag.copyWith(
                            fontSize: 9,
                            letterSpacing: 0.5,
                            color: AppColors.brand600,
                          ),
                        ),
                        Text(
                          DateFormat('h:mm a').format(meal.loggedAt),
                          style: AppTextStyles.cardMeta.copyWith(fontSize: 10),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      meal.summary,
                      style: AppTextStyles.cardTitle.copyWith(fontSize: 14),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${macros.proteinG.round()}P · ${macros.carbsG.round()}C '
                      '· ${macros.fatG.round()}F · '
                      '${macros.fibreG.round()} g fibre',
                      style: AppTextStyles.cardMeta,
                    ),
                    if (meal.source != MealSource.database) ...[
                      const SizedBox(height: 4),
                      Text(
                        meal.source.label,
                        style: AppTextStyles.cardMeta.copyWith(
                          fontSize: 10,
                          color: AppColors.faint,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                '${macros.calories} kcal',
                style: AppTextStyles.h6.copyWith(
                  letterSpacing: 0,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove this meal?'),
        content: Text(meal.summary),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(mealLogProvider.notifier).remove(meal.id);
    }
  }
}

class _PatternRow extends StatelessWidget {
  const _PatternRow({required this.pattern, required this.isLast});

  final NutritionPattern pattern;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final colour = pattern.tone == PatternTone.concern
        ? AppColors.abnormal
        : AppColors.optimal;

    return Container(
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: AppColors.hairline)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space4,
        vertical: 14,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            spacing: AppSpacing.space2,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: colour,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
              Expanded(
                child: Text(
                  pattern.title,
                  style: AppTextStyles.cardTitle.copyWith(
                    fontSize: 14,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 14, top: 4),
            child: Text(
              pattern.detail,
              style: AppTextStyles.cardBody.copyWith(height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _AverageGrid extends StatelessWidget {
  const _AverageGrid({required this.week});

  final WeeklyNutritionSummary week;

  @override
  Widget build(BuildContext context) {
    final averages = week.averages;
    final stats = <(String, String)>[
      ('Calories', '${averages.calories}'),
      ('Protein', '${averages.proteinG.round()} g'),
      ('Carbs', '${averages.carbsG.round()} g'),
      ('Fat', '${averages.fatG.round()} g'),
      ('Fibre', '${averages.fibreG.round()} g'),
      ('Added sugar', '${averages.addedSugarG.round()} g'),
    ];

    return Wrap(
      children: [
        for (final stat in stats)
          FractionallySizedBox(
            widthFactor: 1 / 3,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.space2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stat.$1.toUpperCase(),
                    style: AppTextStyles.tag.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: AppColors.faint,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    stat.$2,
                    style: AppTextStyles.metricSmall.copyWith(fontSize: 17),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
