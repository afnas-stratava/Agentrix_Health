/// Ported from `src/schemas/labs.ts`.
library;

/// Biomarkers the app knows how to reason about. Anything a report contains
/// outside this set is preserved verbatim with a null [Biomarker.code], so
/// nothing is silently dropped from the user's own results.
enum BiomarkerCode {
  // Iron / oxygen transport
  ferritin('ferritin'),
  hemoglobin('hemoglobin'),
  transferrinSaturation('transferrinSaturation'),
  // Inflammation
  hsCrp('hsCrp'),
  esr('esr'),
  // Glycemic
  hba1c('hba1c'),
  fastingGlucose('fastingGlucose'),
  fastingInsulin('fastingInsulin'),
  // Lipids
  totalCholesterol('totalCholesterol'),
  ldl('ldl'),
  hdl('hdl'),
  triglycerides('triglycerides'),
  apoB('apoB'),
  // Thyroid
  tsh('tsh'),
  freeT3('freeT3'),
  freeT4('freeT4'),
  // Micronutrients
  vitaminD('vitaminD'),
  vitaminB12('vitaminB12'),
  folate('folate'),
  magnesium('magnesium'),
  // Hepatic / renal
  alt('alt'),
  ast('ast'),
  ggt('ggt'),
  creatinine('creatinine'),
  egfr('egfr'),
  uricAcid('uricAcid'),
  // Endocrine
  testosterone('testosterone'),
  cortisolAm('cortisolAm'),
  // Haematology
  wbc('wbc'),
  plateletCount('plateletCount');

  const BiomarkerCode(this.wireName);

  final String wireName;

  static BiomarkerCode? fromWireName(String value) {
    for (final code in BiomarkerCode.values) {
      if (code.wireName == value) return code;
    }
    return null;
  }
}

enum BiomarkerCategory {
  iron('iron', 'Iron & oxygen transport'),
  inflammation('inflammation', 'Inflammation'),
  glycemic('glycemic', 'Blood sugar'),
  lipids('lipids', 'Lipids'),
  thyroid('thyroid', 'Thyroid'),
  micronutrient('micronutrient', 'Micronutrients'),
  organ('organ', 'Liver & kidney'),
  endocrine('endocrine', 'Hormones'),
  hematology('hematology', 'Blood count'),
  other('other', 'Other');

  const BiomarkerCategory(this.wireName, this.label);

  final String wireName;
  final String label;

  static BiomarkerCategory? fromWireName(String value) {
    for (final category in BiomarkerCategory.values) {
      if (category.wireName == value) return category;
    }
    return null;
  }
}

/// Where a value sits relative to its reference interval.
///
/// `optimal` is a narrower, evidence-based band *inside* the lab's own `normal`
/// range — that distinction is the whole point of the product. A ferritin of
/// 22 ng/mL is "normal" on every lab report in the world and is still a
/// plausible cause of suppressed HRV.
enum BiomarkerFlag {
  criticalLow('critical-low', 'Critically low'),
  low('low', 'Low'),
  borderlineLow('borderline-low', 'Below optimal'),
  optimal('optimal', 'Optimal'),
  normal('normal', 'Normal'),
  borderlineHigh('borderline-high', 'Above optimal'),
  high('high', 'High'),
  criticalHigh('critical-high', 'Critically high'),
  unknown('unknown', 'Unclassified');

  const BiomarkerFlag(this.wireName, this.label);

  final String wireName;
  final String label;

  /// Ranking weight used by [isOutOfRange] and [needsAttention].
  int get severity => switch (this) {
    BiomarkerFlag.criticalLow || BiomarkerFlag.criticalHigh => 4,
    BiomarkerFlag.low || BiomarkerFlag.high => 3,
    BiomarkerFlag.borderlineLow || BiomarkerFlag.borderlineHigh => 2,
    BiomarkerFlag.normal => 1,
    BiomarkerFlag.optimal || BiomarkerFlag.unknown => 0,
  };

  /// Outside the conventional laboratory interval.
  bool get isOutOfRange => severity >= 3;

  /// Outside the *optimal* band — the threshold the brief acts on.
  bool get needsAttention => severity >= 2;

  static BiomarkerFlag fromWireName(String value) {
    for (final flag in BiomarkerFlag.values) {
      if (flag.wireName == value) return flag;
    }
    return BiomarkerFlag.unknown;
  }
}

class ReferenceRange {
  const ReferenceRange({
    required this.low,
    required this.high,
    this.optimalLow,
    this.optimalHigh,
    this.source = ReferenceSource.lab,
  });

  final double? low;
  final double? high;

  /// Tighter evidence-based band, when the app has an opinion.
  final double? optimalLow;
  final double? optimalHigh;

  final ReferenceSource source;

  factory ReferenceRange.fromJson(Map<String, dynamic> json) => ReferenceRange(
    low: (json['low'] as num?)?.toDouble(),
    high: (json['high'] as num?)?.toDouble(),
    optimalLow: (json['optimalLow'] as num?)?.toDouble(),
    optimalHigh: (json['optimalHigh'] as num?)?.toDouble(),
    source: json['source'] == 'app'
        ? ReferenceSource.app
        : ReferenceSource.lab,
  );

  Map<String, dynamic> toJson() => {
    'low': low,
    'high': high,
    'optimalLow': optimalLow,
    'optimalHigh': optimalHigh,
    'source': source.name,
  };
}

/// `lab` = printed on the report, `app` = our own reference table.
enum ReferenceSource { lab, app }

class Biomarker {
  const Biomarker({
    required this.code,
    required this.rawName,
    required this.displayName,
    required this.value,
    required this.unit,
    required this.range,
    this.category = BiomarkerCategory.other,
    this.flag = BiomarkerFlag.unknown,
    this.confidence = 1,
    this.sourcePage,
  });

  /// Known code, or null when the printed name could not be mapped.
  final BiomarkerCode? code;

  /// Verbatim analyte name as printed on the report.
  final String rawName;

  final String displayName;
  final BiomarkerCategory category;
  final double value;
  final String unit;
  final ReferenceRange range;
  final BiomarkerFlag flag;

  /// Extraction confidence 0–1. Below 0.7 the UI asks the user to confirm.
  final double confidence;

  /// 1-based page in the source document, for the "show me where" affordance.
  final int? sourcePage;

  /// Trimmed for display — 5.6 not 5.6000000000000005.
  String get valueLabel {
    final rounded = (value * 100).round() / 100;
    return rounded == rounded.roundToDouble()
        ? '${rounded.round()}'
        : '$rounded';
  }

  String get valueWithUnit => '$valueLabel $unit';

  Biomarker copyWith({
    String? displayName,
    BiomarkerCategory? category,
    double? value,
    String? unit,
    ReferenceRange? range,
    BiomarkerFlag? flag,
    double? confidence,
  }) => Biomarker(
    code: code,
    rawName: rawName,
    displayName: displayName ?? this.displayName,
    category: category ?? this.category,
    value: value ?? this.value,
    unit: unit ?? this.unit,
    range: range ?? this.range,
    flag: flag ?? this.flag,
    confidence: confidence ?? this.confidence,
    sourcePage: sourcePage,
  );

  factory Biomarker.fromJson(Map<String, dynamic> json) => Biomarker(
    code: json['code'] == null
        ? null
        : BiomarkerCode.fromWireName(json['code'] as String),
    rawName: json['rawName'] as String,
    displayName: json['displayName'] as String,
    category:
        BiomarkerCategory.fromWireName(json['category'] as String? ?? '') ??
        BiomarkerCategory.other,
    value: (json['value'] as num).toDouble(),
    unit: json['unit'] as String,
    range: ReferenceRange.fromJson(
      Map<String, dynamic>.from(json['range'] as Map),
    ),
    flag: BiomarkerFlag.fromWireName(json['flag'] as String? ?? 'unknown'),
    confidence: (json['confidence'] as num?)?.toDouble() ?? 1,
    sourcePage: (json['sourcePage'] as num?)?.toInt(),
  );

  Map<String, dynamic> toJson() => {
    'code': code?.wireName,
    'rawName': rawName,
    'displayName': displayName,
    'category': category.wireName,
    'value': value,
    'unit': unit,
    'range': range.toJson(),
    'flag': flag.wireName,
    'confidence': confidence,
    'sourcePage': sourcePage,
  };
}
