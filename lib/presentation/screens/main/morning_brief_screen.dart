import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/fade_in.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../../core/widgets/screen_back_button.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../domain/entities/brief/daily_brief.dart';
import '../../providers/brief_providers.dart';
import '../../providers/health_providers.dart';
import '../../providers/main_tab_provider.dart';
import '../../providers/user_profile_provider.dart';
import 'main_shell.dart';

/// Today's plan.
///
/// There is no "regenerate" button, and its absence is the point: the brief is a
/// pure function of the day's blood work, telemetry, cycle phase and food log, so
/// the same inputs always compose the same plan. A button that reshuffled the
/// wording would be admitting the wording was arbitrary. What the user can do
/// instead is refresh the *inputs* — pull to refresh — and watch the plan follow.
class MorningBriefScreen extends ConsumerWidget {
  const MorningBriefScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brief = ref.watch(dailyBriefProvider);
    final profile = ref.watch(userProfileProvider);

    return RefreshIndicator(
      color: AppColors.brand,
      onRefresh: () => ref.refresh(healthSeriesProvider.future),
      child: ListView(
        padding: EdgeInsets.only(
          top: AppSpacing.space1,
          bottom: MainShell.bottomInsetFor(context),
        ),
        children: [
          _Header(name: profile.greetingName),
          if (brief == null)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.space5),
              child: Column(
                spacing: AppSpacing.space3,
                children: [
                  Skeleton(height: 150),
                  Skeleton(height: 90),
                  Skeleton(height: 120),
                ],
              ),
            )
          else ...[
            _Section(delay: 20, child: _NarrativeCard(brief: brief)),
            _Section(delay: 60, child: _TargetsCard(brief: brief)),
            _Section(delay: 100, child: _WorkoutCard(brief: brief)),
            _Section(delay: 140, child: _FoodFocusCard(brief: brief)),
            _Section(delay: 180, child: _DriversCard(brief: brief)),
            if (brief.caveats.isNotEmpty)
              _Section(delay: 220, child: _CaveatsCard(brief: brief)),
          ],
          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.space8,
              AppSpacing.space6,
              AppSpacing.space8,
              0,
            ),
            child: _Disclaimer(),
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

class _Header extends StatelessWidget {
  const _Header({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : (hour < 18 ? 'Good afternoon' : 'Good evening');

    return Padding(
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
                  DateFormat('EEEE, MMMM d').format(DateTime.now()),
                  style: AppTextStyles.cardMeta.copyWith(
                    fontSize: 11,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 2),
                Text('$greeting, $name', style: AppTextStyles.h3),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The dark hero. Everything below it is detail; this is the read-one-thing card.
class _NarrativeCard extends StatelessWidget {
  const _NarrativeCard({required this.brief});

  final DailyBrief brief;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.space5),
      decoration: BoxDecoration(
        color: AppColors.brand900,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            spacing: AppSpacing.space2,
            children: [
              const Icon(
                Icons.auto_awesome,
                size: 14,
                color: AppColors.accent2_400,
              ),
              Text(
                'YOUR PLAN FOR TODAY',
                style: AppTextStyles.tag.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: AppColors.accent2_400,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space3),
          Text(
            brief.headline,
            style: AppTextStyles.h4.copyWith(
              color: AppColors.onBrand,
              height: 1.25,
            ),
          ),
          const SizedBox(height: AppSpacing.space3),
          for (final sentence in brief.narrative)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.space2),
              child: Text(
                sentence,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.onBrandMuted,
                  height: 1.5,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Five numbers, each with the reason it is that number. The basis line is not
/// decoration — a target nobody can justify is a target nobody follows.
class _TargetsCard extends ConsumerWidget {
  const _TargetsCard({required this.brief});

  final DailyBrief brief;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(targetProgressProvider);

    double? fractionFor(BriefTargetId id) => switch (id) {
      BriefTargetId.calories => progress?.calories,
      BriefTargetId.protein => progress?.protein,
      BriefTargetId.water => progress?.water,
      BriefTargetId.steps => progress?.steps,
      BriefTargetId.sleep => null,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: "Today's targets"),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.hairline),
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final target in brief.targets)
                _TargetRow(
                  target: target,
                  fraction: fractionFor(target.id),
                  isLast: target == brief.targets.last,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TargetRow extends StatelessWidget {
  const _TargetRow({
    required this.target,
    required this.fraction,
    required this.isLast,
  });

  final BriefTarget target;
  final double? fraction;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space4,
        vertical: AppSpacing.space3,
      ),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: AppColors.hairline, width: 1),
              ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  target.label,
                  style: AppTextStyles.cardTitle.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(target.basis, style: AppTextStyles.cardMeta),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.space3),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                target.value,
                style: AppTextStyles.metricSmall.copyWith(fontSize: 17),
              ),
              if (fraction != null) ...[
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: SizedBox(
                    width: 56,
                    height: 5,
                    child: ColoredBox(
                      color: AppColors.ink.withValues(alpha: 0.08),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: fraction!,
                        child: const ColoredBox(color: AppColors.brand),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _WorkoutCard extends StatelessWidget {
  const _WorkoutCard({required this.brief});

  final DailyBrief brief;

  static const _icons = {
    WorkoutIntensity.rest: Icons.self_improvement,
    WorkoutIntensity.easy: Icons.directions_walk,
    WorkoutIntensity.moderate: Icons.fitness_center,
    WorkoutIntensity.hard: Icons.bolt,
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Training'),
        Container(
          padding: const EdgeInsets.all(AppSpacing.space4),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.hairline),
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Row(
            spacing: AppSpacing.space3,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.brand50,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(
                  _icons[brief.workout.intensity],
                  size: 18,
                  color: AppColors.brand,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      brief.workout.title,
                      style: AppTextStyles.cardTitle.copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      brief.workout.detail,
                      style: AppTextStyles.cardBody.copyWith(height: 1.45),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Named dishes, filtered by the user's own diet and allergies, ordered by their
/// own cuisine preferences. Tapping one logs it — the macros behind the
/// recommendation are the macros that get written to the log.
class _FoodFocusCard extends ConsumerWidget {
  const _FoodFocusCard({required this.brief});

  final DailyBrief brief;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focus = brief.foodFocus;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Eat for this',
          actionLabel: 'Log a meal',
          onAction: () =>
              ref.read(mainTabProvider.notifier).select(MainTab.food),
        ),
        Container(
          padding: const EdgeInsets.all(AppSpacing.space4),
          decoration: BoxDecoration(
            color: AppColors.brand50,
            border: Border.all(color: AppColors.brand200),
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                focus.title,
                style: AppTextStyles.cardTitle.copyWith(fontSize: 15),
              ),
              const SizedBox(height: 4),
              Text(
                focus.detail,
                style: AppTextStyles.cardBody.copyWith(
                  height: 1.5,
                  color: AppColors.brand800,
                ),
              ),
              if (focus.examples.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.space3),
                Wrap(
                  spacing: AppSpacing.space2,
                  runSpacing: AppSpacing.space2,
                  children: [
                    for (final example in focus.examples)
                      _FoodChip(example: example),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _FoodChip extends StatelessWidget {
  const _FoodChip({required this.example});

  final FoodFocusExample example;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space3,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.brand200),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            example.name,
            style: AppTextStyles.bodySmall.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            example.portionLabel,
            style: AppTextStyles.cardMeta.copyWith(fontSize: 10),
          ),
        ],
      ),
    );
  }
}

/// Why the plan says what it says. This is the card that makes the brief
/// auditable rather than oracular.
class _DriversCard extends StatefulWidget {
  const _DriversCard({required this.brief});

  final DailyBrief brief;

  @override
  State<_DriversCard> createState() => _DriversCardState();
}

class _DriversCardState extends State<_DriversCard> {
  bool _expanded = false;

  static const _icons = {
    BriefDriverKind.recovery: Icons.favorite_outline,
    BriefDriverKind.sleep: Icons.bedtime_outlined,
    BriefDriverKind.cycle: Icons.calendar_month_outlined,
    BriefDriverKind.labs: Icons.science_outlined,
    BriefDriverKind.nutrition: Icons.restaurant_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final drivers = widget.brief.drivers;
    if (drivers.isEmpty) return const SizedBox.shrink();

    final visible = _expanded ? drivers : drivers.take(2).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'What shaped this',
          count: drivers.length,
          actionLabel: _expanded ? 'Show less' : 'Show all',
          onAction: () => setState(() => _expanded = !_expanded),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.hairline),
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final driver in visible)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.space4),
                  decoration: BoxDecoration(
                    border: driver == visible.last
                        ? null
                        : const Border(
                            bottom: BorderSide(
                              color: AppColors.hairline,
                              width: 1,
                            ),
                          ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: AppSpacing.space3,
                    children: [
                      Icon(
                        _icons[driver.kind],
                        size: 15,
                        color: AppColors.brand,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              driver.label,
                              style: AppTextStyles.bodySmall.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              driver.detail,
                              style: AppTextStyles.cardBody.copyWith(
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// What the brief could not see. Shown, not buried: a plan that overstates its
/// own evidence is worse than one that admits a gap.
class _CaveatsCard extends ConsumerWidget {
  const _CaveatsCard({required this.brief});

  final DailyBrief brief;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PressableScale(
      scaleTo: 0.995,
      onTap: () => ref.read(mainTabProvider.notifier).select(MainTab.settings),
      semanticLabel: 'What this plan could not see',
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.space4),
        decoration: BoxDecoration(
          color: AppColors.neutral200,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'WHAT THIS COULD NOT SEE',
              style: AppTextStyles.tag.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: AppSpacing.space2),
            for (final caveat in brief.caveats)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: AppSpacing.space2,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Container(
                        width: 3,
                        height: 3,
                        decoration: const BoxDecoration(
                          color: AppColors.faint,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        caveat,
                        style: AppTextStyles.cardBody.copyWith(height: 1.45),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Disclaimer extends StatelessWidget {
  const _Disclaimer();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Composed from your own data and published reference intervals — not '
      'medical advice, and not a diagnosis.',
      textAlign: TextAlign.center,
      style: AppTextStyles.cardMeta.copyWith(fontSize: 10, height: 1.5),
    );
  }
}
