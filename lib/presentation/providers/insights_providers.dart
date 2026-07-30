import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/insights/correlation.dart';
import '../../domain/entities/insights/insight.dart';
import '../../domain/entities/labs/biomarker.dart';
import '../../features/correlation/engine.dart';
import '../../features/correlation/rules.dart';
import 'health_providers.dart';
import 'labs_providers.dart';
import 'settings_providers.dart';

/// Biomarkers across every uploaded report, latest value per analyte.
///
/// Merged rather than taken from the newest report alone: a recent narrow panel
/// should not erase a vitamin D from three months ago that no later report
/// re-measured.
final mergedBiomarkersProvider = Provider<List<Biomarker>>(
  (ref) => mergeBiomarkers(ref.watch(labsProvider).reports),
);

/// Every finding the engine produced, before dismissals are applied.
final allInsightsProvider = Provider<List<Insight>>((ref) {
  final context = ref.watch(engineContextProvider);
  if (context == null) return const [];

  return runEngine(
    context,
    mutedRuleIds: ref.watch(settingsProvider).mutedRuleIds,
  );
});

/// What the user actually sees — dismissals filtered out.
///
/// Dismissal is applied here rather than inside the engine so a dismissed
/// finding still counts as "produced": [dismissedInsightsProvider] can offer to
/// restore it, and the engine stays a pure function of the data.
final insightsProvider = Provider<List<Insight>>((ref) {
  final dismissed = ref.watch(settingsProvider).dismissedInsightIds;
  return ref
      .watch(allInsightsProvider)
      .where((insight) => !dismissed.contains(insight.id))
      .toList();
});

final dismissedInsightsProvider = Provider<List<Insight>>((ref) {
  final dismissed = ref.watch(settingsProvider).dismissedInsightIds;
  return ref
      .watch(allInsightsProvider)
      .where((insight) => dismissed.contains(insight.id))
      .toList();
});

/// Findings serious enough to say "take this to a clinician".
final urgentInsightCountProvider = Provider<int>(
  (ref) => ref
      .watch(insightsProvider)
      .where((i) => i.severity == InsightSeverity.urgent)
      .length,
);

/// The finding worth interrupting the user with, if any.
final headlineInsightProvider = Provider<Insight?>((ref) {
  final insights = ref.watch(insightsProvider);
  return insights.isEmpty ? null : insights.first;
});

/// Whether there is any blood work to correlate against. Drives the copy on
/// Today and Insights, which must not promise correlations it cannot make.
final hasLabDataProvider = Provider<bool>(
  (ref) => ref.watch(mergedBiomarkersProvider).isNotEmpty,
);

final hasTelemetryProvider = Provider<bool>(
  (ref) => (ref.watch(healthSeriesProvider).valueOrNull ?? const []).isNotEmpty,
);

/// One actionable suggestion, and the finding that asked for it.
typedef FeedEntry = ({Suggestion suggestion, Insight source});

/// De-duplicated suggestions across every visible finding, cheapest first.
///
/// Ordered by effort then horizon so the top of the list is the thing a user can
/// do today, not the thing that matters most in ninety days.
final suggestionFeedProvider = Provider<List<FeedEntry>>((ref) {
  final collected = collectSuggestions(ref.watch(insightsProvider));

  final feed = collected
      .map<FeedEntry>((e) => (suggestion: e.suggestion, source: e.insight))
      .toList()
    ..sort((a, b) {
      final byEffort = a.suggestion.effort.rank.compareTo(
        b.suggestion.effort.rank,
      );
      if (byEffort != 0) return byEffort;
      return a.suggestion.horizonDays.compareTo(b.suggestion.horizonDays);
    });

  return feed;
});

/// Every rule, for the toggle list in Settings.
final allRulesProvider = Provider<List<Rule>>((ref) => rules);
