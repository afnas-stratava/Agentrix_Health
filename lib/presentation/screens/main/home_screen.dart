import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/fade_in.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../domain/entities/health/metric_key.dart';
import '../../providers/brief_providers.dart';
import '../../providers/health_providers.dart';
import '../../providers/insights_providers.dart';
import '../../providers/labs_providers.dart';
import '../../providers/main_tab_provider.dart';
import '../../providers/nutrition_providers.dart';
import '../../providers/user_profile_provider.dart';
import '../../../core/widgets/surface_card.dart';
import '../../widgets/health/readiness_hero.dart';
import '../../widgets/insights/action_row.dart';
import '../../widgets/insights/headline_insight.dart';
import '../../widgets/labs/lab_status_card.dart';
import '../../widgets/health/stat_tile.dart';
import 'dining_screen.dart';
import 'lab_report_screen.dart';
import 'log_meal_screen.dart';
import 'main_shell.dart';
import 'metric_detail_screen.dart';
import 'morning_brief_screen.dart';
import 'upload_screen.dart';

/// Mirrors `app/(tabs)/today.tsx`.
///
/// Section order is an argument rather than a layout: the urgent banner outranks
/// everything, because "see a clinician" is not a thing to scroll past; the brief
/// sits above readiness because it *contains* readiness; the score outranks the
/// raw signals that produced it; and the findings sit below the signals because
/// they are read once rather than monitored.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  /// How many actions to surface before deferring to the Insights tab.
  static const int _maxActions = 3;

  static String _greeting([DateTime? now]) {
    final hour = (now ?? DateTime.now()).hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  /// The tiles used to be dead ends. Every one now opens the metric's own
  /// history, baseline comparison and correlations.
  static void _openMetric(BuildContext context, MetricKey metric) =>
      MainShell.push(context, MetricDetailScreen(metric: metric));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final seriesAsync = ref.watch(healthSeriesProvider);
    final metrics = ref.watch(metricStatsProvider);
    final readiness = ref.watch(readinessProvider);
    final brief = ref.watch(dailyBriefProvider);
    final briefTeaser = ref.watch(briefTeaserProvider);
    final insights = ref.watch(insightsProvider);
    final headline = ref.watch(headlineInsightProvider);
    final urgentCount = ref.watch(urgentInsightCountProvider);
    final hasLabData = ref.watch(hasLabDataProvider);
    final feed = ref.watch(suggestionFeedProvider);
    final targets = ref.watch(nutritionTargetsProvider);
    final consumed = ref.watch(consumedTodayProvider);
    final report = ref.watch(latestLabReportProvider);
    final flaggedCount = ref
        .watch(mergedBiomarkersProvider)
        .where((b) => b.flag.needsAttention)
        .length;

    final loading = seriesAsync.isLoading;
    final series = seriesAsync.valueOrNull;
    final synced = syncLabel(ref.watch(lastSyncedAtProvider));
    final syntheticData =
        ref.watch(telemetrySourceProvider) == TelemetrySource.synthetic;

    final actions = feed.take(_maxActions).toList();
    final remaining = targets == null
        ? null
        : targets.calories - consumed.calories;

    void openLatestReportOrUpload() {
      if (report != null) {
        MainShell.push(context, LabReportScreen(reportId: report.id));
      } else {
        MainShell.push(context, const UploadScreen());
      }
    }

    // The green wash behind this screen is painted by `MainShell`, outside the
    // safe area, so it reaches behind the status bar.
    return RefreshIndicator(
      color: AppColors.brand,
      onRefresh: () => ref.refresh(healthSeriesProvider.future),
      child: ListView(
        padding: EdgeInsets.only(
          top: AppSpacing.space1,
          bottom: MainShell.bottomInsetFor(context),
        ),
        children: [
          // HEADER
          _Header(
            date: DateFormat('EEEE, d MMMM').format(DateTime.now()),
            synced: synced,
            greeting: _greeting(),
            refreshing: loading,
            onRefresh: () => ref.invalidate(healthSeriesProvider),
            onSettings: () =>
                ref.read(mainTabProvider.notifier).select(MainTab.settings),
          ),

          // URGENT — the one thing that outranks readiness. Tappable, because a
          // "see a clinician" banner that goes nowhere is the one dead end on
          // this screen a user would actually try to follow.
          if (urgentCount > 0)
            _Section(
              delay: 0,
              child: _UrgentBanner(
                count: urgentCount,
                onTap: () =>
                    ref.read(mainTabProvider.notifier).select(MainTab.insights),
              ),
            ),

          // MORNING BRIEF — the composed plan. Above readiness because the score
          // is an input to it, and a user who reads one thing should read the
          // plan, not the number.
          //
          // Rendered even before a plan exists: a section that vanishes reads
          // as a broken screen, where an empty one reads as "not yet".
          _Section(
            delay: 20,
            child: _BriefCard(
              headline: brief?.headline ?? briefTeaser,
              detail: brief == null
                  ? null
                  : '${brief.workout.title} · ${brief.foodFocus.title}',
              onTap: () => MainShell.push(context, const MorningBriefScreen()),
            ),
          ),

          // HERO
          _Section(
            delay: 40,
            child: loading && metrics == null
                ? const Skeleton(height: 248)
                : ReadinessHero(
                    readiness: readiness,
                    fallbackHint:
                        'Keep wearing your watch — seven days of data unlocks '
                        'your score.',
                    onTap: () => ref
                        .read(mainTabProvider.notifier)
                        .select(MainTab.insights),
                  ),
          ),

          // PRIMARY SIGNALS — HRV and resting HR carry 65% of readiness.
          _Section(
            delay: 120,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(
                  title: 'Your signals',
                  actionLabel: series == null ? null : '${series.length} days',
                  onAction: series == null
                      ? null
                      : () => ref.invalidate(healthSeriesProvider),
                ),
                if (metrics == null)
                  const Column(
                    spacing: 10,
                    children: [
                      Row(
                        spacing: 10,
                        children: [
                          Expanded(child: Skeleton(height: 150)),
                          Expanded(child: Skeleton(height: 150)),
                        ],
                      ),
                      Skeleton(height: 84, radius: AppRadius.md),
                    ],
                  )
                else
                  Column(
                    spacing: 10,
                    children: [
                      Row(
                        spacing: 10,
                        children: [
                          for (final key in const [
                            MetricKey.hrv,
                            MetricKey.restingHeartRate,
                          ])
                            Expanded(
                              child: StatTile(
                                stats: metrics[key]!,
                                onTap: () => _openMetric(context, key),
                              ),
                            ),
                        ],
                      ),
                      Row(
                        spacing: AppSpacing.space2,
                        children: [
                          for (final key in const [
                            MetricKey.sleepDuration,
                            MetricKey.sleepEfficiency,
                            MetricKey.steps,
                            MetricKey.activeEnergy,
                          ])
                            Expanded(
                              child: SignalChip(
                                stats: metrics[key]!,
                                onTap: () => _openMetric(context, key),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // FUEL — today's intake against today's target, and the way into the
          // restaurant picker. Shown with a dashed-out target rather than
          // hidden when there is nothing to compare against: what is logged is
          // known either way, and the row is the way into the food log.
          _Section(
            delay: 160,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(
                  title: 'Fuel',
                  actionLabel: 'Log a meal',
                  onAction: () =>
                      MainShell.push(context, const LogMealScreen()),
                ),
                _FuelCard(
                  caloriesConsumed: consumed.calories,
                  caloriesTarget: targets?.calories,
                  proteinConsumed: consumed.proteinG,
                  proteinTarget: targets?.macros.proteinG,
                  remaining: remaining,
                  isCheatDay: targets?.isCheatDay ?? false,
                  // Height and weight are assumed when absent; age is the one
                  // input nothing can stand in for, so it is what to ask for.
                  noTargetHint: profile.ageYears == null
                      ? 'Add your age in Settings for a daily target'
                      : 'No daily target yet',
                  onOpenFood: () =>
                      ref.read(mainTabProvider.notifier).select(MainTab.food),
                  onOpenDining: () =>
                      MainShell.push(context, const DiningScreen()),
                ),
              ],
            ),
          ),

          // HEADLINE FINDING — the product's differentiator.
          _Section(
            delay: 200,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(
                  title: 'What we found',
                  count: insights.length,
                  actionLabel: insights.length > 1 ? 'See all' : null,
                  onAction: insights.length > 1
                      ? () => ref
                            .read(mainTabProvider.notifier)
                            .select(MainTab.insights)
                      : null,
                ),
                if (loading && metrics == null)
                  const Skeleton(height: 168)
                else if (headline != null)
                  HeadlineInsight(
                    insight: headline,
                    onTap: () => ref
                        .read(mainTabProvider.notifier)
                        .select(MainTab.insights),
                  )
                else
                  _NoFindings(hasLabData: hasLabData),
              ],
            ),
          ),

          // ACTIONS — a vertical list, nothing hidden behind a swipe.
          _Section(
            delay: 280,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(title: 'Do this today', count: actions.length),
                if (actions.isEmpty)
                  const _EmptyRow(
                    icon: Icons.check_circle_outline,
                    text:
                        'Nothing queued right now — as new findings appear, '
                        'we will place the next best action here.',
                  )
                else
                  SurfaceCard(
                    padded: false,
                    child: Column(
                      children: [
                        for (final entry in actions)
                          ActionRow(
                            suggestion: entry.suggestion,
                            source: entry.source,
                            isLast: entry == actions.last,
                            onTap: () => ref
                                .read(mainTabProvider.notifier)
                                .select(MainTab.insights),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // LAB STATUS — keeps the correlation half of the product alive.
          _Section(
            delay: 340,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(
                  title: 'Blood work',
                  actionLabel: report != null ? 'Open latest' : 'Add report',
                  onAction: openLatestReportOrUpload,
                ),
                LabStatusCard(
                  report: report,
                  flaggedCount: flaggedCount,
                  onTap: openLatestReportOrUpload,
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
              // Never let sample telemetry read as the user's own.
              syntheticData
                  ? 'Showing a sample 35-day telemetry series — connect Apple '
                        'Health for your own. Not medical advice, and not a '
                        'diagnosis.'
                  : 'Statistical associations in your own data — not medical '
                        'advice, and not a diagnosis.',
              textAlign: TextAlign.center,
              style: AppTextStyles.cardMeta.copyWith(fontSize: 10, height: 1.5),
            ),
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
        AppSpacing.space4,
        AppSpacing.space5,
        0,
      ),
      child: FadeIn(
        delay: Duration(milliseconds: delay),
        child: child,
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.date,
    required this.synced,
    required this.greeting,
    required this.refreshing,
    required this.onRefresh,
    required this.onSettings,
  });

  final String date;
  final String? synced;
  final String greeting;
  final bool refreshing;
  final VoidCallback onRefresh;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space5),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  spacing: 6,
                  children: [
                    Text(
                      date,
                      style: AppTextStyles.cardMeta.copyWith(
                        fontSize: 11,
                        color: AppColors.muted,
                      ),
                    ),
                    if (synced != null) ...[
                      Container(
                        width: 3,
                        height: 3,
                        decoration: const BoxDecoration(
                          color: AppColors.faint,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Text(
                        synced!,
                        style: AppTextStyles.cardMeta.copyWith(fontSize: 11),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(greeting, style: AppTextStyles.h3.copyWith(fontSize: 25)),
              ],
            ),
          ),
          Row(
            spacing: AppSpacing.space2,
            children: [
              AppButton.icon(
                leading: refreshing
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.brand,
                        ),
                      )
                    : const Icon(Icons.refresh, size: 16),
                onPressed: refreshing ? null : onRefresh,
              ),
              AppButton.icon(
                leading: const Icon(Icons.tune, size: 16),
                onPressed: onSettings,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UrgentBanner extends StatelessWidget {
  const _UrgentBanner({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final message = count == 1
        ? 'One finding is worth taking to a clinician.'
        : '$count findings are worth taking to a clinician.';

    return PressableScale(
      scaleTo: 0.98,
      semanticLabel: message,
      semanticHint: 'Opens the full findings list',
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space4,
          vertical: AppSpacing.space3,
        ),
        decoration: BoxDecoration(
          color: AppColors.critical.withValues(alpha: 0.08),
          border: Border.all(color: AppColors.critical.withValues(alpha: 0.25)),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          spacing: AppSpacing.space2 + 2,
          children: [
            const Icon(
              Icons.shield_outlined,
              size: 17,
              color: AppColors.critical,
            ),
            Expanded(
              child: Text(
                message,
                style: AppTextStyles.cardBody.copyWith(
                  fontSize: 12,
                  height: 1.4,
                  color: AppColors.ink.withValues(alpha: 0.8),
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 15,
              color: AppColors.critical,
            ),
          ],
        ),
      ),
    );
  }
}

class _BriefCard extends StatelessWidget {
  const _BriefCard({
    required this.headline,
    required this.detail,
    required this.onTap,
  });

  final String headline;

  /// Null while the plan is still being composed — the headline carries the
  /// "not yet" on its own rather than the card showing an empty second line.
  final String? detail;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      scaleTo: 0.98,
      semanticLabel: 'Your morning brief: $headline',
      semanticHint: "Opens today's full plan",
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: AppColors.brand50,
          border: Border.all(color: AppColors.brand200),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              spacing: AppSpacing.space2,
              children: [
                const Icon(
                  Icons.auto_awesome,
                  size: 15,
                  color: AppColors.brand,
                ),
                Expanded(
                  child: Text(
                    'YOUR BRIEF FOR TODAY',
                    style: AppTextStyles.tag.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: AppColors.brand700,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 15,
                  color: AppColors.brand,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(headline, style: AppTextStyles.h5.copyWith(height: 1.33)),
            if (detail != null) ...[
              const SizedBox(height: 4),
              Text(
                detail!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.cardBody.copyWith(height: 1.4),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Two rows in one card: the day's intake, and the way out to the restaurant
/// picker. One card rather than two because they answer the same question —
/// "what do I eat next" — from different directions.
class _FuelCard extends StatelessWidget {
  const _FuelCard({
    required this.caloriesConsumed,
    required this.caloriesTarget,
    required this.proteinConsumed,
    required this.proteinTarget,
    required this.remaining,
    required this.isCheatDay,
    required this.noTargetHint,
    required this.onOpenFood,
    required this.onOpenDining,
  });

  final int caloriesConsumed;

  /// Null until the profile carries enough to compute one.
  final int? caloriesTarget;

  final double proteinConsumed;
  final int? proteinTarget;
  final int? remaining;
  final bool isCheatDay;

  /// Shown in place of the protein line when there is no target.
  final String noTargetHint;

  final VoidCallback onOpenFood;
  final VoidCallback onOpenDining;

  @override
  Widget build(BuildContext context) {
    final target = caloriesTarget;
    // An empty track, not a full one: with no target there is nothing to be
    // any fraction of.
    final progress = target == null
        ? 0.0
        : (caloriesConsumed / target.clamp(1, 100000)).clamp(0.0, 1.0);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.hairline),
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.sm,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          PressableScale(
            scaleTo: 0.99,
            semanticLabel: target == null
                ? '$caloriesConsumed calories logged today, no target set'
                : '$caloriesConsumed of $target calories eaten today',
            onTap: onOpenFood,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                spacing: AppSpacing.space3,
                children: [
                  const _RowIcon(Icons.local_fire_department_outlined),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          remaining != null && remaining! > 0
                              ? '$remaining kcal left today'
                              : '$caloriesConsumed kcal logged',
                          style: AppTextStyles.cardTitle.copyWith(fontSize: 14),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          proteinTarget == null
                              ? '${proteinConsumed.round()} g protein · '
                                    '$noTargetHint'
                              : '${proteinConsumed.round()} of $proteinTarget g '
                                    'protein${isCheatDay ? ' · cheat day' : ''}',
                          style: AppTextStyles.cardMeta.copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  // "Never render 0 / 0": with no target there is no ratio to
                  // draw, so the bar is absent rather than empty.
                  if (target != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: SizedBox(
                        width: 64,
                        height: 8,
                        child: ColoredBox(
                          color: const Color(0xFFE7EFE7),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: progress,
                            heightFactor: 1,
                            child: const ColoredBox(
                              color: AppColors.limeStrong,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          PressableScale(
            scaleTo: 0.99,
            semanticLabel: 'Find somewhere to eat nearby',
            onTap: onOpenDining,
            child: Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.hairline)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                spacing: AppSpacing.space3,
                children: [
                  const _RowIcon(Icons.place_outlined),
                  Expanded(
                    child: Text(
                      'Eating out?',
                      style: AppTextStyles.cardTitle.copyWith(fontSize: 14),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: 15,
                    color: AppColors.faint,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RowIcon extends StatelessWidget {
  const _RowIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.brand50,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, size: 19, color: AppColors.brand),
    );
  }
}

/// A section that has nothing in it yet, kept on screen rather than dropped.
///
/// The quieter sibling of [_NoFindings]: one line, no title, because the
/// section header above it has already said what this is.
class _EmptyRow extends StatelessWidget {
  const _EmptyRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space4,
        vertical: AppSpacing.space4,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.hairline),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.space3,
        children: [
          Icon(icon, size: 17, color: AppColors.faint),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.cardBody.copyWith(height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoFindings extends StatelessWidget {
  const _NoFindings({required this.hasLabData});

  final bool hasLabData;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.space4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.hairline),
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.space3,
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: 19,
            color: AppColors.optimal,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasLabData ? 'Nothing to flag today' : 'No correlations yet',
                  style: AppTextStyles.cardTitle.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  hasLabData
                      ? 'Your telemetry is tracking its baseline and no lab '
                            'value is out of band. We will surface something '
                            'the moment that changes.'
                      : 'Add a blood report and we can start pairing your '
                            'biomarkers against these daily trends.',
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
