import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/fade_in.dart';
import '../../../core/widgets/screen_back_button.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/surface_card.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../domain/entities/brief/daily_brief.dart';
import '../../providers/brief_providers.dart';
import '../../providers/health_providers.dart';
import '../../providers/main_tab_provider.dart';
import '../../providers/nutrition_providers.dart';
import 'dining_screen.dart';
import 'main_shell.dart';

/// The morning brief. Mirrors `app/brief.tsx`.
///
/// One screen answering "what should I do today", composed from blood work, last
/// night's recovery, cycle phase and the week's eating. The driver list at the
/// bottom is not decoration — it is what makes the plan auditable, and it is the
/// reason this can be shown to someone without over-claiming.
class MorningBriefScreen extends ConsumerWidget {
  const MorningBriefScreen({super.key});

  static const _targetIcon = {
    BriefTargetId.calories: Icons.local_fire_department_outlined,
    BriefTargetId.protein: Icons.restaurant_outlined,
    BriefTargetId.water: Icons.water_drop_outlined,
    BriefTargetId.steps: Icons.directions_walk,
    BriefTargetId.sleep: Icons.bedtime_outlined,
  };

  static const _driverIcon = {
    BriefDriverKind.recovery: Icons.monitor_heart_outlined,
    BriefDriverKind.sleep: Icons.bedtime_outlined,
    BriefDriverKind.cycle: Icons.water_drop_outlined,
    BriefDriverKind.labs: Icons.info_outline,
    BriefDriverKind.nutrition: Icons.restaurant_outlined,
  };

  static const _intensityTone = {
    WorkoutIntensity.rest: AppColors.critical,
    WorkoutIntensity.easy: AppColors.borderline,
    WorkoutIntensity.moderate: AppColors.normal,
    WorkoutIntensity.hard: AppColors.optimal,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brief = ref.watch(dailyBriefProvider);
    final needsProfile = ref.watch(nutritionTargetsProvider) == null;
    final loading = ref.watch(healthSeriesProvider).isLoading;

    if (needsProfile) {
      return Column(
        children: [
          const _BriefHeader(),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.space5),
                child: EmptyState(
                  icon: Icons.restaurant_outlined,
                  title: 'We need a few numbers first',
                  body: 'Your brief prescribes calories, protein and hydration '
                      '— which needs your height, weight and age before it can '
                      'say anything specific.',
                  actionLabel: 'Complete your profile',
                  onAction: () {
                    Navigator.of(context).maybePop();
                    ref.read(mainTabProvider.notifier).select(MainTab.settings);
                  },
                ),
              ),
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: EdgeInsets.only(
        top: AppSpacing.space1,
        bottom: MainShell.bottomInsetFor(context),
      ),
      children: [
        const _BriefHeader(),

        if (loading && brief == null)
          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.space5,
              AppSpacing.space5,
              AppSpacing.space5,
              0,
            ),
            child: Column(
              spacing: AppSpacing.space3,
              children: [Skeleton(height: 220), Skeleton(height: 120)],
            ),
          )
        else if (brief == null)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.space5),
            child: EmptyState(
              icon: Icons.info_outline,
              title: 'Nothing to brief yet',
              body: 'Connect $healthStoreName or add a blood report and your '
                  'first brief appears the next morning.',
            ),
          )
        else ...[
          // HERO
          _Section(delay: 30, child: _Hero(brief: brief)),

          // TARGETS
          _Section(
            delay: 90,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionHeader(title: "Today's targets"),
                SurfaceCard(
                  padded: false,
                  child: Column(
                    children: [
                      for (final target in brief.targets)
                        _TargetRow(
                          icon: _targetIcon[target.id]!,
                          target: target,
                          isLast: target == brief.targets.last,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // TRAINING
          _Section(
            delay: 150,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionHeader(title: 'Training'),
                SurfaceCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: AppSpacing.space3,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _intensityTone[brief.workout.intensity]!
                              .withValues(alpha: 0.09),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Icon(
                          Icons.fitness_center,
                          size: 18,
                          color: _intensityTone[brief.workout.intensity],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              brief.workout.title,
                              style: AppTextStyles.cardTitle.copyWith(
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              brief.workout.detail,
                              style: AppTextStyles.cardBody.copyWith(
                                height: 1.5,
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

          // FOOD FOCUS
          _Section(
            delay: 210,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionHeader(title: 'Eat for this today'),
                SurfaceCard(child: _FoodFocusCard(focus: brief.foodFocus)),
              ],
            ),
          ),

          // DRIVERS — every one of them, not a collapsed summary. A plan you
          // cannot audit is a plan you have to take on faith.
          _Section(
            delay: 270,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionHeader(
                  title: 'What shaped this',
                  count: brief.drivers.length,
                ),
                SurfaceCard(
                  padded: false,
                  child: Column(
                    children: [
                      for (final driver in brief.drivers)
                        _DriverRow(
                          icon: _driverIcon[driver.kind]!,
                          driver: driver,
                          isLast: driver == brief.drivers.last,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // CAVEATS
          if (brief.caveats.isNotEmpty)
            _Section(delay: 330, child: _Caveats(caveats: brief.caveats)),

          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.space8 + AppSpacing.space2,
              AppSpacing.space6,
              AppSpacing.space8 + AppSpacing.space2,
              0,
            ),
            child: Text(
              'Composed from your own data on this device. Not medical advice, '
              'and not a diagnosis.',
              textAlign: TextAlign.center,
              style: AppTextStyles.cardMeta.copyWith(fontSize: 10, height: 1.5),
            ),
          ),
        ],
      ],
    );
  }
}

/// Back button, centred title, and a spacer the same width as the button so the
/// title sits optically centred rather than centred in what is left over.
class _BriefHeader extends StatelessWidget {
  const _BriefHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space5),
      child: Row(
        children: [
          const ScreenBackButton(),
          Expanded(
            child: Text(
              'Your morning brief',
              textAlign: TextAlign.center,
              style: AppTextStyles.h6.copyWith(fontSize: 15, letterSpacing: 0),
            ),
          ),
          const SizedBox(width: 36),
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

class _Hero extends StatelessWidget {
  const _Hero({required this.brief});

  final DailyBrief brief;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.card),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.heroGradient,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.brand900.withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.space5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('EEEE, d MMMM').format(brief.generatedAt).toUpperCase(),
            style: AppTextStyles.tag.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: AppColors.onBrand.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: AppSpacing.space2),
          Text(
            brief.headline,
            style: AppTextStyles.h3.copyWith(
              fontSize: 24,
              height: 1.2,
              color: AppColors.onBrand,
            ),
          ),
          for (final sentence in brief.narrative)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                sentence,
                style: AppTextStyles.bodySmall.copyWith(
                  fontSize: 13,
                  height: 1.46,
                  color: AppColors.onBrand.withValues(alpha: 0.8),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TargetRow extends StatelessWidget {
  const _TargetRow({
    required this.icon,
    required this.target,
    required this.isLast,
  });

  final IconData icon;
  final BriefTarget target;
  final bool isLast;

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
        vertical: 14,
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
            child: Icon(icon, size: 16, color: AppColors.brand),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  target.label,
                  style: AppTextStyles.cardTitle.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 2),
                // The basis line is the whole point: a target nobody can
                // justify is a target nobody follows.
                Text(
                  target.basis,
                  style: AppTextStyles.cardMeta.copyWith(
                    fontSize: 11,
                    height: 1.36,
                  ),
                ),
              ],
            ),
          ),
          Text(
            target.value,
            style: AppTextStyles.metricSmall.copyWith(fontSize: 17),
          ),
        ],
      ),
    );
  }
}

class _FoodFocusCard extends StatelessWidget {
  const _FoodFocusCard({required this.focus});

  final FoodFocus focus;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          focus.title,
          style: AppTextStyles.cardTitle.copyWith(fontSize: 15),
        ),
        const SizedBox(height: 6),
        Text(focus.detail, style: AppTextStyles.cardBody.copyWith(height: 1.5)),

        if (focus.examples.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 14),
            padding: const EdgeInsets.only(top: 14),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.hairline)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'GOOD OPTIONS FOR YOU',
                  style: AppTextStyles.tag.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: AppColors.faint,
                  ),
                ),
                const SizedBox(height: AppSpacing.space2),
                for (final example in focus.examples)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      spacing: AppSpacing.space2,
                      children: [
                        Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            color: AppColors.brand400,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Text(
                          example.name,
                          style: AppTextStyles.bodySmall.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            example.portionLabel,
                            style: AppTextStyles.cardMeta.copyWith(
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

        const SizedBox(height: AppSpacing.space3),
        AppButton(
          label: 'Find somewhere nearby',
          variant: AppButtonVariant.secondary,
          size: AppButtonSize.sm,
          block: true,
          onPressed: () => MainShell.push(context, const DiningScreen()),
        ),
      ],
    );
  }
}

class _DriverRow extends StatelessWidget {
  const _DriverRow({
    required this.icon,
    required this.driver,
    required this.isLast,
  });

  final IconData icon;
  final BriefDriver driver;
  final bool isLast;

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
        vertical: 14,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.space3,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 15, color: AppColors.faint),
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
                    height: 1.38,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  driver.detail,
                  style: AppTextStyles.cardMeta.copyWith(
                    fontSize: 11,
                    height: 1.45,
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

class _Caveats extends StatelessWidget {
  const _Caveats({required this.caveats});

  final List<String> caveats;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.space4),
      decoration: BoxDecoration(
        color: AppColors.ink.withValues(alpha: 0.04),
        border: Border.all(color: AppColors.hairline),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'WHAT THIS BRIEF COULD NOT SEE',
            style: AppTextStyles.tag.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: AppColors.faint,
            ),
          ),
          for (final caveat in caveats)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '• $caveat',
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
