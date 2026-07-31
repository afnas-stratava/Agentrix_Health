import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/stats/stats.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_tag.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/screen_back_button.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../domain/entities/insights/correlation.dart';
import '../../../domain/entities/insights/insight.dart';
import '../../../features/correlation/engine.dart';
import '../../providers/health_providers.dart';
import '../../providers/insights_providers.dart';
import '../../providers/settings_providers.dart';
import '../../widgets/labs/biomarker_table.dart';
import 'main_shell.dart';
import 'upload_screen.dart';

/// Findings from the correlation engine. Mirrors `app/(tabs)/insights.tsx`.
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
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space6),
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
                        style: AppTextStyles.cardBody.copyWith(height: 1.5),
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
                AppSpacing.space6,
                AppSpacing.space4,
                AppSpacing.space6,
                0,
              ),
              child: _UrgentBanner(count: urgentCount),
            ),

          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.space6,
              AppSpacing.space5,
              AppSpacing.space6,
              0,
            ),
            child: loading && insights.isEmpty
                ? const Column(
                    spacing: AppSpacing.space3,
                    children: [Skeleton(height: 168), Skeleton(height: 168)],
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
                        : 'Connect Apple Health and add a blood report — '
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
                        _InsightCard(insight: insight),
                    ],
                  ),
          ),

          if (dismissed.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.space6,
                AppSpacing.space4,
                AppSpacing.space6,
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
                height: 1.4,
                color: AppColors.ink.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One finding, expandable into its evidence and suggested actions, dismissable
/// from its own header.
class _InsightCard extends ConsumerStatefulWidget {
  const _InsightCard({required this.insight});

  final Insight insight;

  @override
  ConsumerState<_InsightCard> createState() => _InsightCardState();
}

class _InsightCardState extends ConsumerState<_InsightCard> {
  bool _expanded = false;

  static Color _severityColour(InsightSeverity severity) => switch (severity) {
    InsightSeverity.urgent => AppColors.critical,
    InsightSeverity.action => AppColors.abnormal,
    InsightSeverity.watch => AppColors.borderline,
    InsightSeverity.info => AppColors.normal,
  };

  @override
  Widget build(BuildContext context) {
    final insight = widget.insight;
    final colour = _severityColour(insight.severity);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.hairline),
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.sm,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Severity as a bar rather than a tinted card: a full red panel on a
          // health finding reads as alarm, and the strongest thing this screen
          // can say is "take this to a clinician".
          Container(height: 3, color: colour),
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.space4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    spacing: AppSpacing.space2,
                    children: [
                      Text(
                        insight.severity.label.toUpperCase(),
                        style: AppTextStyles.tag.copyWith(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          color: colour,
                        ),
                      ),
                      AppTag(
                        label: insight.domain.label,
                        variant: AppTagVariant.neutral,
                      ),
                      const Spacer(),
                      _DismissButton(insight: insight),
                      Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        size: 18,
                        color: AppColors.faint,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.space2),
                  Text(
                    insight.title,
                    style: AppTextStyles.h5.copyWith(height: 1.3),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    insight.summary,
                    maxLines: _expanded ? null : 3,
                    overflow: _expanded ? null : TextOverflow.ellipsis,
                    style: AppTextStyles.cardBody.copyWith(height: 1.5),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) _Detail(insight: insight),
        ],
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
      label: 'Dismiss this finding',
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: () =>
            ref.read(settingsProvider.notifier).dismissInsight(insight.id),
        child: const Padding(
          padding: EdgeInsets.all(4),
          child: Icon(Icons.close, size: 15, color: AppColors.faint),
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.insight});

  final Insight insight;

  @override
  Widget build(BuildContext context) {
    final evidence = insight.evidence;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.space4),
      decoration: const BoxDecoration(
        color: AppColors.canvas,
        border: Border(top: BorderSide(color: AppColors.hairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _MicroLabel('Evidence'),

          if (evidence.biomarkers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.space2),
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
            _EvidenceRow(
              icon: Icons.monitor_heart_outlined,
              text: evidence.telemetryNote!,
            ),

          for (final correlation in evidence.correlations)
            _EvidenceRow(
              icon: Icons.show_chart,
              text: describeCorrelation(correlation),
              // A non-significant link never reaches here, but if one ever did
              // it must not read as a finding.
              muted: correlation.strength == CorrelationStrength.none,
            ),

          const SizedBox(height: AppSpacing.space4),
          const _MicroLabel('What to do'),
          for (final suggestion in insight.suggestionsByEffort)
            _SuggestionRow(suggestion: suggestion),

          if (evidence.citations.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.space4),
            const _MicroLabel('Reference'),
            for (final citation in evidence.citations)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  citation.label,
                  style: AppTextStyles.cardMeta.copyWith(
                    fontSize: 11,
                    color: AppColors.brand600,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _MicroLabel extends StatelessWidget {
  const _MicroLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.space2),
      child: Text(
        label.toUpperCase(),
        style: AppTextStyles.tag.copyWith(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
          color: AppColors.muted,
        ),
      ),
    );
  }
}

class _BiomarkerChip extends StatelessWidget {
  const _BiomarkerChip({required this.biomarker});

  final EvidenceBiomarker biomarker;

  @override
  Widget build(BuildContext context) {
    final colour = flagColour(biomarker.flag);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space2 + 2,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: colour.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 5,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
          ),
          Text(
            '${biomarker.displayName} ${biomarker.valueWithUnit}',
            style: AppTextStyles.cardMeta.copyWith(
              fontSize: 11,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _EvidenceRow extends StatelessWidget {
  const _EvidenceRow({
    required this.icon,
    required this.text,
    this.muted = false,
  });

  final IconData icon;
  final String text;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.space2,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              icon,
              size: 12,
              color: muted ? AppColors.faint : AppColors.brand,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.cardBody.copyWith(
                height: 1.45,
                color: muted ? AppColors.faint : AppColors.muted,
              ),
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
  const _SuggestionRow({required this.suggestion});

  final Suggestion suggestion;

  static const _effortLabel = {
    SuggestionEffort.low: 'Easy',
    SuggestionEffort.medium: 'Moderate',
    SuggestionEffort.high: 'Hard',
  };

  @override
  Widget build(BuildContext context) {
    final weeks = (suggestion.horizonDays / 7).round();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            spacing: AppSpacing.space2,
            children: [
              Expanded(
                child: Text(
                  suggestion.title,
                  style: AppTextStyles.bodySmall.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${_effortLabel[suggestion.effort]} · '
                '${weeks <= 1 ? '1 wk' : '$weeks wks'}',
                style: AppTextStyles.cardMeta.copyWith(fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            suggestion.detail,
            style: AppTextStyles.cardBody.copyWith(height: 1.45),
          ),
        ],
      ),
    );
  }
}
