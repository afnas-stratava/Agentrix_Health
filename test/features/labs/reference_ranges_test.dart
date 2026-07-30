import 'package:agentrix_health/domain/entities/gender.dart';
import 'package:agentrix_health/domain/entities/labs/biomarker.dart';
import 'package:agentrix_health/features/labs/lab_parser.dart';
import 'package:agentrix_health/domain/entities/labs/lab_report.dart';
import 'package:agentrix_health/features/labs/reference_ranges.dart';
import 'package:flutter_test/flutter_test.dart';

Biomarker _marker(
  BiomarkerCode code,
  double value,
  String unit, {
  double? low,
  double? high,
}) => Biomarker(
  code: code,
  rawName: code.wireName,
  displayName: code.wireName,
  value: value,
  unit: unit,
  range: ReferenceRange(low: low, high: high),
);

void main() {
  group('classifyValue', () {
    const range = ReferenceRange(
      low: 15,
      high: 300,
      optimalLow: 50,
      optimalHigh: 150,
    );

    test('separates the lab range from the optimal band', () {
      // The case the whole product rests on: normal on the report, below
      // optimal in reality.
      expect(classifyValue(22, range), BiomarkerFlag.borderlineLow);
      expect(classifyValue(22, range).isOutOfRange, isFalse);
      expect(classifyValue(22, range).needsAttention, isTrue);
    });

    test('inside the optimal band reads as optimal', () {
      expect(classifyValue(90, range), BiomarkerFlag.optimal);
      expect(classifyValue(90, range).needsAttention, isFalse);
    });

    test('above optimal but inside range', () {
      expect(classifyValue(220, range), BiomarkerFlag.borderlineHigh);
    });

    test('outside the lab range', () {
      expect(classifyValue(12, range), BiomarkerFlag.low);
      expect(classifyValue(350, range), BiomarkerFlag.high);
      expect(classifyValue(12, range).isOutOfRange, isTrue);
    });

    test('escalates to critical past 1.5x the bound', () {
      expect(classifyValue(9, range), BiomarkerFlag.criticalLow);
      expect(classifyValue(500, range), BiomarkerFlag.criticalHigh);
    });

    test('falls back to normal when no optimal band is defined', () {
      const plain = ReferenceRange(low: 10, high: 20);
      expect(classifyValue(15, plain), BiomarkerFlag.normal);
      expect(classifyValue(15, plain).needsAttention, isFalse);
    });
  });

  group('resolveRange', () {
    test('applies sex-specific intervals where they matter', () {
      final male = resolveRange(BiomarkerCode.hdl, Gender.male);
      final female = resolveRange(BiomarkerCode.hdl, Gender.female);

      expect(female.low, greaterThan(male.low!));
      expect(female.optimalLow, greaterThan(male.optimalLow!));
    });

    test('shares the interval when there is no sex difference', () {
      final male = resolveRange(BiomarkerCode.hba1c, Gender.male);
      final female = resolveRange(BiomarkerCode.hba1c, Gender.female);

      expect(female.high, male.high);
      expect(female.optimalHigh, male.optimalHigh);
    });

    test('a female testosterone range is not the male one', () {
      // Getting this wrong would flag every female result as critically low.
      final female = resolveRange(BiomarkerCode.testosterone, Gender.female);
      expect(female.high, lessThan(100));
    });
  });

  group('toCanonicalUnit', () {
    test('converts mmol/L glucose to mg/dL', () {
      final result = toCanonicalUnit(
        BiomarkerCode.fastingGlucose,
        5.4,
        'mmol/L',
      )!;
      expect(result.value, closeTo(97.3, 0.5));
      expect(result.unit, 'mg/dL');
    });

    test('passes through the canonical unit unchanged', () {
      final result = toCanonicalUnit(
        BiomarkerCode.fastingGlucose,
        96,
        'mg/dL',
      )!;
      expect(result.value, 96);
    });

    test('is case-insensitive', () {
      expect(
        toCanonicalUnit(BiomarkerCode.ferritin, 40, 'UG/L')?.value,
        40,
      );
    });

    test('returns null for an unrecognised unit rather than assuming', () {
      // Silently assuming would turn a 5.4 mmol/L glucose into hypoglycaemia.
      expect(
        toCanonicalUnit(BiomarkerCode.fastingGlucose, 5.4, 'furlongs'),
        isNull,
      );
    });

    test('converts nmol/L vitamin D to ng/mL', () {
      final result = toCanonicalUnit(
        BiomarkerCode.vitaminD,
        75,
        'nmol/L',
      )!;
      expect(result.value, closeTo(30, 0.5));
    });
  });

  group('enrichBiomarker', () {
    test('flags a normal-but-suboptimal ferritin', () {
      final enriched = enrichBiomarker(
        _marker(BiomarkerCode.ferritin, 22, 'ng/mL', low: 15, high: 300),
        Gender.male,
      );

      expect(enriched.flag, BiomarkerFlag.borderlineLow);
      expect(enriched.range.optimalLow, 50);
    });

    test('converts units before classifying', () {
      final enriched = enrichBiomarker(
        _marker(BiomarkerCode.fastingGlucose, 5.4, 'mmol/L'),
        Gender.male,
      );

      expect(enriched.unit, 'mg/dL');
      expect(enriched.value, closeTo(97.3, 0.5));
      expect(enriched.flag, BiomarkerFlag.borderlineHigh);
    });

    test('prefers the lab’s own interval but keeps our optimal band', () {
      final enriched = enrichBiomarker(
        // A deliberately unusual lab interval.
        _marker(BiomarkerCode.ferritin, 22, 'ng/mL', low: 20, high: 250),
        Gender.male,
      );

      expect(enriched.range.low, 20);
      expect(enriched.range.high, 250);
      expect(enriched.range.optimalLow, 50);
      expect(enriched.range.source, ReferenceSource.lab);
    });

    test('provenance survives re-enrichment', () {
      // This runs on every render; a source that drifts from `app` to `lab`
      // on the second pass would relabel our own interval as the lab's.
      final once = enrichBiomarker(
        _marker(BiomarkerCode.ferritin, 22, 'ng/mL'),
        Gender.male,
      );
      final twice = enrichBiomarker(once, Gender.male);

      expect(once.range.source, ReferenceSource.app);
      expect(twice.range.source, ReferenceSource.app);
    });

    test('downgrades confidence on an unconvertible unit', () {
      final enriched = enrichBiomarker(
        _marker(
          BiomarkerCode.ferritin,
          22,
          'unknown-unit',
          low: 15,
          high: 300,
        ),
        Gender.male,
      );

      expect(enriched.confidence, lessThanOrEqualTo(0.6));
      // The lab's own interval is still usable.
      expect(enriched.flag, BiomarkerFlag.normal);
    });

    test('an unmapped analyte is kept but not flagged', () {
      const unknown = Biomarker(
        code: null,
        rawName: 'SOME NOVEL ASSAY',
        displayName: 'Some Novel Assay',
        value: 42,
        unit: 'x/y',
        range: ReferenceRange(low: null, high: null),
      );

      final enriched = enrichBiomarker(unknown, Gender.male);
      expect(enriched.flag, BiomarkerFlag.unknown);
      expect(enriched.rawName, 'SOME NOVEL ASSAY');
    });
  });

  group('the reference table itself', () {
    test('every optimal band sits inside its lab range', () {
      for (final entry in referenceTable.entries) {
        final d = entry.value;
        if (d.optimalLow != null && d.low != null) {
          expect(
            d.optimalLow,
            greaterThanOrEqualTo(d.low!),
            reason: '${entry.key.wireName} optimalLow below its range',
          );
        }
        if (d.optimalHigh != null && d.high != null) {
          expect(
            d.optimalHigh,
            lessThanOrEqualTo(d.high!),
            reason: '${entry.key.wireName} optimalHigh above its range',
          );
        }
      }
    });

    test('every band is ordered low then high', () {
      for (final entry in referenceTable.entries) {
        final d = entry.value;
        if (d.low != null && d.high != null) {
          expect(d.low, lessThan(d.high!), reason: entry.key.wireName);
        }
        if (d.optimalLow != null && d.optimalHigh != null) {
          expect(
            d.optimalLow,
            lessThanOrEqualTo(d.optimalHigh!),
            reason: entry.key.wireName,
          );
        }
      }
    });

    test('every biomarker code has a reference definition', () {
      for (final code in BiomarkerCode.values) {
        expect(
          referenceTable[code],
          isNotNull,
          reason: '${code.wireName} has no reference definition',
        );
      }
    });
  });

  group('LocalLabParser', () {
    test('produces a flagged, ready report', () async {
      final report = await const LocalLabParser(
        latency: Duration.zero,
      ).parse(
        const LabUpload(
          path: '',
          name: 'panel.pdf',
          source: LabSource.pdf,
          sizeBytes: 120000,
        ),
        gender: Gender.male,
      );

      expect(report.status, ParseStatus.ready);
      expect(report.biomarkers, isNotEmpty);
      expect(report.flagged, isNotEmpty);
      expect(report.fileName, 'panel.pdf');
    });

    test('always carries the no-OCR disclosure', () async {
      final report = await const LocalLabParser(
        latency: Duration.zero,
      ).parse(
        const LabUpload(path: '', name: 'x', source: LabSource.sample),
        gender: Gender.male,
      );

      expect(report.warnings, contains(localParseDisclosure));
    });

    test('adds an extra caution for photographed reports', () async {
      final report = await const LocalLabParser(
        latency: Duration.zero,
      ).parse(
        const LabUpload(path: '', name: 'x', source: LabSource.image),
        gender: Gender.male,
      );

      expect(report.warnings.length, greaterThan(1));
    });

    test('the fixture panel lights up iron, inflammation and vitamin D',
        () async {
      final report = await const LocalLabParser(
        latency: Duration.zero,
      ).parse(
        const LabUpload(path: '', name: 'x', source: LabSource.sample),
        gender: Gender.male,
      );

      final flaggedCodes = report.flagged.map((b) => b.code).toSet();
      expect(flaggedCodes, contains(BiomarkerCode.ferritin));
      expect(flaggedCodes, contains(BiomarkerCode.hsCrp));
      expect(flaggedCodes, contains(BiomarkerCode.vitaminD));
    });

    test('flagged is ordered worst-first', () async {
      final report = await const LocalLabParser(
        latency: Duration.zero,
      ).parse(
        const LabUpload(path: '', name: 'x', source: LabSource.sample),
        gender: Gender.male,
      );

      final severities = report.flagged.map((b) => b.flag.severity).toList();
      expect(
        severities,
        orderedEquals([...severities]..sort((a, b) => b - a)),
      );
    });
  });

  group('LabUpload', () {
    test('rejects an oversized report before any work starts', () {
      const upload = LabUpload(
        path: '',
        name: 'huge.pdf',
        source: LabSource.pdf,
        sizeBytes: 30 * 1024 * 1024,
      );
      expect(upload.rejectionReason, isNotNull);
    });

    test('accepts a normal report', () {
      const upload = LabUpload(
        path: '',
        name: 'ok.pdf',
        source: LabSource.pdf,
        sizeBytes: 400000,
      );
      expect(upload.rejectionReason, isNull);
    });
  });
}
