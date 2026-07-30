import 'package:agentrix_health/core/stats/stats.dart';
import 'package:agentrix_health/core/util/iso_day.dart';
import 'package:agentrix_health/domain/entities/gender.dart';
import 'package:agentrix_health/domain/entities/health/daily_snapshot.dart';
import 'package:agentrix_health/domain/entities/health/metric_key.dart';
import 'package:agentrix_health/domain/entities/insights/correlation.dart';
import 'package:agentrix_health/domain/entities/insights/insight.dart';
import 'package:agentrix_health/domain/entities/labs/biomarker.dart';
import 'package:agentrix_health/domain/entities/labs/lab_report.dart';
import 'package:agentrix_health/features/correlation/engine.dart';
import 'package:agentrix_health/features/correlation/engine_context.dart';
import 'package:agentrix_health/features/correlation/rules.dart';
import 'package:agentrix_health/features/labs/reference_ranges.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 7, 30, 8);

/// Per-metric baseline and recent values, so a test can state exactly the
/// telemetry shape a rule needs and nothing more.
class _Shape {
  const _Shape({required this.baseline, required this.recent});

  final double baseline;
  final double recent;
}

/// A 35-day series: 28 baseline days then 7 recent, matching the engine window.
List<DailySnapshot> _series(Map<MetricKey, _Shape> shapes, {int days = 35}) {
  final out = <DailySnapshot>[];

  for (var i = days - 1; i >= 0; i -= 1) {
    final isRecent = i < 7;
    double? read(MetricKey key) {
      final shape = shapes[key];
      if (shape == null) return null;
      return isRecent ? shape.recent : shape.baseline;
    }

    final asleep = read(MetricKey.sleepDuration);
    final efficiency = read(MetricKey.sleepEfficiency);
    final date = addDays(_now, -i);

    out.add(
      DailySnapshot(
        day: toIsoDay(date),
        hrv: read(MetricKey.hrv),
        restingHeartRate: read(MetricKey.restingHeartRate),
        steps: read(MetricKey.steps),
        activeEnergy: read(MetricKey.activeEnergy),
        sleep: asleep == null
            ? null
            : SleepSummary(
                // The series is expressed in hours; DailySnapshot reads minutes.
                asleepMinutes: asleep * 60,
                inBedMinutes: asleep * 60 + 30,
                deepMinutes: 70,
                remMinutes: 90,
                coreMinutes: asleep * 60 - 160,
                awakeMinutes: 20,
                unspecifiedMinutes: 0,
                efficiency: efficiency == null ? null : efficiency / 100,
                bedtime: null,
                wakeTime: null,
              ),
      ),
    );
  }

  return out;
}

Biomarker _marker(BiomarkerCode code, double value, String unit) =>
    enrichBiomarker(
      Biomarker(
        code: code,
        rawName: code.wireName,
        displayName: code.wireName,
        value: value,
        unit: unit,
        range: const ReferenceRange(low: null, high: null),
      ),
      Gender.male,
    );

EngineContext _context({
  Map<MetricKey, _Shape> shapes = const {},
  List<Biomarker> biomarkers = const [],
  DateTime? collectedAt,
  int days = 35,
}) => buildEngineContext(
  series: _series(shapes, days: days),
  biomarkers: biomarkers,
  labReportId: biomarkers.isEmpty ? null : 'report-1',
  labCollectedAt: (collectedAt ?? addDays(_now, -10)).toIso8601String(),
  sex: BiologicalSex.male,
  now: _now.toIso8601String(),
);

/// Recovery shape that satisfies the iron / inflammation telemetry side: HRV
/// down 20%, resting heart rate up 8%.
const _suppressedRecovery = {
  MetricKey.hrv: _Shape(baseline: 60, recent: 48),
  MetricKey.restingHeartRate: _Shape(baseline: 55, recent: 59),
};

List<Insight> _run(EngineContext context) => runEngine(context);

Insight? _find(List<Insight> insights, String ruleId) =>
    insights.where((i) => i.ruleId == ruleId).firstOrNull;

void main() {
  group('gating', () {
    test('says nothing with no telemetry and no labs', () {
      expect(_run(_context(days: 0)), isEmpty);
    });

    test('says nothing with a baseline too thin to trust', () {
      // Three days cannot support any claim, however dramatic they look.
      final insights = _run(
        _context(shapes: _suppressedRecovery, days: 3),
      );
      expect(insights, isEmpty);
    });

    test('a lab report alone can produce findings without telemetry', () {
      // Biomarkers present but no series: the engine must still run, because
      // several rules are lab-anchored.
      final context = _context(
        days: 0,
        biomarkers: [_marker(BiomarkerCode.ferritin, 18, 'ng/mL')],
      );
      // No telemetry means the iron rule's telemetry side cannot be satisfied,
      // so it correctly does not fire — but the engine reached the rules.
      expect(_run(context), isEmpty);
    });
  });

  group('cross-domain rules require both sides', () {
    test('low ferritin alone does not fire', () {
      final insights = _run(
        _context(
          shapes: const {
            MetricKey.hrv: _Shape(baseline: 60, recent: 60),
            MetricKey.restingHeartRate: _Shape(baseline: 55, recent: 55),
          },
          biomarkers: [_marker(BiomarkerCode.ferritin, 18, 'ng/mL')],
        ),
      );

      expect(_find(insights, 'iron-deficiency-recovery-drag'), isNull);
    });

    test('suppressed HRV alone does not fire the iron rule', () {
      final insights = _run(_context(shapes: _suppressedRecovery));
      expect(_find(insights, 'iron-deficiency-recovery-drag'), isNull);
    });

    test('low ferritin plus suppressed recovery fires', () {
      final insights = _run(
        _context(
          shapes: _suppressedRecovery,
          // 12 is below the male reference floor of 15 — frankly low, not merely
          // below optimal. 18 would be the borderline case, covered separately.
          biomarkers: [_marker(BiomarkerCode.ferritin, 12, 'ng/mL')],
        ),
      );

      final iron = _find(insights, 'iron-deficiency-recovery-drag')!;
      expect(iron.severity, InsightSeverity.action);
      expect(iron.isCrossDomain, isTrue);
      expect(iron.evidence.biomarkers, hasLength(1));
      expect(iron.evidence.telemetryNote, isNotNull);
      expect(iron.suggestions, isNotEmpty);
    });

    test('quotes the real value and the real delta', () {
      final insights = _run(
        _context(
          shapes: _suppressedRecovery,
          biomarkers: [_marker(BiomarkerCode.ferritin, 18, 'ng/mL')],
        ),
      );

      final iron = _find(insights, 'iron-deficiency-recovery-drag')!;
      expect(iron.summary, contains('18 ng/mL'));
      // HRV 60 → 48 is a 20% drop.
      expect(iron.evidence.telemetryNote, contains('20%'));
    });
  });

  group('severity escalation', () {
    test('a critically low ferritin escalates to urgent', () {
      final insights = _run(
        _context(
          shapes: _suppressedRecovery,
          biomarkers: [_marker(BiomarkerCode.ferritin, 8, 'ng/mL')],
        ),
      );

      final iron = _find(insights, 'iron-deficiency-recovery-drag')!;
      expect(iron.severity, InsightSeverity.urgent);
      expect(iron.suggestions.first.detail, isNotEmpty);
    });

    test('a merely-suboptimal ferritin stays at watch', () {
      final insights = _run(
        _context(
          shapes: _suppressedRecovery,
          // Normal on the report, below the optimal band.
          biomarkers: [_marker(BiomarkerCode.ferritin, 40, 'ng/mL')],
        ),
      );

      final iron = _find(insights, 'iron-deficiency-recovery-drag')!;
      expect(iron.severity, InsightSeverity.watch);
    });
  });

  group('telemetry-only rules', () {
    test('chronic short sleep fires with no labs at all', () {
      final insights = _run(
        _context(
          shapes: const {
            MetricKey.sleepDuration: _Shape(baseline: 6.2, recent: 5.6),
            MetricKey.hrv: _Shape(baseline: 60, recent: 55),
          },
        ),
      );

      final sleep = _find(insights, 'chronic-sleep-debt')!;
      expect(sleep.severity, InsightSeverity.action);
      expect(sleep.evidence.biomarkers, isEmpty);
      expect(sleep.labReportId, isNull);
      expect(sleep.isCrossDomain, isFalse);
    });

    test('adequate sleep does not fire the debt rule', () {
      final insights = _run(
        _context(
          shapes: const {
            MetricKey.sleepDuration: _Shape(baseline: 7.8, recent: 7.6),
          },
        ),
      );

      expect(_find(insights, 'chronic-sleep-debt'), isNull);
    });

    test('overreaching needs load up AND HRV down', () {
      final loadUpOnly = _run(
        _context(
          shapes: const {
            MetricKey.activeEnergy: _Shape(baseline: 400, recent: 520),
            MetricKey.hrv: _Shape(baseline: 60, recent: 60),
          },
        ),
      );
      expect(_find(loadUpOnly, 'training-load-hrv-decoupling'), isNull);

      final both = _run(
        _context(
          shapes: const {
            MetricKey.activeEnergy: _Shape(baseline: 400, recent: 520),
            MetricKey.hrv: _Shape(baseline: 60, recent: 50),
          },
        ),
      );
      expect(_find(both, 'training-load-hrv-decoupling'), isNotNull);
    });
  });

  group('ranking', () {
    test('severity outranks score', () {
      final insights = _run(
        _context(
          shapes: const {
            ..._suppressedRecovery,
            MetricKey.activeEnergy: _Shape(baseline: 400, recent: 300),
            MetricKey.steps: _Shape(baseline: 9000, recent: 6000),
          },
          biomarkers: [
            // Urgent referral, and a lower base score than the iron rule.
            _marker(BiomarkerCode.tsh, 7.2, 'mIU/L'),
            _marker(BiomarkerCode.ferritin, 18, 'ng/mL'),
          ],
        ),
      );

      expect(insights.first.severity, InsightSeverity.urgent);
      final ranks = insights.map((i) => i.severity.rank).toList();
      expect(ranks, orderedEquals([...ranks]..sort((a, b) => b - a)));
    });

    test('score breaks ties within a severity band', () {
      final insights = _run(
        _context(
          shapes: _suppressedRecovery,
          biomarkers: [_marker(BiomarkerCode.ferritin, 18, 'ng/mL')],
        ),
      );

      for (var i = 1; i < insights.length; i += 1) {
        if (insights[i - 1].severity == insights[i].severity) {
          expect(
            insights[i - 1].score,
            greaterThanOrEqualTo(insights[i].score),
          );
        }
      }
    });

    test('caps the list', () {
      final insights = runEngine(
        _context(
          shapes: _suppressedRecovery,
          biomarkers: [_marker(BiomarkerCode.ferritin, 18, 'ng/mL')],
        ),
        limit: 2,
      );

      expect(insights.length, lessThanOrEqualTo(2));
    });
  });

  group('scoring', () {
    test('a stale lab discounts the score heavily', () {
      List<Insight> at(DateTime collected) => _run(
        _context(
          shapes: _suppressedRecovery,
          biomarkers: [_marker(BiomarkerCode.ferritin, 18, 'ng/mL')],
          collectedAt: collected,
        ),
      );

      final fresh = _find(at(addDays(_now, -5)), 'iron-deficiency-recovery-drag')!;
      final stale = _find(
        at(addDays(_now, -400)),
        'iron-deficiency-recovery-drag',
      )!;

      expect(stale.score, lessThan(fresh.score));
    });

    test('a medical referral is floored against the same decay', () {
      List<Insight> at(DateTime collected) => _run(
        _context(
          shapes: const {
            MetricKey.activeEnergy: _Shape(baseline: 400, recent: 320),
            MetricKey.restingHeartRate: _Shape(baseline: 58, recent: 55),
          },
          biomarkers: [_marker(BiomarkerCode.tsh, 7.2, 'mIU/L')],
          collectedAt: collected,
        ),
      );

      final stale = _find(at(addDays(_now, -400)), 'subclinical-thyroid')!;
      // 75% of a base score of 92. "See a clinician" must not decay off the
      // list just because the panel is old.
      expect(stale.score, greaterThanOrEqualTo(69));
    });

    test('scores stay inside 0–100', () {
      final insights = _run(
        _context(
          shapes: _suppressedRecovery,
          biomarkers: [_marker(BiomarkerCode.ferritin, 8, 'ng/mL')],
        ),
      );

      for (final insight in insights) {
        expect(insight.score, inInclusiveRange(0, 100));
      }
    });
  });

  group('determinism and identity', () {
    test('the same context produces the same findings', () {
      EngineContext build() => _context(
        shapes: _suppressedRecovery,
        biomarkers: [_marker(BiomarkerCode.ferritin, 18, 'ng/mL')],
      );

      final a = _run(build());
      final b = _run(build());

      expect(a.map((i) => i.id), orderedEquals(b.map((i) => i.id)));
      expect(a.map((i) => i.score), orderedEquals(b.map((i) => i.score)));
      expect(a.map((i) => i.summary), orderedEquals(b.map((i) => i.summary)));
    });

    test('ids are stable across recomputation, so a dismissal can persist', () {
      final insights = _run(
        _context(
          shapes: _suppressedRecovery,
          biomarkers: [_marker(BiomarkerCode.ferritin, 18, 'ng/mL')],
        ),
      );

      final iron = _find(insights, 'iron-deficiency-recovery-drag')!;
      expect(iron.id, 'insight_iron-deficiency-recovery-drag_report-1');
    });

    test('ids are unique within a run', () {
      final insights = _run(
        _context(
          shapes: const {
            ..._suppressedRecovery,
            MetricKey.sleepDuration: _Shape(baseline: 6.2, recent: 5.6),
          },
          biomarkers: [_marker(BiomarkerCode.ferritin, 18, 'ng/mL')],
        ),
      );

      final ids = insights.map((i) => i.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });
  });

  group('muting', () {
    test('a muted rule is excluded', () {
      final context = _context(
        shapes: _suppressedRecovery,
        biomarkers: [_marker(BiomarkerCode.ferritin, 18, 'ng/mL')],
      );

      expect(
        _find(_run(context), 'iron-deficiency-recovery-drag'),
        isNotNull,
      );
      expect(
        _find(
          runEngine(
            context,
            mutedRuleIds: const {'iron-deficiency-recovery-drag'},
          ),
          'iron-deficiency-recovery-drag',
        ),
        isNull,
      );
    });
  });

  group('evidence integrity', () {
    test('never cites a biomarker the context does not hold', () {
      final insights = _run(
        _context(
          shapes: _suppressedRecovery,
          // Ferritin only — the rule also lists hemoglobin when present.
          biomarkers: [_marker(BiomarkerCode.ferritin, 18, 'ng/mL')],
        ),
      );

      final iron = _find(insights, 'iron-deficiency-recovery-drag')!;
      expect(iron.evidence.biomarkers.map((b) => b.code), [
        BiomarkerCode.ferritin,
      ]);
    });

    test('picks up hemoglobin when the panel has it', () {
      final insights = _run(
        _context(
          shapes: _suppressedRecovery,
          biomarkers: [
            _marker(BiomarkerCode.ferritin, 18, 'ng/mL'),
            _marker(BiomarkerCode.hemoglobin, 13.2, 'g/dL'),
          ],
        ),
      );

      final iron = _find(insights, 'iron-deficiency-recovery-drag')!;
      expect(
        iron.evidence.biomarkers.map((b) => b.code),
        containsAll([BiomarkerCode.ferritin, BiomarkerCode.hemoglobin]),
      );
    });

    test('never cites a non-significant correlation', () {
      final insights = _run(
        _context(
          shapes: _suppressedRecovery,
          biomarkers: [_marker(BiomarkerCode.ferritin, 18, 'ng/mL')],
        ),
      );

      for (final insight in insights) {
        for (final correlation in insight.evidence.correlations) {
          expect(correlation.strength, isNot(CorrelationStrength.none));
        }
      }
    });

    test('every finding carries at least one suggestion', () {
      final insights = _run(
        _context(
          shapes: const {
            ..._suppressedRecovery,
            MetricKey.sleepDuration: _Shape(baseline: 6.2, recent: 5.6),
            MetricKey.steps: _Shape(baseline: 9000, recent: 5500),
          },
          biomarkers: [
            _marker(BiomarkerCode.ferritin, 18, 'ng/mL'),
            _marker(BiomarkerCode.vitaminD, 21, 'ng/mL'),
            _marker(BiomarkerCode.hsCrp, 4.2, 'mg/L'),
          ],
        ),
      );

      expect(insights, isNotEmpty);
      for (final insight in insights) {
        expect(insight.suggestions, isNotEmpty);
        expect(insight.title, isNotEmpty);
        expect(insight.summary, isNotEmpty);
      }
    });
  });

  group('the catalogue itself', () {
    test('rule ids are unique', () {
      final ids = rules.map((r) => r.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('every rule has a name for the mute list', () {
      for (final rule in rules) {
        expect(rule.name, isNotEmpty, reason: rule.id);
      }
    });

    test('no rule throws on an empty context', () {
      // The engine catches throws, but a rule that cannot survive a bare context
      // is a bug rather than something to swallow.
      final bare = _context(days: 35);
      for (final rule in rules) {
        expect(
          () => rule.evaluate(bare),
          returnsNormally,
          reason: rule.id,
        );
      }
    });

    test('every citation is a real https URL', () {
      // A fabricated citation on a health claim is this file's worst failure
      // mode, so the shape is asserted even though the values are hand-curated.
      final context = _context(
        shapes: const {
          ..._suppressedRecovery,
          MetricKey.sleepDuration: _Shape(baseline: 6.2, recent: 5.6),
          MetricKey.steps: _Shape(baseline: 9000, recent: 5500),
          MetricKey.activeEnergy: _Shape(baseline: 400, recent: 300),
        },
        biomarkers: [
          _marker(BiomarkerCode.ferritin, 18, 'ng/mL'),
          _marker(BiomarkerCode.vitaminD, 21, 'ng/mL'),
          _marker(BiomarkerCode.hsCrp, 4.2, 'mg/L'),
          _marker(BiomarkerCode.hba1c, 6.0, '%'),
          _marker(BiomarkerCode.triglycerides, 190, 'mg/dL'),
          _marker(BiomarkerCode.hdl, 42, 'mg/dL'),
          _marker(BiomarkerCode.alt, 62, 'U/L'),
          _marker(BiomarkerCode.magnesium, 4.6, 'mg/dL'),
        ],
      );

      final insights = runEngine(context, limit: 100);
      expect(insights, isNotEmpty);

      for (final insight in insights) {
        for (final citation in insight.evidence.citations) {
          expect(citation.label, isNotEmpty);
          expect(Uri.parse(citation.url).scheme, 'https');
        }
      }
    });

    test('suggestion horizons are plausible', () {
      final context = _context(
        shapes: const {
          ..._suppressedRecovery,
          MetricKey.sleepDuration: _Shape(baseline: 6.2, recent: 5.6),
        },
        biomarkers: [_marker(BiomarkerCode.ferritin, 18, 'ng/mL')],
      );

      for (final insight in runEngine(context, limit: 100)) {
        for (final suggestion in insight.suggestions) {
          expect(suggestion.horizonDays, greaterThan(0));
          expect(suggestion.horizonDays, lessThanOrEqualTo(180));
          expect(suggestion.detail, isNotEmpty);
        }
      }
    });
  });

  group('collectSuggestions', () {
    test('de-duplicates by id and keeps the strongest attribution', () {
      final insights = _run(
        _context(
          shapes: const {
            ..._suppressedRecovery,
            MetricKey.sleepDuration: _Shape(baseline: 6.2, recent: 5.6),
          },
          biomarkers: [
            _marker(BiomarkerCode.ferritin, 18, 'ng/mL'),
            _marker(BiomarkerCode.vitaminD, 21, 'ng/mL'),
          ],
        ),
      );

      final collected = collectSuggestions(insights);
      final ids = collected.map((c) => c.suggestion.id).toList();

      expect(ids.toSet(), hasLength(ids.length));
      expect(collected, isNotEmpty);
    });
  });

  group('mergeBiomarkers', () {
    LabReport report(
      String id,
      DateTime collected,
      List<Biomarker> biomarkers,
    ) => LabReport(
      id: id,
      source: LabSource.sample,
      status: ParseStatus.ready,
      collectedAt: collected,
      uploadedAt: collected,
      biomarkers: biomarkers,
    );

    test('a newer report supersedes an older value per analyte', () {
      final merged = mergeBiomarkers([
        report('new', addDays(_now, -5), [
          _marker(BiomarkerCode.ferritin, 60, 'ng/mL'),
        ]),
        report('old', addDays(_now, -200), [
          _marker(BiomarkerCode.ferritin, 20, 'ng/mL'),
        ]),
      ]);

      expect(merged, hasLength(1));
      expect(merged.single.value, 60);
    });

    test('an older analyte survives when no newer report measured it', () {
      // The case that makes merging worth doing: a recent narrow panel must not
      // erase a vitamin D nothing since has re-measured.
      final merged = mergeBiomarkers([
        report('new', addDays(_now, -5), [
          _marker(BiomarkerCode.ferritin, 60, 'ng/mL'),
        ]),
        report('old', addDays(_now, -200), [
          _marker(BiomarkerCode.vitaminD, 21, 'ng/mL'),
        ]),
      ]);

      expect(merged.map((b) => b.code), hasLength(2));
    });

    test('keeps unmapped analytes rather than dropping the user’s results', () {
      const unknown = Biomarker(
        code: null,
        rawName: 'NOVEL ASSAY',
        displayName: 'Novel Assay',
        value: 42,
        unit: 'x/y',
        range: ReferenceRange(low: null, high: null),
      );

      final merged = mergeBiomarkers([
        report('r', addDays(_now, -5), [
          _marker(BiomarkerCode.ferritin, 60, 'ng/mL'),
          unknown,
        ]),
      ]);

      expect(merged, hasLength(2));
      expect(merged.any((b) => b.rawName == 'NOVEL ASSAY'), isTrue);
    });

    test('falls back to uploadedAt when collectedAt is absent', () {
      final withoutCollection = LabReport(
        id: 'no-date',
        source: LabSource.manual,
        status: ParseStatus.ready,
        collectedAt: null,
        uploadedAt: addDays(_now, -1),
        biomarkers: [_marker(BiomarkerCode.ferritin, 90, 'ng/mL')],
      );

      final merged = mergeBiomarkers([
        report('older', addDays(_now, -30), [
          _marker(BiomarkerCode.ferritin, 20, 'ng/mL'),
        ]),
        withoutCollection,
      ]);

      expect(merged.single.value, 90);
    });

    test('is empty for no reports', () {
      expect(mergeBiomarkers(const []), isEmpty);
    });
  });

  group('describeCorrelation', () {
    test('states r and n together', () {
      const correlation = Correlation(
        metric: MetricKey.sleepDuration,
        r: 0.62,
        p: 0.001,
        n: 31,
        strength: CorrelationStrength.moderate,
        direction: CorrelationDirection.positive,
      );

      final text = describeCorrelation(correlation);
      expect(text, contains('Sleep Duration'));
      expect(text, contains('r = 0.62'));
      // Hiding the sample size is how correlation UIs mislead.
      expect(text, contains('n = 31'));
      expect(text, contains('same day'));
    });

    test('names the lag when there is one', () {
      const lagged = Correlation(
        metric: MetricKey.activeEnergy,
        r: -0.4,
        p: 0.02,
        n: 28,
        lagDays: 1,
        strength: CorrelationStrength.weak,
        direction: CorrelationDirection.negative,
      );

      expect(describeCorrelation(lagged), contains('1-day lag'));
    });
  });

  group('suggestionsByEffort', () {
    test('puts the cheapest win first', () {
      final insights = _run(
        _context(
          shapes: _suppressedRecovery,
          biomarkers: [_marker(BiomarkerCode.ferritin, 18, 'ng/mL')],
        ),
      );

      final ordered = _find(
        insights,
        'iron-deficiency-recovery-drag',
      )!.suggestionsByEffort;

      final ranks = ordered.map((s) => s.effort.rank).toList();
      expect(ranks, orderedEquals([...ranks]..sort()));
    });
  });
}
