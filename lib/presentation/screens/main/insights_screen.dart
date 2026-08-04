import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/screen_back_button.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../domain/entities/health/metric_key.dart';
import '../../../domain/entities/insights/correlation.dart';
import '../../../domain/entities/insights/insight.dart';
import '../../providers/health_providers.dart';
import '../../providers/insights_providers.dart';
import '../../providers/settings_providers.dart';
import '../../widgets/labs/biomarker_table.dart';
import 'main_shell.dart';
import 'upload_screen.dart';

/// Findings from the correlation engine. Mirrors `app/(tabs)/insights.tsx` and
/// `src/components/insights/InsightCard.tsx` one-for-one.
///
/// A flat, ranked list — severity then score — rather than any grouping of our
/// own. The engine already decided the order, and a second organising principle
/// layered on top only buries the top finding.
///
/// Cards can be dismissed and dismissals persist: a user who has read a finding
/// and acted on it should not meet it again every morning. The dismissed set
/// stays restorable rather than deleted, because the engine will keep producing
/// the finding for as long as the data supports it.
class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insights = ref.watch(insightsProvider);
    final dismissed = ref.watch(dismissedInsightsProvider);
    final urgentCount = ref.watch(urgentInsightCountProvider);
    final hasLabData = ref.watch(hasLabDataProvider);
    final hasTelemetry = ref.watch(hasTelemetryProvider);
    final loading = ref.watch(healthSeriesProvider).isLoading;

    Future<void> refresh() => ref.refresh(healthSeriesProvider.future);

    return RefreshIndicator(
      color: AppColors.brand,
      onRefresh: refresh,
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
              spacing: AppSpacing.space3,
              children: [
                const ScreenBackButton(),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Insights', style: AppTextStyles.screenTitle),
                      const SizedBox(height: 6),
                      Text(
                        hasLabData
                            ? 'Where your blood work and your daily telemetry '
                                  'agree. Nothing here is a diagnosis.'
                            : 'Patterns found in your telemetry. Add a blood '
                                  'report to unlock the correlations.',
                        style: AppTextStyles.cardBody.copyWith(height: 20 / 13),
                      ),
                    ],
                  ),
                ),
                AppButton(
                  label: 'Refresh',
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.sm,
                  leading: const Icon(Icons.refresh, size: 14),
                  onPressed: refresh,
                ),
              ],
            ),
          ),

          if (urgentCount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.space5,
                AppSpacing.space4,
                AppSpacing.space5,
                0,
              ),
              child: _UrgentBanner(count: urgentCount),
            ),

          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.space5,
              AppSpacing.space5,
              AppSpacing.space5,
              0,
            ),
            child: loading && insights.isEmpty
                ? const Column(
                    spacing: AppSpacing.space3,
                    children: [_InsightCardSkeleton(), _InsightCardSkeleton()],
                  )
                : insights.isEmpty
                ? EmptyState(
                    icon: Icons.lightbulb_outline,
                    title: hasTelemetry
                        ? 'Nothing to flag right now'
                        : 'No data to analyse yet',
                    body: hasTelemetry
                        ? 'Your telemetry is tracking your baseline and no lab '
                              'value is out of band. We will surface something '
                              'the moment that changes.'
                        : 'Connect $healthStoreName and add a blood report — '
                              'insights appear once there is something to '
                              'correlate.',
                    actionLabel: hasLabData ? null : 'Add a blood report',
                    onAction: hasLabData
                        ? null
                        : () => MainShell.push(context, const UploadScreen()),
                  )
                : Column(
                    spacing: AppSpacing.space3,
                    children: [
                      for (final insight in insights)
                        InsightCard(insight: insight),
                    ],
                  ),
          ),

          if (dismissed.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.space5,
                AppSpacing.space4,
                AppSpacing.space5,
                0,
              ),
              child: AppButton(
                label: 'Restore ${dismissed.length} dismissed',
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.sm,
                block: true,
                leading: const Icon(Icons.restore, size: 14),
                onPressed: () =>
                    ref.read(settingsProvider.notifier).clearDismissed(),
              ),
            ),

          if (insights.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.space8,
                AppSpacing.space6,
                AppSpacing.space8,
                0,
              ),
              child: Text(
                'These are statistical associations in your own data, not '
                'medical advice. Discuss any change to medication or treatment '
                'with a clinician.',
                textAlign: TextAlign.center,
                style: AppTextStyles.cardMeta.copyWith(
                  height: 16 / 11,
                  color: AppColors.faint.withValues(alpha: 0.8),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The one thing that outranks everything else on the screen.
class _UrgentBanner extends StatelessWidget {
  const _UrgentBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space4,
        vertical: AppSpacing.space3,
      ),
      decoration: BoxDecoration(
        color: AppColors.critical.withValues(alpha: 0.12),
        border: Border.all(color: AppColors.critical.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        spacing: AppSpacing.space2 + 2,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.critical,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              count == 1
                  ? 'One finding is worth taking to a clinician.'
                  : '$count findings are worth taking to a clinician.',
              style: AppTextStyles.cardBody.copyWith(
                fontSize: 12,
                height: 16 / 12,
                color: AppColors.ink.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One finding: severity rail, domain glyph, badge, headline, evidence, and the
/// suggestions behind a disclosure.
///
/// Only the disclosure row toggles — the card body is not a tap target, so
/// selecting the summary text or a citation never collapses what you are
/// reading.
class InsightCard extends ConsumerStatefulWidget {
  const InsightCard({
    super.key,
    required this.insight,
    this.dismissible = true,
    this.defaultExpanded = false,
  });

  final Insight insight;

  final bool dismissible;

  /// Expanded by default in a detail view, collapsed in feeds.
  final bool defaultExpanded;

  @override
  ConsumerState<InsightCard> createState() => _InsightCardState();
}

class _InsightCardState extends ConsumerState<InsightCard> {
  late bool _expanded = widget.defaultExpanded;

  static const Map<InsightDomain, IconData> _domainIcon = {
    InsightDomain.nutrition: Icons.restaurant_outlined,
    InsightDomain.training: Icons.fitness_center,
    InsightDomain.sleep: Icons.bed_outlined,
    InsightDomain.recovery: Icons.monitor_heart_outlined,
    InsightDomain.stress: Icons.show_chart,
    InsightDomain.medicalReferral: Icons.medical_services_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final insight = widget.insight;
    final severityColour = insight.severity.color;
    final evidence = insight.evidence;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Severity rail — a colour cue that survives greyscale accessibility
          // modes because it is paired with the text badge below.
          Container(height: 4, width: double.infinity, color: severityColour),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: AppSpacing.space3,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.ink.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Icon(
                        _domainIcon[insight.domain],
                        size: 19,
                        color: AppColors.ink,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Badge(
                            label: insight.severity.label,
                            colour: severityColour,
                          ),
                          const SizedBox(height: AppSpacing.space2),
                          Text(
                            insight.title,
                            style: AppTextStyles.h5.copyWith(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              height: 24 / 17,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.dismissible)
                      _DismissButton(insight: insight),
                  ],
                ),

                const SizedBox(height: AppSpacing.space3),
                Text(
                  insight.summary,
                  style: AppTextStyles.bodySmall.copyWith(
                    height: 21 / 14,
                    color: AppColors.ink.withValues(alpha: 0.7),
                  ),
                ),

                // Evidence chips: the biomarkers that fired the rule.
                if (evidence.biomarkers.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.space4),
                    child: Wrap(
                      spacing: AppSpacing.space2,
                      runSpacing: AppSpacing.space2,
                      children: [
                        for (final biomarker in evidence.biomarkers)
                          _BiomarkerChip(biomarker: biomarker),
                      ],
                    ),
                  ),

                if (evidence.telemetryNote != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.space3),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.space3,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.ink.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        spacing: AppSpacing.space2,
                        children: [
                          const Icon(
                            Icons.show_chart,
                            size: 14,
                            color: AppColors.faint,
                          ),
                          Expanded(
                            child: Text(
                              evidence.telemetryNote!,
                              style: AppTextStyles.cardBody.copyWith(
                                fontSize: 12,
                                height: 16 / 12,
                                color: AppColors.ink.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.space4),
                  child: Semantics(
                    button: true,
                    label: _expanded ? 'Hide details' : 'Show what to do',
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _expanded = !_expanded);
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: 6,
                        children: [
                          Text(
                            _expanded
                                ? 'Hide details'
                                : 'What to do (${insight.suggestions.length})',
                            style: AppTextStyles.bodySmall.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Icon(
                            _expanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            size: 18,
                            color: AppColors.ink,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                if (_expanded) _Detail(insight: insight),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// `self-start` pill whose fill and border are both derived from one colour.
class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.colour});

  final String label;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space2, vertical: 2),
      decoration: BoxDecoration(
        // `${color}22` over `${color}55` in the React Native original.
        color: colour.withValues(alpha: 0.13),
        border: Border.all(color: colour.withValues(alpha: 0.33)),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: AppTextStyles.tag.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
          color: colour,
        ),
      ),
    );
  }
}

class _DismissButton extends ConsumerWidget {
  const _DismissButton({required this.insight});

  final Insight insight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Semantics(
      button: true,
      label: 'Dismiss insight',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          HapticFeedback.lightImpact();
          ref.read(settingsProvider.notifier).dismissInsight(insight.id);
        },
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.ink.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.close, size: 13, color: AppColors.ink),
        ),
      ),
    );
  }
}

/// Everything behind the disclosure: the suggestions, then the evidence for
/// them — what was found in the user's own data, and what it rests on.
class _Detail extends StatelessWidget {
  const _Detail({required this.insight});

  final Insight insight;

  @override
  Widget build(BuildContext context) {
    final evidence = insight.evidence;
    final suggestions = insight.suggestionsByEffort;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.space3),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.ink.withValues(alpha: 0.1)),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < suggestions.length; i += 1)
                _SuggestionRow(
                  suggestion: suggestions[i],
                  isLast: i == suggestions.length - 1,
                ),

              if (evidence.correlations.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.space3),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.space3),
                    decoration: BoxDecoration(
                      color: AppColors.ink.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FOUND IN YOUR OWN DATA',
                          style: AppTextStyles.tag.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                            color: AppColors.ink.withValues(alpha: 0.45),
                          ),
                        ),
                        for (final correlation in evidence.correlations)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              _describeCorrelation(correlation),
                              style: AppTextStyles.cardBody.copyWith(
                                fontSize: 12,
                                height: 16 / 12,
                                color: AppColors.ink.withValues(alpha: 0.65),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

              if (evidence.citations.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.space3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final citation in evidence.citations)
                        _CitationLink(citation: citation),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// The card's own phrasing, not the engine's: here the correlation is being
  /// offered as evidence for a claim already made above, so it leads with the
  /// metric and ends with the coefficient.
  static String _describeCorrelation(Correlation correlation) {
    final direction = correlation.r > 0
        ? 'rises and falls with'
        : 'moves inversely to';
    final lag = correlation.lagDays > 0
        ? ' (${correlation.lagDays}-day lag)'
        : '';
    final label = metricMeta[correlation.metric]!.label;
    return '$label $direction this pattern across ${correlation.n} days$lag '
        '· r = ${correlation.r}';
  }
}

class _BiomarkerChip extends StatelessWidget {
  const _BiomarkerChip({required this.biomarker});

  final EvidenceBiomarker biomarker;

  @override
  Widget build(BuildContext context) {
    final colour = flagColour(biomarker.flag);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: colour.withValues(alpha: 0.33)),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          Text(
            biomarker.displayName,
            style: AppTextStyles.cardMeta.copyWith(
              color: AppColors.ink.withValues(alpha: 0.6),
            ),
          ),
          Text(
            biomarker.valueWithUnit,
            style: AppTextStyles.tag.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
              color: colour,
            ),
          ),
        ],
      ),
    );
  }
}

/// Effort and horizon are shown, not hidden: "this takes 6 weeks to move" is
/// what stops someone abandoning it in week two.
class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({required this.suggestion, required this.isLast});

  final Suggestion suggestion;
  final bool isLast;

  static const _effortLabel = {
    SuggestionEffort.low: 'Easy',
    SuggestionEffort.medium: 'Moderate',
    SuggestionEffort.high: 'Committed',
  };

  static const _effortColour = {
    SuggestionEffort.low: AppColors.optimal,
    SuggestionEffort.medium: AppColors.borderline,
    SuggestionEffort.high: AppColors.abnormal,
  };

  static String _horizonLabel(int days) {
    if (days <= 14) return '$days days';
    if (days <= 60) return '${(days / 7).round()} weeks';
    return '${(days / 30).round()} months';
  }

  @override
  Widget build(BuildContext context) {
    final colour = _effortColour[suggestion.effort]!;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                  color: AppColors.ink.withValues(alpha: 0.08),
                ),
              ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            suggestion.title,
            style: AppTextStyles.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            suggestion.detail,
            style: AppTextStyles.cardBody.copyWith(
              height: 19 / 13,
              color: AppColors.ink.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            spacing: AppSpacing.space4,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 6,
                children: [
                  Icon(Icons.speed, size: 12, color: colour),
                  Text(
                    _effortLabel[suggestion.effort]!,
                    style: AppTextStyles.tag.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                      color: colour,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 6,
                children: [
                  const Icon(
                    Icons.schedule,
                    size: 12,
                    color: AppColors.faint,
                  ),
                  Text(
                    'Signal in ~${_horizonLabel(suggestion.horizonDays)}',
                    style: AppTextStyles.cardMeta.copyWith(
                      color: AppColors.ink.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CitationLink extends StatelessWidget {
  const _CitationLink({required this.citation});

  final Citation citation;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Semantics(
        link: true,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            launchUrl(
              Uri.parse(citation.url),
              mode: LaunchMode.externalApplication,
            );
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: [
              const Icon(
                Icons.open_in_new,
                size: 12,
                color: AppColors.faint,
              ),
              Flexible(
                child: Text(
                  citation.label,
                  style: AppTextStyles.cardMeta.copyWith(
                    decoration: TextDecoration.underline,
                    color: AppColors.ink.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Holds the card's shape while the first series loads, rather than collapsing
/// the list to a spinner.
class _InsightCardSkeleton extends StatelessWidget {
  const _InsightCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.ink.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Skeleton(height: 16, width: 96, radius: AppRadius.sm),
          SizedBox(height: AppSpacing.space4),
          Skeleton(height: 20, radius: AppRadius.sm),
          SizedBox(height: AppSpacing.space2),
          FractionallySizedBox(
            widthFactor: 0.75,
            alignment: Alignment.centerLeft,
            child: Skeleton(height: 20, radius: AppRadius.sm),
          ),
          SizedBox(height: AppSpacing.space5),
          Skeleton(height: 12, radius: AppRadius.sm),
          SizedBox(height: AppSpacing.space2),
          FractionallySizedBox(
            widthFactor: 0.833,
            alignment: Alignment.centerLeft,
            child: Skeleton(height: 12, radius: AppRadius.sm),
          ),
        ],
      ),
    );
  }
}
