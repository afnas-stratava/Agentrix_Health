import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/util/iso_day.dart';
import '../../../core/widgets/app_tag.dart';
import '../../../core/widgets/fade_in.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../../core/widgets/screen_back_button.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/segmented_control.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../domain/entities/dining/restaurant.dart';
import '../../../domain/entities/nutrition/food_definition.dart';
import '../../../domain/entities/nutrition/meal_entry.dart';
import '../../../features/dining/fixtures.dart';
import '../../../features/dining/rank.dart';
import '../../../features/nutrition/food_database.dart';
import '../../providers/dining_providers.dart';
import '../../providers/nutrition_providers.dart';
import 'main_shell.dart';

/// Nearby food, ranked by what is left in today's budget.
///
/// The unit of recommendation is a *dish*, not a venue: "there is a healthy place
/// 400 m away" is not actionable, and "order the dal tadka with two rotis — 34 g
/// of protein, and it fits the 780 kcal you have left" is.
///
/// Two disclosures are load-bearing and always rendered: no menu was read (the
/// dishes are cuisine-typical), and when the venue list is a curated fallback
/// rather than live nearby results.
class DiningScreen extends ConsumerWidget {
  const DiningScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nearbyAsync = ref.watch(nearbyRestaurantsProvider);
    final picks = ref.watch(diningPicksProvider);
    final mode = ref.watch(diningModeProvider);
    final targets = ref.watch(nutritionTargetsProvider);
    final consumed = ref.watch(consumedTodayProvider);

    final remaining = targets == null
        ? null
        : targets.calories - consumed.calories;

    return RefreshIndicator(
      color: AppColors.brand,
      onRefresh: () => ref.refresh(nearbyRestaurantsProvider.future),
      child: ListView(
        padding: EdgeInsets.only(
          top: AppSpacing.space1,
          bottom: MainShell.bottomInsetFor(context),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ScreenBackButton(),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        remaining == null
                            ? 'Ranked for your profile'
                            : remaining > 0
                            ? '$remaining kcal left today'
                            : '${remaining.abs()} kcal over today',
                        style: AppTextStyles.cardMeta.copyWith(
                          fontSize: 11,
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text('Eat out', style: AppTextStyles.h3),
                    ],
                  ),
                ),
              ],
            ),
          ),

          _Section(
            delay: 20,
            child: SegmentedControl<DiningMode>(
              options: const [
                SegmentedOption(
                  value: DiningMode.aligned,
                  label: 'Aligned to today',
                ),
                SegmentedOption(value: DiningMode.cheat, label: 'Cheat day'),
              ],
              selected: mode,
              onChanged: (next) =>
                  ref.read(diningModeProvider.notifier).select(next),
            ),
          ),

          _Section(delay: 60, child: _ModeExplainer(mode: mode)),

          if (nearbyAsync.isLoading)
            const _Section(
              delay: 100,
              child: Column(
                spacing: AppSpacing.space3,
                children: [Skeleton(height: 210), Skeleton(height: 210)],
              ),
            )
          else ...[
            if (nearbyAsync.valueOrNull?.isFallback ?? false)
              _Section(delay: 90, child: const _FallbackNotice()),

            if (picks.isEmpty)
              const _Section(delay: 120, child: _NoPicks())
            else ...[
              _Section(
                delay: 120,
                child: SectionHeader(
                  title: 'Best fit near you',
                  count: picks.length,
                ),
              ),
              for (var i = 0; i < picks.length; i += 1)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.space5,
                    0,
                    AppSpacing.space5,
                    AppSpacing.space3,
                  ),
                  child: FadeIn(
                    delay: Duration(milliseconds: 140 + i * 40),
                    child: _PickCard(pick: picks[i], rank: i + 1),
                  ),
                ),
            ],
          ],

          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.space8,
              AppSpacing.space4,
              AppSpacing.space8,
              0,
            ),
            child: _MenuDisclosure(),
          ),
        ],
      ),
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

/// Cheat mode is an explicit choice, so it says out loud what it changed.
class _ModeExplainer extends StatelessWidget {
  const _ModeExplainer({required this.mode});

  final DiningMode mode;

  @override
  Widget build(BuildContext context) {
    final cheat = mode == DiningMode.cheat;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space3,
        vertical: AppSpacing.space2,
      ),
      decoration: BoxDecoration(
        color: cheat ? AppColors.limeSoft : AppColors.brand50,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        spacing: AppSpacing.space2,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            cheat ? Icons.celebration_outlined : Icons.track_changes_outlined,
            size: 15,
            color: cheat ? AppColors.accent2_800 : AppColors.brand,
          ),
          Expanded(
            child: Text(
              cheat
                  ? 'Ranking for enjoyment, not macros. Your allergies and diet '
                        'are still hard filters — those are safety, not '
                        'preference.'
                  : 'Ranked against what you have left today and what your plan '
                        'is asking for.',
              style: AppTextStyles.cardBody.copyWith(
                height: 1.45,
                color: cheat ? AppColors.accent2_900 : AppColors.brand800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FallbackNotice extends StatelessWidget {
  const _FallbackNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space3,
        vertical: AppSpacing.space2,
      ),
      decoration: BoxDecoration(
        color: AppColors.neutral200,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        spacing: AppSpacing.space2,
        children: [
          const Icon(Icons.info_outline, size: 14, color: AppColors.muted),
          Expanded(
            child: Text(
              fixtureDisclosure,
              style: AppTextStyles.cardBody.copyWith(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoPicks extends StatelessWidget {
  const _NoPicks();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.space5),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.hairline),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        children: [
          const Icon(Icons.no_meals_outlined, size: 22, color: AppColors.faint),
          const SizedBox(height: AppSpacing.space2),
          Text(
            'Nothing nearby matches your diet and allergies right now.',
            textAlign: TextAlign.center,
            style: AppTextStyles.cardBody.copyWith(height: 1.45),
          ),
        ],
      ),
    );
  }
}

/// One venue, and the specific thing to order there.
class _PickCard extends ConsumerWidget {
  const _PickCard({required this.pick, required this.rank});

  final RestaurantPick pick;
  final int rank;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final restaurant = pick.restaurant;
    final combo = pick.combo;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(
          color: rank == 1 ? AppColors.brand300 : AppColors.hairline,
          width: rank == 1 ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.space4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            restaurant.name,
                            style: AppTextStyles.cardTitle.copyWith(
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            [
                              restaurant.cuisine?.label,
                              restaurant.distanceLabel,
                              if (restaurant.rating != null)
                                '★ ${restaurant.rating!.toStringAsFixed(1)}',
                              if (restaurant.priceLabel.isNotEmpty)
                                restaurant.priceLabel,
                            ].whereType<String>().join(' · '),
                            style: AppTextStyles.cardMeta,
                          ),
                        ],
                      ),
                    ),
                    if (rank == 1)
                      const AppTag(label: 'Best fit', variant: AppTagVariant.accent),
                  ],
                ),
                const SizedBox(height: AppSpacing.space3),

                // The headline: what to order, and the macros that justify it.
                Container(
                  padding: const EdgeInsets.all(AppSpacing.space3),
                  decoration: BoxDecoration(
                    color: AppColors.brand50,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ORDER THIS',
                        style: AppTextStyles.tag.copyWith(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          color: AppColors.brand700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        combo.map((d) => d.name).join(' + '),
                        style: AppTextStyles.h5.copyWith(height: 1.3),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${pick.comboMacros.calories} kcal · '
                        '${pick.comboMacros.proteinG.round()} g protein · '
                        '${pick.comboMacros.fibreG.round()} g fibre',
                        style: AppTextStyles.cardMeta.copyWith(
                          color: AppColors.brand700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.space2),
                      _LogButton(pick: pick),
                    ],
                  ),
                ),

                if (pick.reasons.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.space3),
                  for (final reason in pick.reasons)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: AppSpacing.space2,
                        children: [
                          const Icon(
                            Icons.check,
                            size: 12,
                            color: AppColors.brand400,
                          ),
                          Expanded(
                            child: Text(
                              reason,
                              style: AppTextStyles.cardBody.copyWith(
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),

          // The runners-up, so the card is a menu rather than a single verdict.
          if (pick.dishes.length > 1)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.space4,
                AppSpacing.space3,
                AppSpacing.space4,
                AppSpacing.space3,
              ),
              decoration: const BoxDecoration(
                color: AppColors.canvas,
                border: Border(top: BorderSide(color: AppColors.hairline)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ALSO GOOD HERE',
                    style: AppTextStyles.tag.copyWith(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: AppColors.faint,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space2),
                  for (final dish in pick.dishes.skip(1))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dish.name,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  dish.rationale,
                                  style: AppTextStyles.cardMeta.copyWith(
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${dish.macros.calories} kcal',
                            style: AppTextStyles.cardMeta,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Logs the recommended combo straight into the food log.
///
/// This is the whole argument for dish-level recommendation: the macros shown on
/// the card are the same rows from the same table that get written to the log, so
/// "I ate this" needs no re-entry and no reconciliation.
class _LogButton extends ConsumerWidget {
  const _LogButton({required this.pick});

  final RestaurantPick pick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PressableScale(
      scaleTo: 0.98,
      semanticLabel: 'Log this order to your food log',
      onTap: () => _log(context, ref),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space3,
          vertical: 7,
        ),
        decoration: BoxDecoration(
          color: AppColors.brand,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 6,
          children: [
            const Icon(Icons.add, size: 13, color: AppColors.onBrand),
            Text(
              'I ate this',
              style: AppTextStyles.button.copyWith(
                fontSize: 12,
                color: AppColors.onBrand,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _log(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final foods = pick.combo
        .map((dish) => findFood(dish.foodId))
        .whereType<FoodDefinition>()
        .map(LoggedFood.fromDefinition)
        .toList();

    if (foods.isEmpty) return;

    await ref.read(mealLogProvider.notifier).add(
      MealEntry(
        id: 'dining-${now.microsecondsSinceEpoch}',
        day: toIsoDay(now),
        loggedAt: now,
        slot: MealSlot.forHour(now.hour),
        source: MealSource.restaurant,
        foods: foods,
        note: pick.restaurant.name,
      ),
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Logged ${pick.comboMacros.calories} kcal from '
          '${pick.restaurant.name}',
        ),
      ),
    );
  }
}

class _MenuDisclosure extends StatelessWidget {
  const _MenuDisclosure();

  @override
  Widget build(BuildContext context) {
    return Text(
      dishBasis,
      textAlign: TextAlign.center,
      style: AppTextStyles.cardMeta.copyWith(fontSize: 10, height: 1.5),
    );
  }
}
