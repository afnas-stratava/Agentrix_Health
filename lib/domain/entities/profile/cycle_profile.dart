import '../../../core/util/iso_day.dart';

/// Ported from the `CycleProfileSchema` half of `src/schemas/profile.ts`.
///
/// Named `CycleProfile` to sit alongside — not replace — the existing
/// `lib/domain/entities/cycle_day.dart` and `cycle_phase.dart` entities that
/// already shipped in this Flutter app.
class CycleProfile {
  const CycleProfile({
    this.tracks = false,
    this.periodStarts = const [],
    this.averageCycleDays = 28,
    this.averagePeriodDays = 5,
    this.hormonalContraception = false,
  });

  /// Off by default; nothing about cycles renders until this is switched on.
  final bool tracks;

  /// First days of logged periods, oldest first. Kept as a list rather than a
  /// single date so cycle length can be *measured* from the user's own history
  /// instead of taken from the textbook 28 days — which very few people have.
  ///
  /// Logged in-app: HealthKit's menstrual-flow category was not reachable from
  /// the React Native build, so this was never sourced from the platform.
  final List<IsoDay> periodStarts;

  /// Fallback used until two periods have been logged.
  final int averageCycleDays;

  final int averagePeriodDays;

  /// Set when a coil, implant or continuous pill makes phase maths meaningless.
  final bool hormonalContraception;

  CycleProfile copyWith({
    bool? tracks,
    List<IsoDay>? periodStarts,
    int? averageCycleDays,
    int? averagePeriodDays,
    bool? hormonalContraception,
  }) => CycleProfile(
    tracks: tracks ?? this.tracks,
    periodStarts: periodStarts ?? this.periodStarts,
    averageCycleDays: averageCycleDays ?? this.averageCycleDays,
    averagePeriodDays: averagePeriodDays ?? this.averagePeriodDays,
    hormonalContraception: hormonalContraception ?? this.hormonalContraception,
  );

  factory CycleProfile.fromJson(Map<String, dynamic> json) => CycleProfile(
    tracks: json['tracks'] as bool? ?? false,
    periodStarts:
        (json['periodStarts'] as List<dynamic>?)?.cast<String>().toList() ??
        const [],
    averageCycleDays: (json['averageCycleDays'] as num?)?.toInt() ?? 28,
    averagePeriodDays: (json['averagePeriodDays'] as num?)?.toInt() ?? 5,
    hormonalContraception: json['hormonalContraception'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'tracks': tracks,
    'periodStarts': periodStarts,
    'averageCycleDays': averageCycleDays,
    'averagePeriodDays': averagePeriodDays,
    'hormonalContraception': hormonalContraception,
  };
}
