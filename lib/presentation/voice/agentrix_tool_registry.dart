import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/health/metric_key.dart';
import '../navigation/app_navigator.dart';
import '../providers/health_providers.dart';
import '../providers/main_tab_provider.dart';

/// One whitelisted action Hume's EVI can invoke over a voice call. Takes the
/// tool's parameters (already JSON-decoded — see `HumeToolCall` in
/// `voice_message.dart`) and returns the UTF-8 string Hume speaks back as the
/// result. Throws to signal failure; the dispatcher in `voice_providers.dart`
/// turns that into a `tool_error`, never a crash.
typedef AgentrixTool =
    Future<String> Function(Ref ref, Map<String, dynamic> parameters);

/// Every action Hume is allowed to trigger, by exact name — this **is** the
/// whitelist. Nothing outside this map runs, no matter what name a
/// `tool_call` message carries; there is deliberately no generic
/// "run this"/"execute this code" escape hatch.
///
/// Phase 1: navigation only, and only these 3 (see the integration plan for
/// what's next — health data, food logging, workouts). Each of those Type 2
/// tools will call `agentrix_backend` from inside its closure; the shape
/// here already supports that, nothing about the registry itself changes.
abstract final class AgentrixToolRegistry {
  static final Map<String, AgentrixTool> _tools = {
    'open_dashboard': (ref, _) async {
      if (!AppNavigator.goToTab(ref, MainTab.today)) {
        throw StateError('Navigation not ready');
      }
      return 'Opened the dashboard.';
    },
    'open_food_diary': (ref, _) async {
      if (!AppNavigator.goToTab(ref, MainTab.food)) {
        throw StateError('Navigation not ready');
      }
      return 'Opened the food diary.';
    },
    'open_sleep': (ref, _) async {
      if (!AppNavigator.openMetric(MetricKey.sleepDuration)) {
        throw StateError('Navigation not ready');
      }
      return 'Opened your sleep data.';
    },
    'open_insights': (ref, _) async {
      if (!AppNavigator.goToTab(ref, MainTab.insights)) {
        throw StateError('Navigation not ready');
      }
      return 'Opened insights.';
    },
    'open_labs': (ref, _) async {
      if (!AppNavigator.goToTab(ref, MainTab.labs)) {
        throw StateError('Navigation not ready');
      }
      return 'Opened your labs.';
    },
    'open_settings': (ref, _) async {
      if (!AppNavigator.goToTab(ref, MainTab.settings)) {
        throw StateError('Navigation not ready');
      }
      return 'Opened settings.';
    },

    // Type 2 tools: answer from data already computed on-device, the same
    // `MetricStats` the Home screen's chips read — no backend round trip
    // needed for something the app already has in memory.
    'get_daily_steps': (ref, _) async {
      final steps = ref.read(metricStatsProvider)?[MetricKey.steps]?.latest;
      if (steps == null) {
        return "I don't have today's step count yet — health data may "
            "still be syncing.";
      }
      return "You've taken ${steps.round()} steps today.";
    },
    'get_heart_rate_variability': (ref, _) async {
      final hrv = ref.read(metricStatsProvider)?[MetricKey.hrv]?.latest;
      if (hrv == null) {
        return "I don't have your HRV yet — it may still be syncing, or "
            "your baseline may still be building.";
      }
      return "Your heart rate variability is ${hrv.round()} milliseconds.";
    },
    'get_resting_heart_rate': (ref, _) async {
      final rhr = ref
          .read(metricStatsProvider)?[MetricKey.restingHeartRate]
          ?.latest;
      if (rhr == null) {
        return "I don't have your resting heart rate yet — it may still be "
            "syncing.";
      }
      return "Your resting heart rate is ${rhr.round()} beats per minute.";
    },
    'get_sleep': (ref, _) async {
      final hours = ref
          .read(metricStatsProvider)?[MetricKey.sleepDuration]
          ?.latest;
      if (hours == null) {
        return "I don't have last night's sleep yet — it may still be "
            "syncing.";
      }
      return "You slept ${hours.toStringAsFixed(1)} hours last night.";
    },
    'get_active_energy': (ref, _) async {
      final kcal = ref.read(metricStatsProvider)?[MetricKey.activeEnergy]?.latest;
      if (kcal == null) {
        return "I don't have today's active energy yet — it may still be "
            "syncing.";
      }
      return "You've burned ${kcal.round()} active calories today.";
    },
  };

  static bool isKnown(String name) => _tools.containsKey(name);

  /// Callers must check [isKnown] first — this throwing [ArgumentError] for
  /// a name outside the whitelist means a caller skipped that check, which
  /// is a bug in this file, not a Hume response to shape.
  static Future<String> execute(
    Ref ref,
    String name,
    Map<String, dynamic> parameters,
  ) {
    final tool = _tools[name];
    if (tool == null) {
      throw ArgumentError.value(name, 'name', 'Not a whitelisted tool');
    }
    return tool(ref, parameters);
  }
}
