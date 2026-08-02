import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:google_generative_ai/google_generative_ai.dart';

import '../../domain/entities/gender.dart';
import '../../domain/entities/labs/biomarker.dart';
import '../../domain/entities/labs/lab_report.dart';
import '../../features/labs/lab_parser.dart';
import '../../features/labs/reference_ranges.dart';

/// Reads an actual lab document with Gemini and returns a real [LabReport].
///
/// This is the OCR path [LocalLabParser] describes but does not implement.
/// Gemini is multimodal, so there is no separate "OCR then parse" step — the
/// PDF or photo goes in as [DataPart] and structured biomarkers come back,
/// constrained by [_responseSchema] so the reply cannot drift into prose.
///
/// Flagging is deliberately *not* done here. Every extracted row goes through
/// [enrichBiomarker] exactly as the fixture path does, so reference resolution,
/// sex-specific ranges and optimal-band classification stay in one place and
/// both parsers are provably equivalent downstream.
///
/// Throws on any failure — an empty reply, malformed JSON, a document Gemini
/// could not read. Callers are expected to fall back rather than surface a
/// half-parsed report; see [FallbackLabParser].
class GeminiLabParser implements LabParser {
  const GeminiLabParser({
    required this.apiKey,
    this.model = 'gemini-flash-latest',
  });

  final String apiKey;

  /// Matches [GeminiChatService]: `gemini-flash-latest` is the alias Google
  /// points at whichever flash model this project actually has quota for.
  final String model;

  bool get isConfigured => apiKey.trim().isNotEmpty;

  /// Inline request payloads are capped well below [LabUpload.maxSizeBytes].
  /// Anything larger needs the Files API, which this path does not use, so it
  /// is rejected here and handled by the fallback instead of failing mid-call.
  static const int maxInlineBytes = 15 * 1024 * 1024;

  @override
  Future<LabReport> parse(LabUpload upload, {required Gender gender}) async {
    final file = File(upload.path);
    if (!await file.exists()) {
      throw StateError('Lab document no longer exists at ${upload.path}');
    }

    final bytes = await file.readAsBytes();
    if (bytes.lengthInBytes > maxInlineBytes) {
      throw StateError(
        'Document is ${(bytes.lengthInBytes / 1024 / 1024).toStringAsFixed(1)}MB, '
        'above the ${maxInlineBytes ~/ (1024 * 1024)}MB inline limit',
      );
    }

    final generativeModel = GenerativeModel(
      model: model,
      apiKey: apiKey,
      systemInstruction: Content.system(_systemPrompt),
      generationConfig: GenerationConfig(
        // Extraction, not composition — the same document should give the same
        // numbers on every run.
        temperature: 0,
        responseMimeType: 'application/json',
        responseSchema: _responseSchema,
      ),
    );

    final response = await generativeModel.generateContent([
      Content.multi([
        DataPart(_mimeTypeFor(upload), bytes),
        TextPart(_extractionInstruction),
      ]),
    ]);

    final text = response.text?.trim();
    if (text == null || text.isEmpty) {
      // Usually a safety filter on a medical document. Throwing lets the
      // caller fall back rather than show an empty report.
      throw StateError('Gemini returned no text for ${upload.name}');
    }

    final decoded = jsonDecode(text);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('Gemini returned ${decoded.runtimeType}, expected an object');
    }

    return reportFromJson(decoded, upload, gender);
  }

  /// Maps Gemini's structured reply onto the app's own types.
  ///
  /// Separated from [parse] and left public so the mapping — unit handling,
  /// one-sided ranges, unrecognised analytes — is testable without a network
  /// call, which is where the failure modes that matter actually live.
  @visibleForTesting
  static LabReport reportFromJson(
    Map<String, dynamic> json,
    LabUpload upload,
    Gender gender,
  ) {
    final rows = (json['biomarkers'] as List?) ?? const [];
    final biomarkers = <Biomarker>[];

    for (final row in rows) {
      if (row is! Map) continue;
      final map = Map<String, dynamic>.from(row);

      final value = (map['value'] as num?)?.toDouble();
      final rawName = (map['rawName'] as String?)?.trim();
      if (value == null || rawName == null || rawName.isEmpty) continue;

      final displayName = (map['displayName'] as String?)?.trim();

      biomarkers.add(
        enrichBiomarker(
          Biomarker(
            // Null when the analyte is outside the set the app reasons about.
            // The row is still kept — dropping a result the user can see on
            // their own report would be worse than showing it unclassified.
            code: BiomarkerCode.fromWireName((map['code'] as String?) ?? ''),
            rawName: rawName,
            displayName: displayName?.isNotEmpty == true ? displayName! : rawName,
            category:
                BiomarkerCategory.fromWireName((map['category'] as String?) ?? '') ??
                    BiomarkerCategory.other,
            value: value,
            unit: (map['unit'] as String?)?.trim() ?? '',
            range: ReferenceRange(
              low: (map['rangeLow'] as num?)?.toDouble(),
              high: (map['rangeHigh'] as num?)?.toDouble(),
            ),
            confidence: (map['confidence'] as num?)?.toDouble().clamp(0, 1) ?? 0.8,
            sourcePage: (map['sourcePage'] as num?)?.toInt(),
          ),
          gender,
        ),
      );
    }

    if (biomarkers.isEmpty) {
      throw StateError('No biomarkers found in ${upload.name}');
    }

    final now = DateTime.now();
    return LabReport(
      id: 'lab-${now.microsecondsSinceEpoch}',
      source: upload.source,
      status: ParseStatus.ready,
      collectedAt: _parseDate(json['collectedAt'] as String?),
      uploadedAt: now,
      biomarkers: biomarkers,
      labName: _nonEmpty(json['labName'] as String?),
      panelName: _nonEmpty(json['panelName'] as String?),
      fileName: upload.name,
      fileSizeBytes: upload.sizeBytes,
      warnings: [
        geminiParseDisclosure,
        if (upload.source == LabSource.image)
          'Photographed reports are the least reliable input — confirm any '
              'value that looks wrong before acting on it.',
      ],
    );
  }

  static String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static DateTime? _parseDate(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return DateTime.tryParse(trimmed)?.toLocal();
  }

  static String _mimeTypeFor(LabUpload upload) {
    final name = upload.name.toLowerCase();
    if (name.endsWith('.pdf')) return 'application/pdf';
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.webp')) return 'image/webp';
    if (name.endsWith('.heic')) return 'image/heic';
    if (name.endsWith('.heif')) return 'image/heif';
    return 'image/jpeg';
  }
}

/// Attached to every Gemini-parsed report, rendered verbatim by the UI. The
/// values are genuinely read from the document now, but they are read by a
/// model and this app is not a diagnostic device.
const String geminiParseDisclosure =
    'Read from your document automatically. Automated extraction can '
    'misread a figure — check anything that looks wrong against the original '
    'before acting on it.';

/// Tries [primary] and falls back to [fallback] when it throws.
///
/// Mirrors how [ChatNotifier] treats Gemini: the hosted model is the primary
/// voice, and a local path keeps the screen answering when there is no key, no
/// network, or the call fails. Without this a missing key would turn every
/// upload into an error state.
class FallbackLabParser implements LabParser {
  const FallbackLabParser({required this.primary, required this.fallback});

  final LabParser primary;
  final LabParser fallback;

  @override
  Future<LabReport> parse(LabUpload upload, {required Gender gender}) async {
    try {
      return await primary.parse(upload, gender: gender);
    } catch (_) {
      return fallback.parse(upload, gender: gender);
    }
  }
}

const String _systemPrompt = '''
You extract laboratory results from documents. You are a careful medical data
transcriber, not an interpreter.

Absolute rules:
- Transcribe ONLY values printed in the document. Never infer, estimate,
  average, or supply a "typical" value for a test that is not printed.
- If the document is not a lab report, or contains no numeric results, return
  an empty biomarkers array. An empty result is correct and expected; an
  invented one is a serious error.
- Copy units exactly as printed (mg/dL, ng/mL, mIU/L, 10^3/uL, ...).
- Copy the reference range exactly as printed on the report. If the report
  shows no range for a row, leave rangeLow and rangeHigh null. Do not supply a
  textbook range.
- One-sided ranges are common: "< 40" means rangeLow null, rangeHigh 40.
  "> 60" means rangeLow 60, rangeHigh null.
- Do not diagnose, interpret, or comment on whether a value is good or bad.
''';

const String _extractionInstruction = '''
Extract every laboratory result from this document.

For each result set `code` to the matching identifier below when the analyte is
clearly the same test, otherwise set `code` to null and still include the row:

ferritin, hemoglobin, transferrinSaturation, hsCrp, esr, hba1c, fastingGlucose,
fastingInsulin, totalCholesterol, ldl, hdl, triglycerides, apoB, tsh, freeT3,
freeT4, vitaminD, vitaminB12, folate, magnesium, alt, ast, ggt, creatinine,
egfr, uricAcid, testosterone, cortisolAm, wbc, plateletCount

Notes on matching: "SGPT" is alt, "SGOT" is ast, "25-OH Vitamin D" is vitaminD,
"Total Leucocyte Count" is wbc, "A1c"/"Glycated Haemoglobin" is hba1c.

Set `category` to one of: iron, inflammation, glycemic, lipids, thyroid,
micronutrient, organ, endocrine, hematology, other.

`rawName` is the analyte label exactly as printed. `displayName` is a short,
clean, human-readable name. `sourcePage` is the 1-based page the row appears on.
`confidence` is 0.0-1.0 reflecting how legibly the row scanned.

Also return the lab or facility name, the panel name, and the specimen
collection date as ISO-8601 (collectedAt) when they are printed. Use the
collection or draw date, not the report or print date. Leave them null if
absent.
''';

final Schema _responseSchema = Schema.object(
  properties: {
    'labName': Schema.string(
      description: 'Testing facility name as printed, or null',
      nullable: true,
    ),
    'panelName': Schema.string(
      description: 'Panel or test group name as printed, or null',
      nullable: true,
    ),
    'collectedAt': Schema.string(
      description: 'ISO-8601 specimen collection date, or null',
      nullable: true,
    ),
    'biomarkers': Schema.array(
      description: 'Every numeric result printed in the document',
      items: Schema.object(
        properties: {
          'code': Schema.string(
            description: 'Known analyte identifier, or null if unrecognised',
            nullable: true,
          ),
          'rawName': Schema.string(description: 'Label exactly as printed'),
          'displayName': Schema.string(description: 'Short readable name'),
          'category': Schema.string(description: 'Category identifier'),
          'value': Schema.number(description: 'Numeric result as printed'),
          'unit': Schema.string(description: 'Unit exactly as printed'),
          'rangeLow': Schema.number(
            description: 'Lower bound of the printed range, or null',
            nullable: true,
          ),
          'rangeHigh': Schema.number(
            description: 'Upper bound of the printed range, or null',
            nullable: true,
          ),
          'sourcePage': Schema.integer(
            description: '1-based page number',
            nullable: true,
          ),
          'confidence': Schema.number(description: '0.0 to 1.0'),
        },
        requiredProperties: ['rawName', 'displayName', 'value', 'unit'],
      ),
    ),
  },
  requiredProperties: ['biomarkers'],
);
