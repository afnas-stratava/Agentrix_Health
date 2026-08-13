import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:google_generative_ai/google_generative_ai.dart';

import '../../domain/entities/labs/lab_report.dart' show ParseStatus;
import '../../domain/entities/prescriptions/prescription.dart';
import '../../features/prescriptions/prescription_parser.dart';

/// Reads an actual prescription with Gemini and returns a real [Prescription].
/// Mirrors `lib/data/labs/gemini_lab_parser.dart` — same multimodal
/// single-call shape, same throw-on-failure contract so [FallbackPrescriptionParser]
/// can substitute the local fixture rather than surfacing a half-read result.
class GeminiPrescriptionParser implements PrescriptionParser {
  const GeminiPrescriptionParser({
    required this.apiKey,
    this.model = 'gemini-flash-latest',
  });

  final String apiKey;
  final String model;

  bool get isConfigured => apiKey.trim().isNotEmpty;

  /// Same ceiling as [GeminiLabParser] — larger files need the Files API,
  /// which this path does not use.
  static const int maxInlineBytes = 15 * 1024 * 1024;

  @override
  Future<Prescription> parse(PrescriptionUpload upload) async {
    final file = File(upload.path);
    if (!await file.exists()) {
      throw StateError('Prescription no longer exists at ${upload.path}');
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
      throw StateError('Gemini returned no text for ${upload.name}');
    }

    final decoded = jsonDecode(text);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('Gemini returned ${decoded.runtimeType}, expected an object');
    }

    return prescriptionFromJson(decoded, upload);
  }

  /// Maps Gemini's structured reply onto the app's own types. Separated and
  /// public for the same reason as `GeminiLabParser.reportFromJson` — testable
  /// without a network call.
  @visibleForTesting
  static Prescription prescriptionFromJson(
    Map<String, dynamic> json,
    PrescriptionUpload upload,
  ) {
    final rows = (json['medications'] as List?) ?? const [];
    final medications = <Medication>[];

    for (final row in rows) {
      if (row is! Map) continue;
      final map = Map<String, dynamic>.from(row);

      final name = (map['name'] as String?)?.trim();
      if (name == null || name.isEmpty) continue;

      medications.add(
        Medication(
          name: name,
          dosage: _nonEmpty(map['dosage'] as String?),
          frequency: _nonEmpty(map['frequency'] as String?),
          route: _nonEmpty(map['route'] as String?),
          duration: _nonEmpty(map['duration'] as String?),
          instructions: _nonEmpty(map['instructions'] as String?),
          confidence:
              (map['confidence'] as num?)?.toDouble().clamp(0, 1) ?? 0.8,
        ),
      );
    }

    if (medications.isEmpty) {
      throw StateError('No medicines found in ${upload.name}');
    }

    final now = DateTime.now();
    return Prescription(
      id: 'rx-${now.microsecondsSinceEpoch}',
      source: upload.source,
      status: ParseStatus.ready,
      prescribedAt: _parseDate(json['prescribedAt'] as String?),
      uploadedAt: now,
      medications: medications,
      prescriberName: _nonEmpty(json['prescriberName'] as String?),
      clinicName: _nonEmpty(json['clinicName'] as String?),
      fileName: upload.name,
      fileSizeBytes: upload.sizeBytes,
      warnings: [
        geminiPrescriptionParseDisclosure,
        if (upload.source == PrescriptionSource.image)
          'Photographed prescriptions are the least reliable input — confirm '
              'every dose against the original before acting on it.',
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

  static String _mimeTypeFor(PrescriptionUpload upload) {
    final name = upload.name.toLowerCase();
    if (name.endsWith('.pdf')) return 'application/pdf';
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.webp')) return 'image/webp';
    if (name.endsWith('.heic')) return 'image/heic';
    if (name.endsWith('.heif')) return 'image/heif';
    return 'image/jpeg';
  }
}

const String geminiPrescriptionParseDisclosure =
    'Read from your document automatically. Automated extraction can '
    'misread a dose — check anything that looks wrong against the original '
    'before acting on it.';

/// Tries [primary] and falls back to [fallback] when it throws. Mirrors
/// `FallbackLabParser`.
class FallbackPrescriptionParser implements PrescriptionParser {
  const FallbackPrescriptionParser({required this.primary, required this.fallback});

  final PrescriptionParser primary;
  final PrescriptionParser fallback;

  @override
  Future<Prescription> parse(PrescriptionUpload upload) async {
    try {
      return await primary.parse(upload);
    } catch (_) {
      return fallback.parse(upload);
    }
  }
}

const String _systemPrompt = '''
You extract medication information from photographs or scans of prescriptions
and pharmacy labels. You are a careful transcriber, not a pharmacist or
physician.

Absolute rules:
- Transcribe ONLY medicines actually printed or handwritten on the document.
  Never infer, guess, or add a drug that is not visible.
- If the document is not a prescription or pharmacy label, or you cannot make
  out any medicine names, return an empty medications array. An empty result
  is correct and expected; an invented one is a serious error.
- Copy dosage, frequency and duration exactly as written (e.g. "500 mg",
  "1-0-1", "5 days"). If a field is illegible or absent, leave it null rather
  than guessing a typical value.
- Do not comment on drug interactions, suitability, or dosing safety — that is
  outside what this transcription does.
''';

const String _extractionInstruction = '''
Extract every medicine listed on this prescription or pharmacy label.

For each medicine return: the drug `name` as printed, `dosage` (strength per
dose, e.g. "500 mg"), `frequency` (e.g. "twice daily" or a printed pattern
like "1-0-1"), `route` (e.g. "oral", "topical") if stated, `duration` (e.g.
"5 days", "30 tablets") if stated, any other `instructions` printed (e.g.
"after food", "avoid alcohol"), and a `confidence` from 0.0 to 1.0 reflecting
how legibly the row scanned.

Also return the prescribing doctor's name (`prescriberName`), the clinic or
hospital name (`clinicName`), and the date printed on the prescription as
ISO-8601 (`prescribedAt`), when present. Leave any of these null if absent.
''';

final Schema _responseSchema = Schema.object(
  properties: {
    'prescriberName': Schema.string(
      description: 'Prescribing doctor\'s name as printed, or null',
      nullable: true,
    ),
    'clinicName': Schema.string(
      description: 'Clinic or hospital name as printed, or null',
      nullable: true,
    ),
    'prescribedAt': Schema.string(
      description: 'ISO-8601 date printed on the prescription, or null',
      nullable: true,
    ),
    'medications': Schema.array(
      description: 'Every medicine listed on the document',
      items: Schema.object(
        properties: {
          'name': Schema.string(description: 'Drug name as printed'),
          'dosage': Schema.string(
            description: 'Strength per dose, or null',
            nullable: true,
          ),
          'frequency': Schema.string(
            description: 'How often it is taken, or null',
            nullable: true,
          ),
          'route': Schema.string(
            description: 'How it is taken, or null',
            nullable: true,
          ),
          'duration': Schema.string(
            description: 'How long for, or null',
            nullable: true,
          ),
          'instructions': Schema.string(
            description: 'Any other printed instructions, or null',
            nullable: true,
          ),
          'confidence': Schema.number(description: '0.0 to 1.0'),
        },
        requiredProperties: ['name', 'confidence'],
      ),
    ),
  },
  requiredProperties: ['medications'],
);
