import 'biomarker.dart';

/// How a report arrived.
enum LabSource {
  pdf('pdf', 'PDF'),
  image('image', 'Photo'),
  email('email', 'From your inbox'),
  manual('manual', 'Entered by hand'),
  sample('sample', 'Sample report');

  const LabSource(this.wireName, this.label);

  final String wireName;
  final String label;

  static LabSource fromWireName(String value) {
    for (final source in LabSource.values) {
      if (source.wireName == value) return source;
    }
    return LabSource.manual;
  }
}

enum ParseStatus {
  pending('pending'),
  parsing('parsing'),
  needsReview('needs-review'),
  ready('ready'),
  failed('failed');

  const ParseStatus(this.wireName);

  final String wireName;

  static ParseStatus fromWireName(String value) {
    for (final status in ParseStatus.values) {
      if (status.wireName == value) return status;
    }
    return ParseStatus.pending;
  }
}

class LabReport {
  const LabReport({
    required this.id,
    required this.source,
    required this.status,
    required this.collectedAt,
    required this.uploadedAt,
    required this.biomarkers,
    this.labName,
    this.panelName,
    this.fileName,
    this.fileSizeBytes,
    this.error,
    this.warnings = const [],
  });

  final String id;
  final LabSource source;
  final ParseStatus status;

  /// When blood was drawn — the date any trend anchors to.
  final DateTime? collectedAt;

  final DateTime uploadedAt;
  final List<Biomarker> biomarkers;
  final String? labName;
  final String? panelName;
  final String? fileName;
  final int? fileSizeBytes;

  /// Human-readable failure cause when [status] is [ParseStatus.failed].
  final String? error;

  final List<String> warnings;

  /// Biomarkers outside their optimal band, worst first. This is the list the
  /// brief reads and the report screen leads with.
  List<Biomarker> get flagged {
    final out = biomarkers.where((b) => b.flag.needsAttention).toList();
    out.sort((a, b) => b.flag.severity.compareTo(a.flag.severity));
    return out;
  }

  /// Mean extraction confidence across all analytes.
  double get overallConfidence {
    if (biomarkers.isEmpty) return 0;
    final total = biomarkers.fold<double>(0, (sum, b) => sum + b.confidence);
    return total / biomarkers.length;
  }

  Biomarker? marker(BiomarkerCode code) {
    for (final biomarker in biomarkers) {
      if (biomarker.code == code) return biomarker;
    }
    return null;
  }

  LabReport copyWith({
    ParseStatus? status,
    List<Biomarker>? biomarkers,
    String? error,
  }) => LabReport(
    id: id,
    source: source,
    status: status ?? this.status,
    collectedAt: collectedAt,
    uploadedAt: uploadedAt,
    biomarkers: biomarkers ?? this.biomarkers,
    labName: labName,
    panelName: panelName,
    fileName: fileName,
    fileSizeBytes: fileSizeBytes,
    error: error ?? this.error,
    warnings: warnings,
  );

  factory LabReport.fromJson(Map<String, dynamic> json) => LabReport(
    id: json['id'] as String,
    source: LabSource.fromWireName(json['source'] as String),
    status: ParseStatus.fromWireName(json['status'] as String),
    collectedAt: json['collectedAt'] == null
        ? null
        : DateTime.parse(json['collectedAt'] as String).toLocal(),
    uploadedAt: DateTime.parse(json['uploadedAt'] as String).toLocal(),
    biomarkers: (json['biomarkers'] as List)
        .map((b) => Biomarker.fromJson(Map<String, dynamic>.from(b as Map)))
        .toList(),
    labName: json['labName'] as String?,
    panelName: json['panelName'] as String?,
    fileName: json['fileName'] as String?,
    fileSizeBytes: (json['fileSizeBytes'] as num?)?.toInt(),
    error: json['error'] as String?,
    warnings: (json['warnings'] as List?)?.cast<String>() ?? const [],
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'source': source.wireName,
    'status': status.wireName,
    'collectedAt': collectedAt?.toIso8601String(),
    'uploadedAt': uploadedAt.toIso8601String(),
    'biomarkers': biomarkers.map((b) => b.toJson()).toList(),
    'labName': labName,
    'panelName': panelName,
    'fileName': fileName,
    'fileSizeBytes': fileSizeBytes,
    'error': error,
    'warnings': warnings,
  };
}

/// A document handed to the parser.
class LabUpload {
  const LabUpload({
    required this.path,
    required this.name,
    required this.source,
    this.sizeBytes,
  });

  final String path;
  final String name;
  final LabSource source;
  final int? sizeBytes;

  /// Reports above this are rejected before any work starts.
  static const int maxSizeBytes = 25 * 1024 * 1024;

  String? get rejectionReason {
    final size = sizeBytes;
    if (size != null && size > maxSizeBytes) {
      return 'Reports must be under 25 MB.';
    }
    return null;
  }
}
