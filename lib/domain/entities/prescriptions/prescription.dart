import '../labs/lab_report.dart' show ParseStatus;

/// How a prescription arrived. Mirrors [LabSource] minus the paths that don't
/// apply here — there is no Gmail-import equivalent for prescriptions.
enum PrescriptionSource {
  pdf('pdf', 'PDF'),
  image('image', 'Photo'),
  manual('manual', 'Entered by hand');

  const PrescriptionSource(this.wireName, this.label);

  final String wireName;
  final String label;

  static PrescriptionSource fromWireName(String value) {
    for (final source in PrescriptionSource.values) {
      if (source.wireName == value) return source;
    }
    return PrescriptionSource.manual;
  }
}

/// One drug on a prescription. No reference-range/flag concept exists for
/// medications the way it does for biomarkers — a dosage is not "high" or
/// "low" in the abstract, so this stays a plain transcription of what the
/// document says.
class Medication {
  const Medication({
    required this.name,
    this.dosage,
    this.frequency,
    this.route,
    this.duration,
    this.instructions,
    this.confidence = 0.8,
  });

  final String name;

  /// e.g. "500 mg".
  final String? dosage;

  /// e.g. "Twice daily" or "1-0-1".
  final String? frequency;

  /// e.g. "Oral", "Topical".
  final String? route;

  /// e.g. "5 days", "Until finished".
  final String? duration;

  /// Anything printed beyond dose/frequency — "after food", "with water".
  final String? instructions;

  /// 0.0–1.0, how legibly this row read.
  final double confidence;

  String get doseLine => [
    dosage,
    frequency,
  ].where((s) => s != null && s.isNotEmpty).join(' · ');

  Medication copyWith({
    String? name,
    String? dosage,
    String? frequency,
    String? route,
    String? duration,
    String? instructions,
    double? confidence,
  }) => Medication(
    name: name ?? this.name,
    dosage: dosage ?? this.dosage,
    frequency: frequency ?? this.frequency,
    route: route ?? this.route,
    duration: duration ?? this.duration,
    instructions: instructions ?? this.instructions,
    confidence: confidence ?? this.confidence,
  );

  factory Medication.fromJson(Map<String, dynamic> json) => Medication(
    name: json['name'] as String,
    dosage: json['dosage'] as String?,
    frequency: json['frequency'] as String?,
    route: json['route'] as String?,
    duration: json['duration'] as String?,
    instructions: json['instructions'] as String?,
    confidence: (json['confidence'] as num?)?.toDouble() ?? 0.8,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'dosage': dosage,
    'frequency': frequency,
    'route': route,
    'duration': duration,
    'instructions': instructions,
    'confidence': confidence,
  };
}

/// A parsed prescription document. Deliberately the same shape as [LabReport]
/// — id/source/status/uploadedAt/warnings — so [PrescriptionsNotifier] can
/// reuse `LabsNotifier`'s upload→parse→sort→persist pattern verbatim.
class Prescription {
  const Prescription({
    required this.id,
    required this.source,
    required this.status,
    required this.prescribedAt,
    required this.uploadedAt,
    required this.medications,
    this.prescriberName,
    this.clinicName,
    this.fileName,
    this.fileSizeBytes,
    this.error,
    this.warnings = const [],
  });

  final String id;
  final PrescriptionSource source;
  final ParseStatus status;

  /// The date printed on the prescription, if any.
  final DateTime? prescribedAt;

  final DateTime uploadedAt;
  final List<Medication> medications;
  final String? prescriberName;
  final String? clinicName;
  final String? fileName;
  final int? fileSizeBytes;

  /// Human-readable failure cause when [status] is [ParseStatus.failed].
  final String? error;

  final List<String> warnings;

  /// Mean extraction confidence across every medication row.
  double get overallConfidence {
    if (medications.isEmpty) return 0;
    final total = medications.fold<double>(0, (sum, m) => sum + m.confidence);
    return total / medications.length;
  }

  Prescription copyWith({
    ParseStatus? status,
    List<Medication>? medications,
    String? error,
  }) => Prescription(
    id: id,
    source: source,
    status: status ?? this.status,
    prescribedAt: prescribedAt,
    uploadedAt: uploadedAt,
    medications: medications ?? this.medications,
    prescriberName: prescriberName,
    clinicName: clinicName,
    fileName: fileName,
    fileSizeBytes: fileSizeBytes,
    error: error ?? this.error,
    warnings: warnings,
  );

  factory Prescription.fromJson(Map<String, dynamic> json) => Prescription(
    id: json['id'] as String,
    source: PrescriptionSource.fromWireName(json['source'] as String),
    status: ParseStatus.fromWireName(json['status'] as String),
    prescribedAt: json['prescribedAt'] == null
        ? null
        : DateTime.parse(json['prescribedAt'] as String).toLocal(),
    uploadedAt: DateTime.parse(json['uploadedAt'] as String).toLocal(),
    medications: (json['medications'] as List)
        .map((m) => Medication.fromJson(Map<String, dynamic>.from(m as Map)))
        .toList(),
    prescriberName: json['prescriberName'] as String?,
    clinicName: json['clinicName'] as String?,
    fileName: json['fileName'] as String?,
    fileSizeBytes: (json['fileSizeBytes'] as num?)?.toInt(),
    error: json['error'] as String?,
    warnings: (json['warnings'] as List?)?.cast<String>() ?? const [],
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'source': source.wireName,
    'status': status.wireName,
    'prescribedAt': prescribedAt?.toIso8601String(),
    'uploadedAt': uploadedAt.toIso8601String(),
    'medications': medications.map((m) => m.toJson()).toList(),
    'prescriberName': prescriberName,
    'clinicName': clinicName,
    'fileName': fileName,
    'fileSizeBytes': fileSizeBytes,
    'error': error,
    'warnings': warnings,
  };
}

/// A document handed to the parser.
class PrescriptionUpload {
  const PrescriptionUpload({
    required this.path,
    required this.name,
    required this.source,
    this.sizeBytes,
  });

  final String path;
  final String name;
  final PrescriptionSource source;
  final int? sizeBytes;

  /// Same ceiling as [LabUpload] — rejected before any work starts.
  static const int maxSizeBytes = 25 * 1024 * 1024;

  String? get rejectionReason {
    final size = sizeBytes;
    if (size != null && size > maxSizeBytes) {
      return 'Prescriptions must be under 25 MB.';
    }
    return null;
  }
}
