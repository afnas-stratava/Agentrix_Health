import '../../core/util/iso_day.dart';
import '../../domain/entities/gender.dart';
import '../../domain/entities/labs/biomarker.dart';
import '../../domain/entities/labs/lab_report.dart';
import 'reference_ranges.dart';

/// Turns an uploaded document into a flagged [LabReport].
/// Ported from `src/features/labs/parser.ts` + `parser.mock.ts`.
///
/// ───────────────────────────────────────────────────────────────────────────
/// THE LOCAL PARSER DOES NOT READ THE DOCUMENT. There is no OCR model on the
/// device and no parsing backend configured in this build.
///
/// What it does is return a fixed, clinically coherent panel so that every
/// stage *after* extraction — unit conversion, sex-specific reference
/// resolution, optimal-band flagging, the brief's food focus, the dish ranker's
/// focus tags — runs on real data and can be demonstrated and tested end to
/// end. The file the user picked is recorded on the report (name and size) so
/// the provenance is honest, and [LabReport.warnings] carries the disclosure
/// that the UI renders verbatim.
///
/// To make this real, implement [LabParser] against an OCR endpoint and return
/// the same [LabReport] shape. Nothing downstream changes: flagging already
/// happens here rather than at the boundary, precisely so both paths share it.
/// ───────────────────────────────────────────────────────────────────────────
abstract class LabParser {
  Future<LabReport> parse(LabUpload upload, {required Gender gender});
}

/// One row of the fixture panel.
class _Seed {
  const _Seed(
    this.code,
    this.rawName,
    this.displayName,
    this.category,
    this.value,
    this.unit,
    this.low,
    this.high,
    this.page,
  );

  final BiomarkerCode code;
  final String rawName;
  final String displayName;
  final BiomarkerCategory category;
  final double value;
  final String unit;
  final double? low;
  final double? high;
  final int page;
}

/// Mildly depleted iron stores, low-grade inflammation and insufficient vitamin
/// D. Paired with the synthetic telemetry — which encodes a matching three-week
/// HRV decline — this reliably lights up the iron, inflammation and vitamin-D
/// paths in the brief, so the product's central claim is demonstrable.
const List<_Seed> _panel = [
  _Seed(
    BiomarkerCode.ferritin,
    'FERRITIN, SERUM',
    'Ferritin',
    BiomarkerCategory.iron,
    21,
    'ng/mL',
    15,
    300,
    1,
  ),
  _Seed(
    BiomarkerCode.hemoglobin,
    'HAEMOGLOBIN',
    'Haemoglobin',
    BiomarkerCategory.iron,
    13.9,
    'g/dL',
    13.5,
    17.5,
    1,
  ),
  _Seed(
    BiomarkerCode.transferrinSaturation,
    'TRANSFERRIN SAT.',
    'Transferrin Saturation',
    BiomarkerCategory.iron,
    18,
    '%',
    20,
    50,
    1,
  ),
  _Seed(
    BiomarkerCode.hsCrp,
    'C-REACTIVE PROTEIN (HS)',
    'hs-CRP',
    BiomarkerCategory.inflammation,
    3.4,
    'mg/L',
    null,
    3,
    1,
  ),
  _Seed(
    BiomarkerCode.hba1c,
    'GLYCOSYLATED HB (HbA1c)',
    'HbA1c',
    BiomarkerCategory.glycemic,
    5.6,
    '%',
    4,
    5.7,
    2,
  ),
  _Seed(
    BiomarkerCode.fastingGlucose,
    'GLUCOSE, FASTING',
    'Fasting Glucose',
    BiomarkerCategory.glycemic,
    96,
    'mg/dL',
    70,
    99,
    2,
  ),
  _Seed(
    BiomarkerCode.triglycerides,
    'TRIGLYCERIDES',
    'Triglycerides',
    BiomarkerCategory.lipids,
    168,
    'mg/dL',
    null,
    150,
    2,
  ),
  _Seed(
    BiomarkerCode.hdl,
    'HDL CHOLESTEROL',
    'HDL Cholesterol',
    BiomarkerCategory.lipids,
    46,
    'mg/dL',
    40,
    null,
    2,
  ),
  _Seed(
    BiomarkerCode.ldl,
    'LDL CHOLESTEROL',
    'LDL Cholesterol',
    BiomarkerCategory.lipids,
    112,
    'mg/dL',
    null,
    100,
    2,
  ),
  _Seed(
    BiomarkerCode.totalCholesterol,
    'CHOLESTEROL, TOTAL',
    'Total Cholesterol',
    BiomarkerCategory.lipids,
    191,
    'mg/dL',
    null,
    200,
    2,
  ),
  _Seed(
    BiomarkerCode.vitaminD,
    '25-OH VITAMIN D (TOTAL)',
    'Vitamin D (25-OH)',
    BiomarkerCategory.micronutrient,
    22,
    'ng/mL',
    30,
    100,
    3,
  ),
  _Seed(
    BiomarkerCode.vitaminB12,
    'VITAMIN B-12',
    'Vitamin B12',
    BiomarkerCategory.micronutrient,
    412,
    'pg/mL',
    200,
    900,
    3,
  ),
  _Seed(
    BiomarkerCode.magnesium,
    'MAGNESIUM, RBC',
    'Magnesium (RBC)',
    BiomarkerCategory.micronutrient,
    5.1,
    'mg/dL',
    4.2,
    6.8,
    3,
  ),
  _Seed(
    BiomarkerCode.tsh,
    'TSH, ULTRASENSITIVE',
    'TSH',
    BiomarkerCategory.thyroid,
    2.1,
    'mIU/L',
    0.45,
    4.5,
    3,
  ),
  _Seed(
    BiomarkerCode.alt,
    'SGPT / ALT',
    'ALT',
    BiomarkerCategory.organ,
    29,
    'U/L',
    null,
    40,
    4,
  ),
  _Seed(
    BiomarkerCode.ast,
    'SGOT / AST',
    'AST',
    BiomarkerCategory.organ,
    24,
    'U/L',
    null,
    40,
    4,
  ),
  _Seed(
    BiomarkerCode.creatinine,
    'CREATININE, SERUM',
    'Creatinine',
    BiomarkerCategory.organ,
    0.94,
    'mg/dL',
    0.7,
    1.3,
    4,
  ),
  _Seed(
    BiomarkerCode.wbc,
    'TOTAL LEUCOCYTE COUNT',
    'White Blood Cells',
    BiomarkerCategory.hematology,
    6.8,
    '10³/µL',
    4,
    11,
    1,
  ),
];

/// Standing disclosure attached to every locally-parsed report, rendered
/// verbatim by the UI so the mechanism is never misrepresented.
const String localParseDisclosure =
    'Extracted with the on-device reference panel — no OCR service is '
    'configured in this build, so these are not yet read from your file. '
    'Ranges, flags and everything downstream are real.';

class LocalLabParser implements LabParser {
  const LocalLabParser({this.latency = const Duration(milliseconds: 1400)});

  /// Mimics OCR latency so the parsing state is exercised rather than skipped.
  final Duration latency;

  @override
  Future<LabReport> parse(LabUpload upload, {required Gender gender}) async {
    await Future<void>.delayed(latency);

    final now = DateTime.now();
    final collected = addDays(now, -9);

    final biomarkers = _panel
        .map(
          (seed) => enrichBiomarker(
            Biomarker(
              code: seed.code,
              rawName: seed.rawName,
              displayName: seed.displayName,
              category: seed.category,
              value: seed.value,
              unit: seed.unit,
              range: ReferenceRange(low: seed.low, high: seed.high),
              // Flagging is deliberately left to `enrichBiomarker`, so this path
              // exercises exactly the same classification code a real parser
              // would feed.
              confidence: 0.94,
              sourcePage: seed.page,
            ),
            gender,
          ),
        )
        .toList();

    return LabReport(
      id: 'lab-${now.microsecondsSinceEpoch}',
      source: upload.source,
      status: ParseStatus.ready,
      collectedAt: DateTime(
        collected.year,
        collected.month,
        collected.day,
        8,
        15,
      ),
      uploadedAt: now,
      biomarkers: biomarkers,
      labName: 'Meridian Diagnostics',
      panelName: 'Comprehensive Metabolic & Micronutrient Panel',
      fileName: upload.name,
      fileSizeBytes: upload.sizeBytes,
      warnings: [
        localParseDisclosure,
        if (upload.source == LabSource.image)
          'Photographed reports are the least reliable input — confirm any '
              'value that looks wrong before acting on it.',
      ],
    );
  }
}
