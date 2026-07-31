import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/correlation/engine_context.dart';

/// App preferences. Ported from `src/store/settings.store.ts`.
///
/// Persisted, because every one of these is a decision the user made *about* the
/// analysis — a dismissed finding that reappears on relaunch, or a rule they
/// muted that comes back, reads as the app ignoring them.

/// How far back correlations look.
enum AnalysisWindow {
  thirty(30),
  sixty(60),
  ninety(90);

  const AnalysisWindow(this.days);

  final int days;

  static AnalysisWindow fromDays(int days) => AnalysisWindow.values.firstWhere(
    (w) => w.days == days,
    orElse: () => AnalysisWindow.ninety,
  );
}

class Settings {
  const Settings({
    this.sex = BiologicalSex.unspecified,
    // 90 days, matching `settings.store.ts`.
    this.analysisWindow = AnalysisWindow.ninety,
    this.mutedRuleIds = const {},
    this.dismissedInsightIds = const {},
  });

  /// Kept separate from the profile's gender because several reference intervals
  /// are sex-specific and the user may prefer not to say — in which case the
  /// wider interval is the honest default rather than a guess.
  final BiologicalSex sex;

  final AnalysisWindow analysisWindow;
  final Set<String> mutedRuleIds;
  final Set<String> dismissedInsightIds;

  Settings copyWith({
    BiologicalSex? sex,
    AnalysisWindow? analysisWindow,
    Set<String>? mutedRuleIds,
    Set<String>? dismissedInsightIds,
  }) => Settings(
    sex: sex ?? this.sex,
    analysisWindow: analysisWindow ?? this.analysisWindow,
    mutedRuleIds: mutedRuleIds ?? this.mutedRuleIds,
    dismissedInsightIds: dismissedInsightIds ?? this.dismissedInsightIds,
  );

  Map<String, dynamic> toJson() => {
    'sex': sex.wireName,
    'analysisWindowDays': analysisWindow.days,
    'mutedRuleIds': mutedRuleIds.toList(),
    'dismissedInsightIds': dismissedInsightIds.toList(),
  };

  factory Settings.fromJson(Map<String, dynamic> json) => Settings(
    sex: BiologicalSex.values.firstWhere(
      (s) => s.wireName == json['sex'],
      orElse: () => BiologicalSex.unspecified,
    ),
    analysisWindow: AnalysisWindow.fromDays(
      (json['analysisWindowDays'] as num?)?.toInt() ?? 90,
    ),
    mutedRuleIds:
        (json['mutedRuleIds'] as List?)?.whereType<String>().toSet() ??
        const {},
    dismissedInsightIds:
        (json['dismissedInsightIds'] as List?)?.whereType<String>().toSet() ??
        const {},
  );
}

class SettingsNotifier extends Notifier<Settings> {
  static const _key = 'settings.v1';

  @override
  Settings build() {
    _hydrate();
    return const Settings();
  }

  Future<void> _hydrate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return;
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        state = Settings.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (error) {
      // A corrupt preference must not make the app unlaunchable.
      debugPrint('Discarding unreadable settings: $error');
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(state.toJson()));
    } catch (error) {
      debugPrint('Could not persist settings: $error');
    }
  }

  void setSex(BiologicalSex sex) {
    state = state.copyWith(sex: sex);
    _persist();
  }

  void setAnalysisWindow(AnalysisWindow window) {
    state = state.copyWith(analysisWindow: window);
    _persist();
  }

  void toggleRule(String ruleId) {
    final next = {...state.mutedRuleIds};
    next.contains(ruleId) ? next.remove(ruleId) : next.add(ruleId);
    state = state.copyWith(mutedRuleIds: next);
    _persist();
  }

  void dismissInsight(String insightId) {
    state = state.copyWith(
      dismissedInsightIds: {...state.dismissedInsightIds, insightId},
    );
    _persist();
  }

  void clearDismissed() {
    state = state.copyWith(dismissedInsightIds: const {});
    _persist();
  }

  void reset() {
    state = const Settings();
    _persist();
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, Settings>(
  SettingsNotifier.new,
);

final biologicalSexProvider = Provider<BiologicalSex>(
  (ref) => ref.watch(settingsProvider).sex,
);

final analysisWindowProvider = Provider<AnalysisWindow>(
  (ref) => ref.watch(settingsProvider).analysisWindow,
);
