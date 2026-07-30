import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/charts/day_column_chart.dart';
import '../../../core/widgets/fade_in.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/util/iso_day.dart';
import '../../../domain/entities/nutrition/macros.dart';
import '../../../domain/entities/nutrition/meal_entry.dart';
import '../../../domain/entities/nutrition/nutrition_targets.dart';
import '../../../features/nutrition/patterns.dart';
import '../../providers/nutrition_providers.dart';
import 'log_meal_sheet.dart';
import 'main_shell.dart';

/// The food log.
///
/// Ordered by what a user actually wants at the moment they open it: what is left
/// today, then what they have logged, then the week's pattern. The pattern is
/// last because it is the only part not actionable in the next ten minutes — and
/// it is a *computed* finding, not a caption.
class FoodLogScreen extends ConsumerWidget {
  const FoodLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meals = ref.watch(todayMealsProvider);
    final consumed = ref.watch(consumedTodayProvider);
    final targets = ref.watch(nutritionTargetsProvider);
    final weekly = ref.watch(weeklyNutritionProvider);
    final water = ref.watch(hydrationTodayProvider);

    return ListView(
      padding: EdgeInsets.only(
        top: AppSpacing.space1,
        bottom: MainShell.bottomInsetFor(context),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat('EEEE, MMMM d').format(DateTime.now()),
                style: AppTextStyles.cardMeta.copyWith(
                  fontSize: 11,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 2),
              Text('Food log', style: AppTextStyles.h3),
            ],
          ),
        ),

        _Section(
          delay: 20,
          child: _MacroSummary(consumed: consumed, targets: targets),
        ),

        _Section(
          delay: 60,
          child: AppButton(
            label: 'Log a meal',
            block: true,
            leading: const Icon(Icons.add, size: 16),
            onPressed: () => showLogMealSheet(context),
          ),
        ),

        _Section(
          delay: 100,
          child: _WaterRow(consumed: water, targetMl: targets?.waterMl),
        ),

        _Section(
          delay: 140,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(title: 'Today', count: meals.length),
              if (meals.isEmpty)
                const _EmptyToday()
              else
                Column(
                  spacing: AppSpacing.space2,
                  children: [
                    for (final meal in meals) _MealCard(meal: meal),
                  ],
                ),
            ],
          ),
        ),

        _Section(delay: 180, child: _WeekCard(weekly: weekly)),

        if (weekly.patterns.isNotEmpty)
          _Section(delay: 220, child: _PatternsCard(weekly: weekly)),
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
        AppSpacing.space5,
        AppSpacing.space5,
        0,
      ),
      child: FadeIn(delay: Duration(milliseconds: delay), child: child),
    );
  }
}

/// Calories left, then the macros against target. "Left" rather than "eaten"
/// because that is the number that changes a decision at 7pm.
class _MacroSummary extends StatelessWidget {
  const _MacroSummary({required this.consumed, required this.targets});

  final Macros consumed;
  final NutritionTargets? targets;

  @override
  Widget build(BuildContext context) {
    final target = targets;
    final remaining = target == null
        ? null
        : target.calories - consumed.calories;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.space5),
      decoration: BoxDecoration(
        color: AppColors.brand900,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            remaining == null
                ? 'EATEN TODAY'
                : (remaining >= 0 ? 'LEFT TODAY' : 'OVER TODAY'),
            style: AppTextStyles.tag.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: AppColors.accent2_400,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            spacing: AppSpacing.space2,
            children: [
              Text(
                '${remaining == null ? consumed.calories : remaining.abs()}',
                style: AppTextStyles.metricLarge.copyWith(
                  color: AppColors.onBrand,
                ),
              ),
              Text(
                'kcal',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.onBrandMuted,
                ),
              ),
            ],
          ),
          if (target != null) ...[
            const SizedBox(height: 4),
            Text(
              '${consumed.calories} of ${target.calories} kcal · '
              '${target.energyBasis == EnergyBasis.measured ? 'measured' : 'estimated'} burn',
              style: AppTextStyles.cardMeta.copyWith(
                color: AppColors.onBrandFaint,
                fontSize: 11,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.space4),
          Row(
            spacing: AppSpacing.space3,
            children: [
              _MacroBar(
                label: 'Protein',
                actual: consumed.proteinG,
                target: target?.macros.proteinG.toDouble(),
              ),
              _MacroBar(
                label: 'Carbs',
                actual: consumed.carbsG,
                target: target?.macros.carbsG.toDouble(),
              ),
              _MacroBar(
                label: 'Fat',
                actual: consumed.fatG,
                target: target?.macros.fatG.toDouble(),
              ),
              _MacroBar(
                label: 'Fibre',
                actual: consumed.fibreG,
                target: target?.macros.fibreG.toDouble(),
              ),
            ],
          ),
          if (target != null) ...[
            const SizedBox(height: AppSpacing.space3),
            _SugarLine(
              consumed: consumed.addedSugarG,
              ceiling: target.addedSugarCeilingG,
            ),
          ],
        ],
      ),
    );
  }
}

class _MacroBar extends StatelessWidget {
  const _MacroBar({
    required this.label,
    required this.actual,
    required this.target,
  });

  final String label;
  final double actual;
  final double? target;

  @override
  Widget build(BuildContext context) {
    final goal = target;
    final fraction = goal == null || goal <= 0
        ? 0.0
        : (actual / goal).clamp(0.0, 1.0);

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: AppTextStyles.tag.copyWith(
              fontSize: 9,
              letterSpacing: 0.8,
              color: AppColors.onBrandFaint,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            goal == null
                ? '${actual.round()} g'
                : '${actual.round()}/${goal.round()}',
            style: AppTextStyles.bodySmall.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.onBrand,
            ),
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: SizedBox(
              height: 4,
              child: ColoredBox(
                color: AppColors.onBrand.withValues(alpha: 0.15),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: fraction,
                  child: const ColoredBox(color: AppColors.accent2_400),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Added sugar gets a line rather than a fifth bar: it is a *ceiling*, not a
/// target, and rendering it like the others would imply filling it is the goal.
class _SugarLine extends StatelessWidget {
  const _SugarLine({required this.consumed, required this.ceiling});

  final double consumed;
  final int ceiling;

  @override
  Widget build(BuildContext context) {
    final over = consumed > ceiling;

    return Row(
      spacing: AppSpacing.space2,
      children: [
        Icon(
          over ? Icons.warning_amber_rounded : Icons.check_circle_outline,
          size: 13,
          color: over ? AppColors.borderline : AppColors.accent2_400,
        ),
        Expanded(
          child: Text(
            over
                ? 'Added sugar ${consumed.round()} g — over your $ceiling g ceiling'
                : 'Added sugar ${consumed.round()} of $ceiling g ceiling',
            style: AppTextStyles.cardMeta.copyWith(
              fontSize: 11,
              color: AppColors.onBrandMuted,
            ),
          ),
        ),
      ],
    );
  }
}

class _WaterRow extends ConsumerWidget {
  const _WaterRow({required this.consumed, required this.targetMl});

  final int consumed;
  final int? targetMl;

  static const _glassMl = 250;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = targetMl ?? 2500;
    final fraction = (consumed / target).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space4,
        vertical: AppSpacing.space3,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.hairline),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        spacing: AppSpacing.space3,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.brand50,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(
              Icons.water_drop_outlined,
              size: 16,
              color: AppColors.brand,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${(consumed / 1000).toStringAsFixed(1)} of '
                  '${(target / 1000).toStringAsFixed(1)} L water',
                  style: AppTextStyles.cardTitle.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: SizedBox(
                    height: 4,
                    child: ColoredBox(
                      color: AppColors.ink.withValues(alpha: 0.08),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: fraction,
                        child: const ColoredBox(color: AppColors.brand),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          AppButton.icon(
            leading: const Icon(Icons.add, size: 16),
            backgroundColor: AppColors.brand50,
            onPressed: () =>
                ref.read(mealLogProvider.notifier).addWater(_glassMl),
          ),
        ],
      ),
    );
  }
}

class _EmptyToday extends StatelessWidget {
  const _EmptyToday();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space4,
        vertical: AppSpacing.space6,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.hairline),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.restaurant_outlined,
            size: 22,
            color: AppColors.faint,
          ),
          const SizedBox(height: AppSpacing.space2),
          Text(
            'Nothing logged yet today',
            style: AppTextStyles.cardBody,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _MealCard extends ConsumerWidget {
  const _MealCard({required this.meal});

  final MealEntry meal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final macros = meal.macros;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.hairline),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      clipBehavior: Clip.antiAlias,
      // InkWell rather than PressableScale: this row's only gesture is the
      // long-press that removes it, which PressableScale does not expose.
      child: Semantics(
        label: '${meal.slot.label}: ${meal.summary}',
        hint: 'Long press to remove',
        child: InkWell(
          onLongPress: () => _confirmRemove(context, ref),
          child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    spacing: AppSpacing.space2,
                    children: [
                      Text(
                        meal.slot.label.toUpperCase(),
                        style: AppTextStyles.tag.copyWith(
                          fontSize: 9,
                          letterSpacing: 0.9,
                          color: AppColors.brand600,
                        ),
                      ),
                      Text(
                        DateFormat('h:mm a').format(meal.loggedAt),
                        style: AppTextStyles.cardMeta.copyWith(fontSize: 10),
                      ),
                    ],
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
              const SizedBox(height: 5),
              Text(
                meal.summary,
                style: AppTextStyles.cardTitle.copyWith(fontSize: 14),
              ),
              const SizedBox(height: 3),
              Text(
                '${macros.proteinG.round()}P · ${macros.carbsG.round()}C · '
                '${macros.fatG.round()}F · ${macros.fibreG.round()} g fibre',
                style: AppTextStyles.cardMeta,
              ),
              if (meal.source == MealSource.seed ||
                  meal.source == MealSource.photo ||
                  meal.source == MealSource.restaurant) ...[
                const SizedBox(height: 5),
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

/// The week, from the log — every column is a real sum, and the caption below it
/// is the analyser's own arithmetic rather than a fixed string.
class _WeekCard extends StatefulWidget {
  const _WeekCard({required this.weekly});

  final WeeklyNutritionSummary weekly;

  @override
  State<_WeekCard> createState() => _WeekCardState();
}

class _WeekCardState extends State<_WeekCard> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final days = widget.weekly.days;
    final selected = (_selected ?? days.length - 1).clamp(0, days.length - 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'This week',
          actionLabel: '${widget.weekly.loggedDays} logged',
        ),
        Container(
          padding: const EdgeInsets.all(AppSpacing.space4),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.hairline),
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DayColumnChart(
                values: [
                  for (final day in days)
                    day.macros.calories == 0
                        ? null
                        : day.macros.calories.toDouble(),
                ],
                labels: [
                  for (final day in days)
                    DateFormat('E').format(fromIsoDay(day.day))[0],
                ],
                selectedIndex: selected,
                formatValue: (value) => '${value.round()} kcal',
                onSelect: (index) => setState(() => _selected = index),
              ),
              const SizedBox(height: AppSpacing.space3),
              Text(
                widget.weekly.isSparse
                    ? 'Log at least three days and the weekly pattern analysis '
                          'switches on.'
                    : 'Averaging ${widget.weekly.averages.calories} kcal and '
                          '${widget.weekly.averages.proteinG.round()} g protein '
                          'across ${widget.weekly.loggedDays} logged days.',
                style: AppTextStyles.cardBody.copyWith(height: 1.45),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Counted over days, never averaged — averaging is what hides a pattern.
class _PatternsCard extends StatelessWidget {
  const _PatternsCard({required this.weekly});

  final WeeklyNutritionSummary weekly;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'Patterns', count: weekly.patterns.length),
        Column(
          spacing: AppSpacing.space2,
          children: [
            for (final pattern in weekly.patterns)
              _PatternRow(pattern: pattern),
          ],
        ),
      ],
    );
  }
}

class _PatternRow extends StatelessWidget {
  const _PatternRow({required this.pattern});

  final NutritionPattern pattern;

  @override
  Widget build(BuildContext context) {
    final isWin = pattern.tone == PatternTone.win;
    final accent = isWin ? AppColors.optimal : AppColors.borderline;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.space4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.hairline),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.space3,
        children: [
          Container(
            width: 3,
            height: 34,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pattern.title,
                  style: AppTextStyles.cardTitle.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 3),
                Text(
                  pattern.detail,
                  style: AppTextStyles.cardBody.copyWith(height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
