import 'package:flutter_test/flutter_test.dart';

import 'package:agentrix_health/data/labs/gemini_lab_parser.dart';
import 'package:agentrix_health/domain/entities/gender.dart';
import 'package:agentrix_health/domain/entities/labs/biomarker.dart';
import 'package:agentrix_health/domain/entities/labs/lab_report.dart';

/// Covers the mapping from Gemini's reply onto the app's types. The network
/// call is not exercised — what matters here is that a real document's
/// quirks (one-sided ranges, analytes the app has never heard of, missing
/// metadata) survive the boundary without being silently reshaped.
void main() {
  const upload = LabUpload(
    path: '/tmp/report.pdf',
    name: 'report.pdf',
    source: LabSource.email,
    sizeBytes: 1024,
  );

  Map<String, dynamic> row({
    String? code = 'ferritin',
    String rawName = 'FERRITIN, SERUM',
    double value = 21,
    String unit = 'ng/mL',
    num? low = 15,
    num? high = 300,
  }) => {
    'code': code,
    'rawName': rawName,
    'displayName': 'Ferritin',
    'category': 'iron',
    'value': value,
    'unit': unit,
    'rangeLow': low,
    'rangeHigh': high,
    'sourcePage': 1,
    'confidence': 0.9,
  };

  test('maps a known analyte and lets enrichBiomarker do the flagging', () {
    final report = GeminiLabParser.reportFromJson({
      'labName': 'Quest Diagnostics',
      'panelName': 'CMP',
      'collectedAt': '2026-07-01T08:15:00Z',
      'biomarkers': [row()],
    }, upload, Gender.male);

    expect(report.biomarkers, hasLength(1));
    final marker = report.biomarkers.single;
    expect(marker.code, BiomarkerCode.ferritin);
    expect(marker.value, 21);
    expect(marker.unit, 'ng/mL');
    expect(report.labName, 'Quest Diagnostics');
    expect(report.collectedAt, isNotNull);
    expect(report.source, LabSource.email);
    expect(report.fileName, 'report.pdf');
    // Classification is delegated, so it must not still be unknown.
    expect(marker.flag, isNot(BiomarkerFlag.unknown));
  });

  test('keeps an unrecognised analyte rather than dropping the row', () {
    final report = GeminiLabParser.reportFromJson({
      'biomarkers': [
        row(code: null, rawName: 'LIPOPROTEIN(A)', value: 42, unit: 'nmol/L'),
      ],
    }, upload, Gender.female);

    expect(report.biomarkers, hasLength(1));
    expect(report.biomarkers.single.code, isNull);
    expect(report.biomarkers.single.rawName, 'LIPOPROTEIN(A)');
  });

  test('carries one-sided reference ranges through as nulls', () {
    final report = GeminiLabParser.reportFromJson({
      'biomarkers': [
        row(code: 'alt', rawName: 'SGPT / ALT', value: 29, unit: 'U/L', low: null, high: 40),
      ],
    }, upload, Gender.male);

    final range = report.biomarkers.single.range;
    expect(range.high, 40);
    // A missing lower bound must stay missing — inventing 0 would make an
    // out-of-range low value read as normal.
    expect(range.low, isNull);
  });

  test('skips rows with no numeric value instead of coercing them', () {
    final report = GeminiLabParser.reportFromJson({
      'biomarkers': [
        row(),
        {'rawName': 'COMMENTS', 'displayName': 'Comments', 'unit': ''},
      ],
    }, upload, Gender.male);

    expect(report.biomarkers, hasLength(1));
  });

  test('throws when the document yielded nothing, so the caller can fall back', () {
    expect(
      () => GeminiLabParser.reportFromJson(
        {'biomarkers': <dynamic>[]},
        upload,
        Gender.male,
      ),
      throwsStateError,
    );
  });

  test('attaches the automated-extraction disclosure', () {
    final report = GeminiLabParser.reportFromJson({
      'biomarkers': [row()],
    }, upload, Gender.male);

    expect(report.warnings, contains(geminiParseDisclosure));
  });

  test('adds the extra caution for photographed reports', () {
    const photo = LabUpload(
      path: '/tmp/report.jpg',
      name: 'report.jpg',
      source: LabSource.image,
    );
    final report = GeminiLabParser.reportFromJson({
      'biomarkers': [row()],
    }, photo, Gender.male);

    expect(report.warnings.length, 2);
  });
}
