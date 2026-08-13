import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/util/iso_day.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/fade_in.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../../core/widgets/screen_back_button.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/surface_card.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../domain/entities/dining/restaurant.dart';
import '../../../domain/entities/nutrition/food_definition.dart';
import '../../../domain/entities/nutrition/meal_entry.dart';
import '../../../features/nutrition/food_database.dart';
import '../../providers/dining_providers.dart';
import '../../providers/main_tab_provider.dart';
import '../../providers/nutrition_providers.dart';
import 'main_shell.dart';

/// Nearby restaurants, ranked by what is left in today's budget.
/// Mirrors `app/dining.tsx`.
///
/// The recommendation is the *dish*, not the venue — so every card leads with
/// what to order and what it costs in macros, and the venue is context. Tapping
/// a dish logs it, which closes the loop between "where should I eat" and the
/// food diary that drives tomorrow's brief.
class DiningScreen extends ConsumerWidget {
  const DiningScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nearbyAsync = ref.watch(nearbyRestaurantsProvider);
    final picks = ref.watch(diningPicksProvider);
    final mode = ref.watch(diningModeProvider);
    final targets = ref.watch(nutritionTargetsProvider);
    final consumed = ref.watch(consumedTodayProvider);
    final cheat = mode == DiningMode.cheat;

    final remainingCalories = targets == null
        ? null
        : targets.calories - consumed.calories;
    final remainingProtein = targets == null
        ? null
        : targets.macros.proteinG - consumed.proteinG;

    // Null only while still loading; once resolved, a non-null value here
    // means the search failed in some specific, nameable way — see
    // `NearbyFailureReason`. Never papered over with invented restaurants.
    final failureReason =
        nearbyAsync.valueOrNull?.failure ??
        (nearbyAsync.hasError ? NearbyFailureReason.searchFailed : null);

    return ListView(
      padding: EdgeInsets.only(
        top: AppSpacing.space1,
        bottom: MainShell.bottomInsetFor(context),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space5),
          child: Row(
            children: [
              const ScreenBackButton(),
              Expanded(
                child: Text(
                  'Eat out',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.h6.copyWith(
                    fontSize: 15,
                    letterSpacing: 0,
                  ),
                ),
              ),
              const SizedBox(width: 36),
            ],
          ),
        ),

        // BUDGET + MODE
        _Section(
          delay: 30,
          child: _BudgetCard(
            cheat: cheat,
            remainingCalories: remainingCalories,
            remainingProtein: remainingProtein,
            onToggle: () => ref
                .read(diningModeProvider.notifier)
                .select(cheat ? DiningMode.aligned : DiningMode.cheat),
          ),
        ),

        // PICKS
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.space5,
            AppSpacing.space6,
            AppSpacing.space5,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(
                title: cheat ? 'Worth the cheat' : 'Fits your day',
                count: picks.length,
              ),
              if (nearbyAsync.isLoading && picks.isEmpty)
                const Column(
                  spacing: AppSpacing.space3,
                  children: [Skeleton(height: 180), Skeleton(height: 180)],
                )
              else if (failureReason != null)
                _SearchIssueCard(
                  reason: failureReason,
                  onRetry: () => ref.invalidate(nearbyRestaurantsProvider),
                )
              else if (picks.isEmpty)
                EmptyState(
                  icon: Icons.no_meals_outlined,
                  title: 'Nothing we can recommend here',
                  body: 'Every nearby venue serves food that conflicts with '
                      'your allergies or diet. Widening your cuisines in '
                      'Settings usually fixes this.',
                  actionLabel: 'Open settings',
                  onAction: () {
                    Navigator.of(context).maybePop();
                    ref.read(mainTabProvider.notifier).select(MainTab.settings);
                  },
                )
              else
                Column(
                  children: [
                    for (var i = 0; i < picks.length; i += 1)
                      FadeIn(
                        delay: Duration(milliseconds: 40 * (i > 6 ? 6 : i)),
                        child: _RestaurantPickCard(pick: picks[i]),
                      ),
                  ],
                ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.space8 + AppSpacing.space2,
            AppSpacing.space6,
            AppSpacing.space8 + AppSpacing.space2,
            0,
          ),
          child: Text(
            'Dish suggestions are typical of each cuisine — we do not have '
            'these restaurants’ menus. Check with the venue for ingredients if '
            'you have an allergy.',
            textAlign: TextAlign.center,
            style: AppTextStyles.cardMeta.copyWith(fontSize: 10, height: 1.5),
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

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({
    required this.cheat,
    required this.remainingCalories,
    required this.remainingProtein,
    required this.onToggle,
  });

  final bool cheat;
  final int? remainingCalories;
  final double? remainingProtein;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cheat ? 'CHEAT DAY' : 'LEFT TODAY',
                      style: AppTextStyles.tag.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                        color: AppColors.faint,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      remainingCalories != null
                          ? '$remainingCalories kcal'
                          : 'No target set',
                      style: AppTextStyles.h3.copyWith(fontSize: 24),
                    ),
                    if (remainingProtein != null && remainingProtein! > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'and ${remainingProtein!.round()} g of protein to go',
                          style: AppTextStyles.cardMeta.copyWith(fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
              _ModeToggle(cheat: cheat, onTap: onToggle),
            ],
          ),
          Container(
            margin: const EdgeInsets.only(top: AppSpacing.space3),
            padding: const EdgeInsets.only(top: AppSpacing.space3),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.hairline)),
            ),
            child: Text(
              cheat
                  ? 'Cheat mode ranks for what you actually want. Your allergies '
                        'and diet are still hard filters — those never relax.'
                  : 'Dishes are ranked against what you have left today, your '
                        'blood work and your cuisines.',
              style: AppTextStyles.cardMeta.copyWith(
                fontSize: 11,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.cheat, required this.onTap});

  final bool cheat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: cheat,
      label: 'Cheat day mode',
      hint: 'Stops down-ranking indulgent dishes. Allergies and diet are still '
          'respected.',
      child: PressableScale(
        scaleTo: 0.97,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space3,
            vertical: AppSpacing.space2,
          ),
          decoration: BoxDecoration(
            color: cheat ? AppColors.limeSoft : AppColors.surface,
            border: Border.all(
              color: cheat ? AppColors.limeStrong : AppColors.hairline,
            ),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: [
              Icon(
                cheat ? Icons.cake_outlined : Icons.eco_outlined,
                size: 15,
                color: cheat ? AppColors.ink : AppColors.faint,
              ),
              Text(
                cheat ? 'Cheat' : 'On plan',
                style: AppTextStyles.cardMeta.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: cheat ? AppColors.ink : AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What went wrong and, where there is one, a single button that fixes it.
/// Shown instead of the picks list whenever the search could not run — never
/// alongside invented restaurants.
class _SearchIssueCard extends StatelessWidget {
  const _SearchIssueCard({required this.reason, required this.onRetry});

  final NearbyFailureReason reason;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final (icon, title, body, actionLabel, action) = switch (reason) {
      NearbyFailureReason.locationServicesOff => (
        Icons.location_off_outlined,
        'Location is turned off',
        'Turn on location services to find restaurants near you.',
        'Open location settings',
        () => unawaited(Geolocator.openLocationSettings()),
      ),
      NearbyFailureReason.permissionDenied => (
        Icons.location_disabled_outlined,
        'Location access needed',
        'Allow location access so we can find restaurants near you.',
        'Allow access',
        onRetry,
      ),
      NearbyFailureReason.permissionDeniedForever => (
        Icons.settings_outlined,
        'Location access is off for this app',
        'Turn it back on in this app’s system settings to search nearby.',
        'Open app settings',
        () => unawaited(Geolocator.openAppSettings()),
      ),
      NearbyFailureReason.searchFailed => (
        Icons.wifi_off_outlined,
        'Could not reach the search',
        'Check your connection and try again.',
        'Try again',
        onRetry,
      ),
      NearbyFailureReason.noResults => (
        Icons.explore_off_outlined,
        'Nothing nearby',
        'No restaurants turned up within about 1.5 miles. Try again later, or '
            'from somewhere more central.',
        'Try again',
        onRetry,
      ),
    };

    return EmptyState(
      icon: icon,
      title: title,
      body: body,
      actionLabel: actionLabel,
      onAction: action,
    );
  }
}

/// One venue: what to order, what it costs, and a one-tap way into the log.
class _RestaurantPickCard extends ConsumerWidget {
  const _RestaurantPickCard({required this.pick});

  final RestaurantPick pick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final restaurant = pick.restaurant;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.space3),
      child: SurfaceCard(
        padded: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // VENUE
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.space4,
                AppSpacing.space4,
                AppSpacing.space4,
                AppSpacing.space3,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          restaurant.name,
                          style: AppTextStyles.h5.copyWith(
                            fontSize: 16,
                            height: 1.25,
                          ),
                        ),
                      ),
                      if (restaurant.directionsUri != null)
                        _DirectionsButton(restaurant: restaurant),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _VenueMeta(restaurant: restaurant),
                  if (pick.reasons.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        pick.reasons.join(' · '),
                        style: AppTextStyles.cardMeta.copyWith(
                          fontSize: 11,
                          height: 1.45,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // DISHES
            Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.hairline)),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < pick.dishes.length; i += 1)
                    _DishRow(
                      dish: pick.dishes[i],
                      isTopPick: i == 0,
                      isLast: i == pick.dishes.length - 1,
                      onLog: () => _logDish(context, ref, pick.dishes[i]),
                    ),
                ],
              ),
            ),

            // COMBO
            if (pick.comboMacros.calories > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.space4,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.brand50.withValues(alpha: 0.6),
                  border: const Border(
                    top: BorderSide(color: AppColors.hairline),
                  ),
                ),
                child: Text(
                  'Ordering the top '
                  '${pick.dishes.length > 1 ? 'two' : 'pick'}: '
                  '${pick.comboMacros.calories} kcal, '
                  '${pick.comboMacros.proteinG.round()} g protein, '
                  '${pick.comboMacros.fibreG.round()} g fibre.',
                  style: AppTextStyles.cardMeta.copyWith(
                    fontSize: 11,
                    height: 1.4,
                    color: AppColors.brand800,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Logs a single dish. The macros written are the same rows from the same food
  /// table the card displayed — which is the whole argument for recommending
  /// dishes rather than venues.
  Future<void> _logDish(
    BuildContext context,
    WidgetRef ref,
    DishPick dish,
  ) async {
    final food = findFood(dish.foodId);
    if (food == null) return;

    await HapticFeedback.mediumImpact();

    final now = DateTime.now();
    await ref.read(mealLogProvider.notifier).add(
      MealEntry(
        id: 'dining-${now.microsecondsSinceEpoch}',
        day: toIsoDay(now),
        loggedAt: now,
        slot: MealSlot.forHour(now.hour),
        source: MealSource.restaurant,
        foods: [LoggedFood.fromDefinition(food)],
        note: 'At ${pick.restaurant.name}',
      ),
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Logged ${dish.name} · ${dish.macros.calories} kcal'),
      ),
    );
  }
}

class _VenueMeta extends StatelessWidget {
  const _VenueMeta({required this.restaurant});

  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    final parts = <Widget>[
      if (restaurant.rating != null)
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 3,
          children: [
            const Icon(Icons.star, size: 11, color: AppColors.borderline),
            Text(
              restaurant.rating!.toStringAsFixed(1),
              style: AppTextStyles.cardMeta.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      if (restaurant.distanceLabel != null)
        Text(
          restaurant.distanceLabel!,
          style: AppTextStyles.cardMeta.copyWith(fontSize: 11),
        ),
      if (restaurant.priceLabel.isNotEmpty)
        Text(
          restaurant.priceLabel,
          style: AppTextStyles.cardMeta.copyWith(fontSize: 11),
        ),
      if (restaurant.address != null)
        Text(
          restaurant.address!,
          style: AppTextStyles.cardMeta.copyWith(fontSize: 11),
        ),
    ];

    return Wrap(
      spacing: AppSpacing.space2,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < parts.length; i += 1) ...[
          if (i > 0)
            Container(
              width: 3,
              height: 3,
              decoration: const BoxDecoration(
                color: AppColors.faint,
                shape: BoxShape.circle,
              ),
            ),
          parts[i],
        ],
      ],
    );
  }
}

/// Opens the venue in whichever maps app is installed. Needs no API key —
/// it is a plain search URL, not a Places lookup.
class _DirectionsButton extends StatelessWidget {
  const _DirectionsButton({required this.restaurant});

  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Directions to ${restaurant.name}',
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: () => _open(context),
        child: Container(
          padding: const EdgeInsets.all(6),
          child: const Icon(
            Icons.directions_outlined,
            size: 18,
            color: AppColors.brand,
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    final uri = restaurant.directionsUri;
    if (uri == null) return;
    HapticFeedback.selectionClick();
    final opened = await launchUrl(
      Uri.parse(uri),
      mode: LaunchMode.externalApplication,
    );
    if (opened || !context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Could not open maps')));
  }
}

class _DishRow extends StatelessWidget {
  const _DishRow({
    required this.dish,
    required this.isTopPick,
    required this.isLast,
    required this.onLog,
  });

  final DishPick dish;
  final bool isTopPick;
  final bool isLast;
  final VoidCallback onLog;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: AppColors.hairline)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space4,
        vertical: AppSpacing.space3,
      ),
      child: Row(
        spacing: AppSpacing.space3,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  spacing: AppSpacing.space2,
                  children: [
                    if (isTopPick)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.brand600,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          'TOP PICK',
                          style: AppTextStyles.tag.copyWith(
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: AppColors.onBrand,
                          ),
                        ),
                      ),
                    Expanded(
                      child: Text(
                        dish.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.cardTitle.copyWith(fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${dish.portionLabel} · ${dish.macros.calories} kcal · '
                  '${dish.macros.proteinG.round()} g protein',
                  style: AppTextStyles.cardMeta.copyWith(fontSize: 11),
                ),
                const SizedBox(height: 2),
                Text(
                  dish.rationale,
                  style: AppTextStyles.cardMeta.copyWith(
                    fontSize: 11,
                    height: 1.36,
                    color: AppColors.faint,
                  ),
                ),
              ],
            ),
          ),
          PressableScale(
            scaleTo: 0.94,
            semanticLabel: 'Log ${dish.name}',
            semanticHint: "Adds this dish to today's food log",
            onTap: onLog,
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.brand50,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, size: 17, color: AppColors.brand),
            ),
          ),
        ],
      ),
    );
  }
}
